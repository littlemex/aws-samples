import os
import io
import logging
import asyncio
import time
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from inference_processor import LocalInferenceProcessor, AWSInferenceProcessor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI()
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    error_details = []
    for error in exc.errors():
        error_details.append({
            "loc": " -> ".join(str(loc) for loc in error["loc"]),
            "msg": error["msg"],
            "type": error["type"]
        })
    logger.error(f"Validation error details: {error_details}")
    return JSONResponse(
        status_code=422,
        content={"detail": error_details}
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error(f"HTTP error occurred: {exc.status_code} - {exc.detail}")
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unexpected error occurred: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )

class AsyncInferenceResponse(BaseModel):
    InferenceId: str = Field(..., description="Identifier for the inference request")
    OutputLocation: str = Field(..., description="The S3 URI where the inference response payload is stored")

class ErrorResponse(BaseModel):
    detail: str = Field(..., description="Error details")

class SageMakerHeaders(BaseModel):
    content_type: str = Field(..., max_length=1024)
    accept: Optional[str] = Field(None, max_length=1024)
    custom_attributes: Optional[str] = Field(None, max_length=1024)
    inference_id: Optional[str] = Field(None, max_length=64)


# Initialize configuration
USE_AWS = os.environ.get('USE_AWS', 'true').lower() == 'true'
model_name = os.environ.get('MODEL_NAME', 'u2net')
max_concurrent_invocations = int(os.environ.get('MAX_CONCURRENT_INVOCATIONS', '2'))
semaphore = asyncio.Semaphore(max_concurrent_invocations)
thread_pool = ThreadPoolExecutor(max_workers=max_concurrent_invocations)

# Initialize processor based on environment
processor = AWSInferenceProcessor(model_name) if USE_AWS else LocalInferenceProcessor(model_name)

async def process_async_inference(image_data: str, output_location: str, inference_id: str):
    """Process async inference request with queue management"""
    try:
        async with semaphore:
            # Parse locations
            output_bucket, output_key = processor.parse_location(output_location)

            # Process image in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            # Convert PIL Image to bytes in memory
            img_byte_arr = io.BytesIO()
            image_data.save(img_byte_arr, format=image_data.format or 'PNG')
            img_byte_arr.seek(0)  # Reset buffer position to start
            img_bytes = img_byte_arr.getvalue()
            
            output_bytes = await loop.run_in_executor(
                thread_pool,
                processor.process_image,
                img_bytes
            )
            
            # Save output image
            output_path = await processor.save_output_image(output_bytes, output_bucket, output_key)
            
            # Update metrics after processing (AWS only)
            if USE_AWS:
                backlog_size = max_concurrent_invocations - semaphore._value
                endpoint_name = os.environ.get('SAGEMAKER_ENDPOINT_NAME', 'rembg-async-app')
                processor.update_backlog_metric(endpoint_name, backlog_size)
            
            return AsyncInferenceResponse(
                InferenceId=inference_id,
                OutputLocation=output_path
            )
            
    except Exception as e:
        logger.error(f"Error processing async inference: {str(e)}")
        if USE_AWS:
            backlog_size = max_concurrent_invocations - semaphore._value
            endpoint_name = os.environ.get('SAGEMAKER_ENDPOINT_NAME', 'rembg-async-app')
            processor.update_backlog_metric(endpoint_name, backlog_size)
        raise

async def process_request_parameters(
    inference_id: Optional[str] = None,
    custom_attributes: Optional[str] = None
) -> dict:

    # Generate output location based on input location or custom attributes
    output_location = None
    if custom_attributes:
        try:
            custom_attrs = dict(attr.split('=') for attr in custom_attributes.split(';') if '=' in attr)
            output_location = custom_attrs.get('output_location')
        except Exception as e:
            logger.warning(f"Failed to parse custom attributes: {e}")
    
    # Generate or use provided inference ID
    final_inference_id = inference_id or str(time.time())

    # Fallback to default output location if not specified in custom attributes
    if not output_location:
        output_bucket = os.environ.get('OUTPUT_BUCKET')
        if not output_bucket:
            raise HTTPException(
                status_code=500,
                detail="OUTPUT_BUCKET environment variable is not set"
            )
        output_location = f"s3://{output_bucket}/output/{final_inference_id}.png"
    
    # Check current queue size
    current_backlog = max_concurrent_invocations - semaphore._value
    if current_backlog >= max_concurrent_invocations:
        raise HTTPException(
            status_code=429,
            detail="Queue is full, please try again later"
        )
    
    return {
        "output_location": output_location,
        "inference_id": final_inference_id
    }

