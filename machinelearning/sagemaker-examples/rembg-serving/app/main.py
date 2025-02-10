import logging
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
import io
from PIL import Image
from rembg import remove, new_session
from pathlib import Path
from pydantic import BaseModel
from typing import Optional

# ロガーの設定
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# ファイルハンドラーの設定
file_handler = logging.FileHandler('app.log')
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# コンソールハンドラーの設定
console_handler = logging.StreamHandler()
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

app = FastAPI(title="Background Removal API")

# モデルのセッションを保持する辞書
model_sessions = {}

def get_model_session(model_name: str = "u2net"):
    """モデルセッションを取得または作成"""
    if model_name not in model_sessions:
        logger.info(f"Creating new model session for {model_name}")
        models_dir = Path(__file__).parent.parent / "models"
        model_path = models_dir / f"{model_name}.onnx"
        if not model_path.exists():
            logger.error(f"Model file not found: {model_path}")
            raise FileNotFoundError(f"Model file not found: {model_path}")
        model_sessions[model_name] = new_session(model_name, model_path=str(model_path))
        logger.info(f"Successfully created model session for {model_name}")
    return model_sessions[model_name]

class RemoveBackgroundResponse(BaseModel):
    """背景削除APIのレスポンスモデル"""
    message: str
    error: Optional[str] = None

@app.post("/remove-background", response_model=RemoveBackgroundResponse)
async def remove_background(
    file: UploadFile = File(...),
    model: str = "u2net"
) -> Response:
    """
    画像の背景を削除するエンドポイント
    
    Args:
        file: アップロードされた画像ファイル
        model: 使用するモデル名（デフォルト: u2net)
    
    Returns:
        処理された画像(PNG形式)
    """
    logger.info(f"Processing image: {file.filename} with model: {model}")
    try:
        # 画像を読み込み
        image_data = await file.read()
        input_image = Image.open(io.BytesIO(image_data))
        logger.debug(f"Successfully loaded image: {file.filename}")
        
        # モデルセッションを取得
        session = get_model_session(model)
        
        # 背景を削除
        logger.info("Removing background from image")
        output_image = remove(input_image, session=session)
        logger.info("Successfully removed background")
        
        # 画像をバイトストリームに変換
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        img_byte_arr = img_byte_arr.getvalue()
        
        # 画像を返す
        logger.info(f"Returning processed image for {file.filename}")
        return Response(
            content=img_byte_arr,
            media_type="image/png",
            headers={"Content-Disposition": f"attachment; filename={file.filename.rsplit('.', 1)[0]}_nobg.png"}
        )
        
    except Exception as e:
        logger.error(f"Error processing image {file.filename}: {str(e)}", exc_info=True)
        return RemoveBackgroundResponse(
            message="Error processing image",
            error=str(e)
        )

@app.get("/health")
async def health_check():
    """ヘルスチェックエンドポイント"""
    logger.debug("Health check requested")
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting Background Removal API server")
    uvicorn.run(app, host="0.0.0.0", port=8000)