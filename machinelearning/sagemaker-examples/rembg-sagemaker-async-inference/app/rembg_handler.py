import os
from PIL import Image
from rembg.sessions.base import BaseSession
from rembg import remove, new_session
import logging

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

model_dir_path = os.environ.get("MODEL_PATH", "/opt/ml/model")


class RembgHandler:
    def __init__(self, model_name: str):
        # 絶対 new_session でgithubからモデルダウンロードするのでモンキーパッチをあてた
        def custom_download_models(cls, *args, **kwargs):
            logger.info("Custom download_models method called")
            return f"{model_dir_path}/{model_name}.onnx"

        BaseSession.download_models = classmethod(custom_download_models)
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
