import os
import json
import logging
import sys
import io
from pathlib import Path
from typing import Dict, Union

import boto3
from fastapi import FastAPI
from PIL import Image
from rembg import remove, new_session

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI()

# Initialize S3 client
s3 = boto3.client('s3')

# Global variables
model_name = os.environ.get('MODEL_NAME', 'u2net')
model_session = None

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

def input_fn(input_data: Union[str, bytes], content_type: str):
    """Parse input data payload"""
    logger.info(f"Processing input with content type: {content_type}")
    
    try:
        if content_type == 'application/json':
            if not isinstance(input_data, (str, bytes)):
                raise ValueError("Input data must be string or bytes for JSON content type")
                
            input_json = json.loads(input_data)
            
            if not isinstance(input_json, dict):
                raise ValueError("JSON input must be an object")
                
            if 'bucket' not in input_json or 'key' not in input_json:
                raise ValueError("JSON input must contain 'bucket' and 'key' fields")
                
            bucket = input_json['bucket']
            key = input_json['key']
            
            if not isinstance(bucket, str) or not isinstance(key, str):
                raise ValueError("'bucket' and 'key' must be strings")
            
            try:
                # Download image from S3
                response = s3.get_object(Bucket=bucket, Key=key)
                image_data = response['Body'].read()
            except Exception as s3_error:
                raise ValueError(f"Error accessing S3: {str(s3_error)}")
            
        elif content_type in ['image/jpeg', 'image/png']:
            if not isinstance(input_data, bytes):
                raise ValueError("Input data must be bytes for image content types")
            image_data = input_data
        else:
            raise ValueError(f"Unsupported content type: {content_type}. Supported types are: application/json, image/jpeg, image/png")
        
        try:
            # Convert to PIL Image
            image = Image.open(io.BytesIO(image_data))
            return {
                'image': image,
                'bucket': bucket if 'bucket' in locals() else None,
                'key': key if 'key' in locals() else None
            }
        except Exception as img_error:
            raise ValueError(f"Invalid image data: {str(img_error)}")
    
    except Exception as e:
        logger.error(f"Error processing input: {str(e)}")
        raise

def predict_fn(input_object: Dict, model):
    """Perform prediction"""
    try:
        image = input_object['image']
        
        # Use GPU if available and enabled
        use_gpu = os.environ.get('CUDA_ENABLED', '0') == '1' and torch.cuda.is_available()
        if use_gpu:
            logger.info("Using GPU for inference")
        else:
            logger.info("Using CPU for inference")
        
        # Remove background
        output_image = remove(image, session=model)
        
        # Convert to bytes
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        img_byte_arr = img_byte_arr.getvalue()
        
        return {
            'image_data': img_byte_arr,
            'bucket': input_object.get('bucket'),
            'key': input_object.get('key')
        }
    
    except Exception as e:
        logger.error(f"Error during prediction: {str(e)}")
        raise

def output_fn(prediction_output: Dict, accept: str):
    """Return prediction results"""
    try:
        if prediction_output.get('bucket') and prediction_output.get('key'):
            # For async inference, save to S3
            output_key = f"output/{Path(prediction_output['key']).stem}_nobg.png"
            s3.put_object(
                Bucket=prediction_output['bucket'],
                Key=output_key,
                Body=prediction_output['image_data'],
                ContentType='image/png'
            )
            logger.info(f"Saved output to s3://{prediction_output['bucket']}/{output_key}")
            return json.dumps({
                'status': 'success',
                'output_bucket': prediction_output['bucket'],
                'output_key': output_key
            })
        else:
            # For real-time inference, return image directly
            return prediction_output['image_data']
    
    except Exception as e:
        logger.error(f"Error in output processing: {str(e)}")
        raise

# Load the model
model = model_fn()

@app.post("/invocations")
async def invoke_endpoint(data: Union[str, bytes] = None):
    """Endpoint for model invocation"""
    try:
        if data is None:
            logger.error("No input data provided")
            return {
                "error": "No input data provided",
                "status": "error",
                "details": "Request body is required and must contain either image data or S3 location"
            }
            
        input_object = input_fn(data, "application/json")
        prediction = predict_fn(input_object, model)
        return output_fn(prediction, "application/json")
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format: {str(e)}")
        return {
            "error": "Invalid JSON format",
            "status": "error",
            "details": str(e)
        }
    except Exception as e:
        logger.error(f"Error during invocation: {str(e)}")
        return {
            "error": "Internal server error",
            "status": "error",
            "details": str(e)
        }

@app.get("/ping")
async def ping():
    """Healthcheck endpoint"""
    return {"status": "healthy"}