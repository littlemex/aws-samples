import os
import json
import logging
import sys
import io
import asyncio
import time
from pathlib import Path
from typing import Dict, Union, Optional
from concurrent.futures import ThreadPoolExecutor

import boto3
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field, validator
from PIL import Image
from rembg import remove, new_session

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI()

# Pydantic models for request/response validation
class AsyncInferenceRequest(BaseModel):
    InputLocation: str = Field(..., description="Input image location (S3 URI)")
    OutputLocation: str = Field(..., description="Output image location (S3 URI)")

    @validator('InputLocation', 'OutputLocation')
    def validate_location(cls, v):
        use_aws = os.environ.get('USE_AWS', 'true').lower() == 'true'
        if not v.startswith('s3://'):
            raise ValueError("Location must be an S3 URI (s3://)")
        return v

class AsyncInferenceResponse(BaseModel):
    status: str = Field(..., description="Processing status")
    output_location: str = Field(..., description="Location of the processed image")

class ErrorResponse(BaseModel):
    detail: str = Field(..., description="Error details")

# Initialize AWS clients (only if AWS resources are enabled)
USE_AWS = os.environ.get('USE_AWS', 'true').lower() == 'true'
s3 = None
if USE_AWS:
    runtime = boto3.client('sagemaker-runtime')
    s3 = boto3.client('s3')
    cloudwatch = boto3.client('cloudwatch')

# Global variables
model_name = os.environ.get('MODEL_NAME', 'u2net')
model_session = None
max_concurrent_invocations = int(os.environ.get('MAX_CONCURRENT_INVOCATIONS', '2'))
semaphore = asyncio.Semaphore(max_concurrent_invocations)
thread_pool = ThreadPoolExecutor(max_workers=max_concurrent_invocations)

# Metrics
NAMESPACE = "CustomMetrics/AsyncInference"

def download_models():
    """Download model files if they don't exist"""
    model_dir_path = os.environ.get('MODEL_PATH', '/opt/ml/model')
    models_dir = Path(model_dir_path)
    model_path = models_dir / f"{model_name}.onnx"
    
    if not model_path.exists():
        logger.error(f"Model file not found: {model_path}")
        raise FileNotFoundError(f"Model file not found: {model_path}")
    
    return str(model_path)

def model_fn():
    """Load the model for inference"""
    global model_session
    
    try:
        model_path = download_models()
        os.environ['U2NET_HOME'] = os.path.dirname(model_path)
        
        # GPU/CPU setup
        import torch
        if torch.cuda.is_available():
            device = torch.cuda.get_device_name(0)
            logger.info(f"Using GPU: {device}")
            torch.cuda.empty_cache()
            torch.cuda.set_per_process_memory_fraction(0.8)
        else:
            logger.info("Using CPU for inference")
            
        # Create session
        model_session = new_session(model_name, model_path=model_path)
        logger.info(f"Successfully loaded model: {model_name}")
        
        return model_session
    except FileNotFoundError as e:
        logger.error(f"Model file not found at {model_path}. Please ensure the model is mounted correctly.")
        raise
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise

async def update_metrics(endpoint_name: str):
    """Update CloudWatch metrics for queue monitoring"""
    if not USE_AWS:
        return

    try:
        # Get current semaphore count to estimate backlog
        backlog_size = max_concurrent_invocations - semaphore._value
        
        cloudwatch.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[
                {
                    'MetricName': 'ApproximateBacklogSizePerInstance',
                    'Value': backlog_size,
                    'Unit': 'Count',
                    'Dimensions': [
                        {
                            'Name': 'EndpointName',
                            'Value': endpoint_name
                        }
                    ]
                }
            ]
        )
    except Exception as e:
        logger.error(f"Error updating metrics: {str(e)}")