def create_inference_response(result: AsyncInferenceResponse) -> JSONResponse:
    """Create JSON response with appropriate headers"""
    headers = {
        'X-Amzn-SageMaker-OutputLocation': result.OutputLocation,
        'Content-Type': 'application/json'
    }
    
    # Add optional failure location if present
    if hasattr(result, 'FailureLocation'):
        headers['X-Amzn-SageMaker-FailureLocation'] = result.FailureLocation
        
    return JSONResponse(
        status_code=202,
        content={"InferenceId": result.InferenceId},
        headers=headers
    )

async def process_request(request: Request) -> tuple[any, SageMakerHeaders]:
    """Process and validate the incoming request"""
    import json
    import io
    from PIL import Image

    # Log raw request details
    headers = dict(request.headers)
    logger.info("Raw request headers:")
    logger.info(headers)
    
    # Get request body and content type
    body = await request.body()
    content_type = request.headers.get("content-type", "").lower()
    
    # Process body based on content type
    logger.info("Raw request body:")
    if "application/json" in content_type:
        try:
            body_content = json.loads(body)
            logger.info(body_content)
            raise HTTPException(
                status_code=415,
                detail="Text/JSON processing is not implemented"
            )
        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse JSON body: {e}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid JSON format: {str(e)}"
            )
    elif "image/" in content_type:
        try:
            body_content = Image.open(io.BytesIO(body))
            logger.info(f"Image details - Format: {body_content.format}, Size: {body_content.size}, Mode: {body_content.mode}")
        except Exception as e:
            logger.error(f"Failed to parse image: {e}")
            raise HTTPException(
                status_code=400,
                detail=f"Invalid image format: {str(e)}"
            )
    else:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported content type: {content_type}. Only application/json and image/* are supported."
        )

    # Log request metadata
    query_params = dict(request.query_params)
    logger.info("Request query parameters:")
    logger.info(query_params)
    
    logger.info("Complete request information:")
    logger.info({
        "method": request.method,
        "url": str(request.url),
        "headers": headers,
        "query_params": query_params,
        "client": request.client,
        "cookies": request.cookies,
        "path_params": request.path_params
    })

    # Log model directory contents
    model_dir_path = os.environ.get('MODEL_PATH', '/opt/ml/model')
    if os.path.exists(model_dir_path):
        logger.info(f"Contents of {model_dir_path}:")
        for root, dirs, files in os.walk(model_dir_path):
            logger.info(f"Directory: {root}")
            if dirs:
                logger.info(f"Subdirectories: {dirs}")
            if files:
                logger.info(f"Files: {files}")
    else:
        logger.warning(f"{model_dir_path} does not exist")

    # Validate and create SageMaker headers
    sagemaker_headers = SageMakerHeaders(
        content_type=headers.get("content-type"),
        accept=headers.get("x-amzn-sagemaker-accept"),
        custom_attributes=headers.get("x-amzn-sagemaker-custom-attributes"),
        inference_id=headers.get("x-amzn-sagemaker-inference-id"),
    )

    # Log validated request details
    logger.info("Validated SageMaker headers:")
    logger.info(f"Content type: {sagemaker_headers.content_type}")
    logger.info(f"Accept: {sagemaker_headers.accept}")
    logger.info(f"Custom attributes: {sagemaker_headers.custom_attributes}")
    logger.info(f"Inference ID: {sagemaker_headers.inference_id}")

    return body_content, sagemaker_headers

@app.post("/invocations", response_model=AsyncInferenceResponse, status_code=202)
async def predict_fn(request: Request):
    """
    Endpoint for async model invocation that follows SageMaker async inference format
    See: https://docs.aws.amazon.com/ja_jp/sagemaker/latest/APIReference/API_runtime_InvokeEndpointAsync.html
    """
    try:
        # Process the request and get the body content
        body_content, sagemaker_headers = await process_request(request)

        # Process request parameters
        request_params = await process_request_parameters(
            sagemaker_headers.inference_id,
            sagemaker_headers.custom_attributes
        )
            
        # Process the inference request
        result = await process_async_inference(
            body_content,
            request_params["output_location"],
            request_params["inference_id"]
        )
        
        # Create and return response
        return create_inference_response(result)
    
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error during invocation: {str(e)}")
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ping")
async def ping():
    """Healthcheck endpoint"""
    return {"status": "healthy"}