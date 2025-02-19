from abc import ABC, abstractmethod
import io
import logging
import os
from pathlib import Path
import boto3
from PIL import Image
from rembg_handler import RembgHandler
from cloudwatch_metrics import CloudWatchMetricsHandler

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class InferenceProcessor(ABC):
    """Abstract base class for image background removal inference processing"""

    def __init__(self, model_name: str = "u2net", use_cloudwatch: bool = True):
        self.model_name = model_name
        self._create_session()
        self.cloudwatch_handler = CloudWatchMetricsHandler() if use_cloudwatch else None

        # Prepare model at initialization
        try:
            logger.info(f"Initializing model files for {self.model_name}")
            self._check_models()
        except Exception as e:
            logger.error(
                f"Failed to prepare model files during initialization: {str(e)}"
            )
            raise

    def _create_session(self):
        try:
            import torch

            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                torch.cuda.set_per_process_memory_fraction(0.8)
                logger.info("Using GPU for inference")
            else:
                logger.info("Using CPU for inference")

            # Create RembgHandler instance
            self.handler = RembgHandler(self.model_name)
            logger.info(
                f"Successfully created RembgHandler for model: {self.model_name}"
            )

        except Exception as e:
            logger.error(f"Error loading model: {str(e)}")
            raise

    def _check_models(self) -> str:
        """Download model files if they don't exist"""
        model_dir_path = os.environ.get("MODEL_PATH", "/opt/ml/model")
        models_dir = Path(model_dir_path)
        model_path = models_dir / f"{self.model_name}.onnx"
        tar_path = models_dir / "model.tar.gz"

        logger.info(f"Checking for model files in {models_dir}")
        logger.info(f"Looking for model file: {model_path}")
        logger.info(f"Looking for tar archive: {tar_path}")

        if not model_path.exists():
            if tar_path.exists():
                logger.info(f"Found tar archive at {tar_path}")
                logger.info(f"Starting model extraction from {tar_path}")
                import tarfile

                with tarfile.open(tar_path, "r:gz") as tar:
                    logger.info("Extracting tar archive contents...")
                    tar.extractall(path=models_dir)
                    logger.info(f"Extraction completed to {models_dir}")

                if not model_path.exists():
                    logger.error(f"Model file not found after extraction: {model_path}")
                    logger.error("Contents of model directory:")
                    for file in models_dir.iterdir():
                        logger.error(f"- {file}")
                    raise FileNotFoundError(
                        f"Model file not found after extraction: {model_path}"
                    )
            else:
                logger.error(
                    f"Neither model file nor tar archive found: {model_path}, {tar_path}"
                )
                raise FileNotFoundError(
                    f"Neither model file nor tar archive found: {model_path}, {tar_path}"
                )
        else:
            logger.info(f"Found existing model file at {model_path}")

        self.model_path = model_path
        logger.info(f"Model files successfully are prepared at: {self.model_path}")

        return str(self.model_path)

    def process_image(self, image_data: bytes) -> bytes:
        """Process image using the loaded model"""
        try:
            image = Image.open(io.BytesIO(image_data))
            logger.info(
                f"Input image opened successfully: size={image.size}, mode={image.mode}"
            )

            output_image = self.handler.predict(image)
            logger.info(f"Prediction completed: output_image type={type(output_image)}")
            img_byte_arr = io.BytesIO()
            output_image.save(img_byte_arr, format="PNG")
            logger.info("Successfully saved output image to bytes")

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
    async def save_output_image(
        self, output_bytes: bytes, output_bucket: str, output_key: str
    ) -> str:
        """Save output image to storage"""
        pass

    def parse_location(self, location: str) -> tuple[str, str]:
        """Parse URI into bucket and key"""
        if not location.startswith("s3://"):
            raise ValueError("Location must be an S3 URI (s3://)")
        parts = location.replace("s3://", "").split("/")
        bucket = parts[0]
        key = "/".join(parts[1:])
        logger.info(f"Parsed location - bucket: {bucket}, key: {key}")
        return bucket, key


class LocalInferenceProcessor(InferenceProcessor):
    """Local file system implementation of inference processor"""

    def __init__(self, model_name: str = "u2net"):
        super().__init__(model_name, use_cloudwatch=False)

    async def save_output_image(
        self, output_bytes: bytes, output_bucket: str, output_key: str
    ) -> str:
        """Save output image to local file system"""
        try:
            local_path = f"{output_bucket}/{output_key}"
            logger.info(f"Saving to local path: {local_path}")
            # Create output directory if it doesn't exist
            output_dir = Path(local_path).parent
            output_dir.mkdir(parents=True, exist_ok=True)

            with open(local_path, "wb") as f:
                f.write(output_bytes)

            return f"s3://{output_bucket}/{output_key}"
        except Exception as e:
            logger.error(f"Error saving output image: {str(e)}")
            raise


class AWSInferenceProcessor(InferenceProcessor):
    """AWS S3 implementation of inference processor"""

    def __init__(self, model_name: str = "u2net"):
        super().__init__(model_name, use_cloudwatch=True)
        self.s3 = boto3.client("s3")

    async def save_output_image(
        self, output_bytes: bytes, output_bucket: str, output_key: str
    ) -> str:
        """Save output image to S3"""
        try:
            self.s3.put_object(
                Bucket=output_bucket,
                Key=output_key,
                Body=output_bytes,
                ContentType="image/png",
            )
            return f"s3://{output_bucket}/{output_key}"
        except Exception as e:
            logger.error(f"Error saving output image to S3: {str(e)}")
            raise
