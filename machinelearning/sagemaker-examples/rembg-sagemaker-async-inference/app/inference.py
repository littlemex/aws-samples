import os
import json
import logging
import sys
import io
import asyncio
from pathlib import Path
from typing import Dict, Union
from concurrent.futures import ThreadPoolExecutor

import boto3
from fastapi import FastAPI, HTTPException, BackgroundTasks
from PIL import Image
from rembg import remove, new_session

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI()

# FIXME: 環境変数で AWS リソースがなくてもローカルで背景削除検証できるような実装に変更してください。
#  例えば、S3 の in/out の代わりにローカルのディレクトリ in/out を利用したいです。
# FIXME: SageMaker 上でエラー等の問題がおきないのであれば pydantic を用いた型付けをしたいです。

# Initialize AWS clients
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
        model_session = new_session(model_name, model_path=model_path)
        logger.info(f"Successfully loaded model: {model_name}")
        return model_session
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise

async def update_metrics(endpoint_name: str):
    """Update CloudWatch metrics for queue monitoring"""
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
    image = Image.open(io.BytesIO(image_data))
    output_image = remove(image, session=model_session)
    img_byte_arr = io.BytesIO()
    output_image.save(img_byte_arr, format='PNG')
    return img_byte_arr.getvalue()

async def process_async_inference(input_location: str, output_location: str, endpoint_name: str):
    """Process async inference request with queue management"""
    try:
        # Acquire semaphore for concurrent request management
        async with semaphore:
            # Parse S3 input location
            input_parts = input_location.replace("s3://", "").split("/")
            input_bucket = input_parts[0]
            input_key = "/".join(input_parts[1:])

            # Parse S3 output location
            output_parts = output_location.replace("s3://", "").split("/")
            output_bucket = output_parts[0]
            output_key = "/".join(output_parts[1:])

            # Download input image from S3
            response = s3.get_object(Bucket=input_bucket, Key=input_key)
            image_data = response['Body'].read()
            
            # Process image in thread pool to avoid blocking
            loop = asyncio.get_event_loop()
            output_bytes = await loop.run_in_executor(
                thread_pool,
                process_image,
                image_data
            )
            
            # Upload result to S3
            s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=output_bytes,
                ContentType='image/png'
            )
            
            # Update metrics after processing
            await update_metrics(endpoint_name)
            
            return {
                "status": "success",
                "output_location": f"s3://{output_bucket}/{output_key}"
            }
            
    except Exception as e:
        logger.error(f"Error processing async inference: {str(e)}")
        # Update metrics even on failure
        await update_metrics(endpoint_name)
        raise

# Load the model
model = model_fn()

@app.post("/invocations")
async def invoke_endpoint(request: Dict):
    """
    Endpoint for async model invocation
    Expected request format:
    {
        "InputLocation": "s3://input-bucket/input-key",
        "OutputLocation": "s3://output-bucket/output-key"
    }
    """
    try:
        if not isinstance(request, dict):
            raise HTTPException(status_code=400, detail="Invalid request format")
        
        input_location = request.get("InputLocation")
        output_location = request.get("OutputLocation")
        
        if not input_location or not output_location:
            raise HTTPException(
                status_code=400,
                detail="Both InputLocation and OutputLocation are required"
            )
        
        if not (input_location.startswith("s3://") and output_location.startswith("s3://")):
            raise HTTPException(
                status_code=400,
                detail="Both InputLocation and OutputLocation must be S3 URIs"
            )
        # Get endpoint name from environment
        endpoint_name = os.environ.get('SAGEMAKER_ENDPOINT_NAME', 'unknown-endpoint')
        
        # Check current queue size
        current_backlog = max_concurrent_invocations - semaphore._value
        if current_backlog >= max_concurrent_invocations:
            raise HTTPException(
                status_code=429,
                detail="Queue is full, please try again later"
            )
            
        result = await process_async_inference(input_location, output_location, endpoint_name)
        return result
    
    except Exception as e:
        logger.error(f"Error during invocation: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ping")
async def ping():
    """Healthcheck endpoint"""
    return {"status": "healthy"}