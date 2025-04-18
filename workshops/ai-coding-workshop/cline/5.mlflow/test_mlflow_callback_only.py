#!/usr/bin/env python3
import os
import logging
import asyncio
from datetime import datetime
from mlflow_callback import MLflowCallback

# ロガーの設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_mlflow_callback")

# MLflow のデバッグログを有効化
logging.getLogger('mlflow').setLevel(logging.DEBUG)
logging.getLogger('sagemaker_mlflow').setLevel(logging.DEBUG)
logging.getLogger('botocore').setLevel(logging.DEBUG)
logging.getLogger('urllib3').setLevel(logging.DEBUG)

def print_env_vars():
    """環境変数の状態を表示"""
    logger.info("環境変数の状態:")
    for var in ["MLFLOW_TRACKING_URI", "MLFLOW_TRACKING_ARN", "MLFLOW_EXPERIMENT_NAME"]:
        value = os.getenv(var)
        if var == "MLFLOW_TRACKING_ARN" and not value:
            logger.error(f"{var} が設定されていません。このテストは失敗します。")
        else:
            logger.info(f"{var}: {value}")

async def test_mlflow_callback():
    """MLflowCallback クラスの単体テスト"""
    print_env_vars()
    
    # 必須環境変数のチェック
    if not os.getenv("MLFLOW_TRACKING_ARN"):
        logger.error("MLFLOW_TRACKING_ARN が設定されていません")
        return False
    try:
        # MLflowCallback インスタンスの作成
        callback = MLflowCallback()
        logger.info("MLflowCallback の初期化に成功")

        # テスト用のダミーデータ
        kwargs = {
            "model": "test-model",
            "messages": [{"role": "user", "content": "テストメッセージ"}],
            "user": "test-user",
            "temperature": 0.7,
            "max_tokens": 100,
            "litellm_params": {
                "metadata": {
                    "user_id": "test-user-id"
                }
            }
        }
        
        response_obj = {
            "choices": [
                {
                    "message": {"content": "テストレスポンス"}
                }
            ],
            "usage": {
                "prompt_tokens": 10,
                "completion_tokens": 20,
                "total_tokens": 30
            }
        }

        # 成功イベントのテスト
        start_time = datetime.now().timestamp()
        end_time = start_time + 1.0
        
        await callback.async_log_success_event(
            kwargs=kwargs,
            response_obj=response_obj,
            start_time=start_time,
            end_time=end_time
        )
        
        logger.info("MLflow へのログ記録に成功")
        return True

    except Exception as e:
        logger.error(f"テスト中にエラーが発生: {str(e)}")
        logger.debug("詳細なエラー情報:", exc_info=True)
        return False

if __name__ == "__main__":
    # 非同期関数を実行
    success = asyncio.run(test_mlflow_callback())
    exit(0 if success else 1)
