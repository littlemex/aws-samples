from abc import ABC, abstractmethod
import io
import logging
import os
from pathlib import Path
import boto3
from PIL import Image
from rembg import remove, new_session
from cloudwatch_metrics import CloudWatchMetricsHandler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class InferenceProcessor(ABC):
    """Abstract base class for image background removal inference processing"""
    
    def __init__(self, model_name: str = 'u2net', use_cloudwatch: bool = True):
        self.model_name = model_name
        self.model_session = None
        self.cloudwatch_handler = CloudWatchMetricsHandler() if use_cloudwatch else None
        
    def initialize_model(self):
        """Initialize the model if not already loaded"""
        if self.model_session is None:
            self.model_session = self._load_model()
    
    def _load_model(self):
        """Load the model for inference"""
        try:
            model_path = self._download_models()
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
            model_session = new_session(self.model_name, model_path=model_path)
            logger.info(f"Successfully loaded model: {self.model_name}")
            
            return model_session
        except Exception as e:
            logger.error(f"Error loading model: {str(e)}")
            raise

    def _download_models(self) -> str:
        """Download model files if they don't exist"""
        model_dir_path = os.environ.get('MODEL_PATH', '/opt/ml/model')
        models_dir = Path(model_dir_path)
        model_path = models_dir / f"{self.model_name}.onnx"
        
        if not model_path.exists():
            logger.error(f"Model file not found: {model_path}")
            raise FileNotFoundError(f"Model file not found: {model_path}")
        
        return str(model_path)

    def process_image(self, image_data: bytes) -> bytes:
        """Process image using the loaded model"""
        try:
            self.initialize_model()
            
            image = Image.open(io.BytesIO(image_data))
            output_image = remove(image, session=self.model_session)
            img_byte_arr = io.BytesIO()
            output_image.save(img_byte_arr, format='PNG')
            return img_byte_arr.getvalue()
        except Exception as e:
            logger.error(f"Error processing image: {str(e)}")
            raise

    def update_backlog_metric(self, endpoint_name: str, backlog_size: int) -> None:
        """Update CloudWatch metrics for queue monitoring"""
        try:
            if self.cloudwatch_handler:
                self.cloudwatch_handler.put_backlog_metric(endpoint_name, backlog_size)
        except Exception as e:
            logger.error(f"Error updating backlog metric: {str(e)}")
            raise

    @abstractmethod
    async def read_input_image(self, input_bucket: str, input_key: str) -> bytes:
        """Read input image from storage"""
        pass

    @abstractmethod
    async def save_output_image(self, output_bytes: bytes, output_bucket: str, output_key: str) -> str:
        """Save output image to storage"""
        pass

    def parse_location(self, location: str) -> tuple[str, str]:
        """Parse URI into bucket and key"""
        if not location.startswith('s3://'):
            raise ValueError("Location must be an S3 URI (s3://)")
        parts = location.replace("s3://", "").split("/")
        bucket = parts[0]
        key = "/".join(parts[1:])
        logger.info(f"Parsed location - bucket: {bucket}, key: {key}")
        return bucket, key

class LocalInferenceProcessor(InferenceProcessor):
    """Local file system implementation of inference processor"""

    def __init__(self, model_name: str = 'u2net'):
        super().__init__(model_name, use_cloudwatch=False)

    # 画像がバイナリで body に入っているのでこのメソッドは不要だがそのまま残しておく
    async def read_input_image(self, input_bucket: str, input_key: str) -> bytes:
        """Read input image from local file system"""
        try:
            local_path = f"{input_bucket}/{input_key}"
            logger.info(f"Reading from local path: {local_path}")
            with open(local_path, 'rb') as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading input image: {str(e)}")
            raise

    async def save_output_image(self, output_bytes: bytes, output_bucket: str, output_key: str) -> str:
        """Save output image to local file system"""
        try:
            local_path = f"{output_bucket}/{output_key}"
            logger.info(f"Saving to local path: {local_path}")
            # Create output directory if it doesn't exist
            output_dir = Path(local_path).parent
            output_dir.mkdir(parents=True, exist_ok=True)
            
            with open(local_path, 'wb') as f:
                f.write(output_bytes)
            
            return f"s3://{output_bucket}/{output_key}"
        except Exception as e:
            logger.error(f"Error saving output image: {str(e)}")
            raise

class AWSInferenceProcessor(InferenceProcessor):
    """AWS S3 implementation of inference processor"""

    def __init__(self, model_name: str = 'u2net'):
        super().__init__(model_name, use_cloudwatch=True)
        self.s3 = boto3.client('s3')

    async def read_input_image(self, input_bucket: str, input_key: str) -> bytes:
        """Read input image from S3"""
        try:
            response = self.s3.get_object(Bucket=input_bucket, Key=input_key)
            return response['Body'].read()
        except Exception as e:
            logger.error(f"Error reading input image from S3: {str(e)}")
            raise

    async def save_output_image(self, output_bytes: bytes, output_bucket: str, output_key: str) -> str:
        """Save output image to S3"""
        try:
            self.s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=output_bytes,
                ContentType='image/png'
            )
            return f"s3://{output_bucket}/{output_key}"
        except Exception as e:
            logger.error(f"Error saving output image to S3: {str(e)}")
            raise