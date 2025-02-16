import os
import logging
import asyncio
import time
from typing import Optional
from concurrent.futures import ThreadPoolExecutor

from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator

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

class AsyncInferenceRequest(BaseModel):
    ContentType: Optional[str] = Field(..., max_length=1024, pattern=r'\p{ASCII}*', alias="content_type")
    Accept: Optional[str] = Field(..., max_length=1024, pattern=r'\p{ASCII}*', alias="accept")
    CustomAttributes: Optional[str] = Field(None, max_length=1024, pattern=r'\p{ASCII}*', alias="custom_attributes")
    InferenceId: Optional[str] = Field(None, min_length=1, max_length=64, pattern=r'^[^\s][\x20-\x7E]*$', alias="inference_id")
    InputLocation: str = Field(..., min_length=1, max_length=1024, pattern=r'^(https|s3)://([^/]+)/?(.*)$', alias="input_location")
    RequestTtl: Optional[int] = Field(21600, ge=60, le=21600, alias="request_ttl")
    InvocationTimeout: Optional[int] = Field(900, ge=1, le=3600, alias="invocation_timeout")

    class Config:
        populate_by_name = True

    @validator('InputLocation')
    def validate_location(cls, v):
        if not v.startswith('s3://'):
            raise ValueError("Location must be an S3 URI (s3://)")
        return v

class AsyncInferenceResponse(BaseModel):
    InferenceId: str = Field(..., description="Identifier for the inference request")
    OutputLocation: str = Field(..., description="The S3 URI where the inference response payload is stored")

class ErrorResponse(BaseModel):
    detail: str = Field(..., description="Error details")

# Initialize configuration
USE_AWS = os.environ.get('USE_AWS', 'true').lower() == 'true'
model_name = os.environ.get('MODEL_NAME', 'u2net')
max_concurrent_invocations = int(os.environ.get('MAX_CONCURRENT_INVOCATIONS', '2'))
semaphore = asyncio.Semaphore(max_concurrent_invocations)
thread_pool = ThreadPoolExecutor(max_workers=max_concurrent_invocations)

# Initialize processor based on environment
processor = AWSInferenceProcessor(model_name) if USE_AWS else LocalInferenceProcessor(model_name)

async def process_async_inference(input_location: str, output_location: str, endpoint_name: str, inference_id: str):
    """Process async inference request with queue management"""
    try:
        async with semaphore:
            # Parse locations
            input_bucket, input_key = processor.parse_location(input_location)
            output_bucket, output_key = processor.parse_location(output_location)

            # Read input image
            image_data = await processor.read_input_image(input_bucket, input_key)
            
            # Process image in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            output_bytes = await loop.run_in_executor(
                thread_pool,
                processor.process_image,
                image_data
            )
            
            # Save output image
            output_path = await processor.save_output_image(output_bytes, output_bucket, output_key)
            
            # Update metrics after processing (AWS only)
            if USE_AWS:
                backlog_size = max_concurrent_invocations - semaphore._value
                processor.update_backlog_metric(endpoint_name, backlog_size)
            
            return AsyncInferenceResponse(
                InferenceId=inference_id,
                OutputLocation=output_path
            )
            
    except Exception as e:
        logger.error(f"Error processing async inference: {str(e)}")
        if USE_AWS:
            backlog_size = max_concurrent_invocations - semaphore._value
            processor.update_backlog_metric(endpoint_name, backlog_size)
        raise

async def process_request_parameters(input_location: str, inference_id: Optional[str] = None) -> dict:
    """Process and validate request parameters"""
    # Validate input location format
    if not input_location.startswith(('https://', 's3://')):
        raise HTTPException(
            status_code=400,
            detail="InputLocation must start with https:// or s3://"
        )

    # Generate output location based on input location
    input_parts = input_location.split('/')
    output_location = f"{'/'.join(input_parts[:-1])}/output/{input_parts[-1]}"
    
    # Generate or use provided inference ID
    final_inference_id = inference_id or str(time.time())
    
    # Check current queue size
    current_backlog = max_concurrent_invocations - semaphore._value
    if current_backlog >= max_concurrent_invocations:
        raise HTTPException(
            status_code=429,
            detail="Queue is full, please try again later"
        )
    
    return {
        "input_location": input_location,
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

@app.post("/endpoints/{endpoint_name}/async-invocations", response_model=AsyncInferenceResponse, status_code=202)
async def invoke_endpoint(
    endpoint_name: str,
    request: Request,
    x_amzn_sagemaker_content_type: str = Header(..., max_length=1024, alias="X-Amzn-SageMaker-Content-Type"),
    x_amzn_sagemaker_accept: Optional[str] = Header(None, max_length=1024, alias="X-Amzn-SageMaker-Accept"),
    x_amzn_sagemaker_custom_attributes: Optional[str] = Header(None, max_length=1024, alias="X-Amzn-SageMaker-Custom-Attributes"),
    x_amzn_sagemaker_inference_id: Optional[str] = Header(None, max_length=64, alias="X-Amzn-SageMaker-Inference-Id"),
    x_amzn_sagemaker_input_location: str = Header(..., min_length=1, max_length=1024, alias="X-Amzn-SageMaker-InputLocation"),
    x_amzn_sagemaker_request_ttl_seconds: Optional[int] = Header(None, ge=60, le=21600, alias="X-Amzn-SageMaker-RequestTTLSeconds"),
    x_amzn_sagemaker_invocation_timeout_seconds: Optional[int] = Header(None, ge=1, le=3600, alias="X-Amzn-SageMaker-InvocationTimeoutSeconds"),
):
    """
    Endpoint for async model invocation that follows SageMaker async inference format
    See: https://docs.aws.amazon.com/ja_jp/sagemaker/latest/APIReference/API_runtime_InvokeEndpointAsync.html
    """
    try:
        # Log request details
        logger.info(f"Endpoint name: {endpoint_name}")
        logger.info(f"Content type: {x_amzn_sagemaker_content_type}")
        logger.info(f"Accept: {x_amzn_sagemaker_accept}")
        logger.info(f"Custom attributes: {x_amzn_sagemaker_custom_attributes}")
        logger.info(f"Inference ID: {x_amzn_sagemaker_inference_id}")
        logger.info(f"Input location: {x_amzn_sagemaker_input_location}")
        logger.info(f"Request TTL: {x_amzn_sagemaker_request_ttl_seconds}")
        logger.info(f"Invocation timeout: {x_amzn_sagemaker_invocation_timeout_seconds}")

        # Process request parameters
        request_params = await process_request_parameters(
            x_amzn_sagemaker_input_location,
            x_amzn_sagemaker_inference_id
        )
            
        # Process the inference request
        result = await process_async_inference(
            request_params["input_location"],
            request_params["output_location"],
            endpoint_name,
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