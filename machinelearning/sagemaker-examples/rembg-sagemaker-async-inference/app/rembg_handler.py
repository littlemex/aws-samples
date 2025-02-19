import os
from PIL import Image
from rembg.sessions.base import BaseSession
from rembg import remove, new_session
import logging
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
load_dotenv()

model_dir_path = os.environ.get("MODEL_PATH", "/opt/ml/model")
model_name = os.environ.get("MODEL_NAME", "u2net")


class RembgHandler:
    # request_model_name はリクエストヘッダの情報ごとにモデルを切り替える対応用、未実装
    def __init__(self, request_model_name: str):
        # 絶対 new_session でgithubからモデルダウンロードする.. /opt/ml/model をロードしても意味ない状態
        self.session = new_session(model_name)

    def predict(self, image: Image.Image) -> Image.Image:
        """Remove background from image using the created session"""
        try:
            logger.info("Starting background removal with rembg")
            output = remove(image, session=self.session)
            logger.info(f"Remove operation completed, output type: {type(output)}")
            logger.info(
                f"Successfully processed image: size={output.size}, mode={output.mode}"
            )
            return output

        except Exception as e:
            logger.error(f"Error in predict: {str(e)}")
            raise