def process_image(image_data: bytes) -> bytes:
    """Process image in a separate thread"""
    global model_session
    
    # Lazy load model if not already loaded
    if model_session is None:
        model_session = model_fn()
        
    image = Image.open(io.BytesIO(image_data))
    output_image = remove(image, session=model_session)
    img_byte_arr = io.BytesIO()
    output_image.save(img_byte_arr, format='PNG')
    return img_byte_arr.getvalue()

def parse_location(location: str) -> tuple[str, str]:
    """Parse S3 URI into bucket and key"""
    if not location.startswith('s3://'):
        raise ValueError("Location must be an S3 URI (s3://)")
    parts = location.replace("s3://", "").split("/")
    bucket = parts[0]
    key = "/".join(parts[1:])
    return bucket, key

async def read_input_image(input_bucket: str, input_key: str) -> bytes:
    """Read input image from S3 or local file system based on USE_AWS"""
    try:
        if USE_AWS:
            response = s3.get_object(Bucket=input_bucket, Key=input_key)
            return response['Body'].read()
        else:
            # In local mode, treat bucket/key as local path
            local_path = f"{input_bucket}/{input_key}"
            logger.info(f"local_path: {local_path}")
            with open(local_path, 'rb') as f:
                return f.read()
    except Exception as e:
        logger.error(f"Error reading input image: {str(e)}")
        raise

async def save_output_image(output_bytes: bytes, output_bucket: str, output_key: str) -> str:
    """Save output image to S3 or local file system based on USE_AWS"""
    try:
        if USE_AWS:
            s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=output_bytes,
                ContentType='image/png'
            )
        else:
            # In local mode, treat bucket/key as local path
            local_path = f"{output_bucket}/{output_key}"
            # Create output directory if it doesn't exist
            output_dir = Path(local_path).parent
            output_dir.mkdir(parents=True, exist_ok=True)
            
            with open(local_path, 'wb') as f:
                f.write(output_bytes)
        
        return f"s3://{output_bucket}/{output_key}"
    except Exception as e:
        logger.error(f"Error saving output image: {str(e)}")
        raise

async def process_async_inference(input_location: str, output_location: str, endpoint_name: str):
    """Process async inference request with queue management"""
    try:
        async with semaphore:
            # Parse locations (always s3:// format)
            input_bucket, input_key = parse_location(input_location)
            output_bucket, output_key = parse_location(output_location)

            # Read input image (handles both S3 and local based on USE_AWS)
            image_data = await read_input_image(input_bucket, input_key)
            
            # Process image in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            output_bytes = await loop.run_in_executor(
                thread_pool,
                process_image,
                image_data
            )
            
            # Save output image (handles both S3 and local based on USE_AWS)
            output_path = await save_output_image(output_bytes, output_bucket, output_key)
            
            # Update metrics after processing (AWS only)
            if USE_AWS:
                await update_metrics(endpoint_name)
            
            return AsyncInferenceResponse(
                status="success",
                output_location=output_path
            )
            
    except Exception as e:
        logger.error(f"Error processing async inference: {str(e)}")
        if USE_AWS:
            await update_metrics(endpoint_name)
        raise

@app.post("/invocations", response_model=AsyncInferenceResponse)
async def invoke_endpoint(request: AsyncInferenceRequest):
    """
    Endpoint for async model invocation
    """
    try:
        # Get endpoint name from environment
        endpoint_name = os.environ.get('SAGEMAKER_ENDPOINT_NAME', 'unknown-endpoint')
        
        # Check current queue size
        current_backlog = max_concurrent_invocations - semaphore._value
        if current_backlog >= max_concurrent_invocations:
            raise HTTPException(
                status_code=429,
                detail="Queue is full, please try again later"
            )
            
        result = await process_async_inference(
            request.InputLocation,
            request.OutputLocation,
            endpoint_name
        )
        return result
    
    except Exception as e:
        logger.error(f"Error during invocation: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ping")
async def ping():
    """Healthcheck endpoint"""
    return {"status": "healthy"}