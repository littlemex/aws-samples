#!/usr/bin/env python3
import requests
import json
import os
import sys
import time
import logging
import mlflow

# ロガーの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_litellm_mlflow")

def setup_mlflow():
    """MLflow の設定を初期化"""
    tracking_arn = os.getenv("MLFLOW_TRACKING_ARN")
    if not tracking_arn:
        logger.error("MLFLOW_TRACKING_ARN が設定されていません")
        return False
    
    try:
        # MLflow の設定
        mlflow.set_tracking_uri(tracking_arn)
        logger.info(f"MLflow tracking URI を設定しました: {tracking_arn}")
        
        # 環境変数 MLFLOW_TRACKING_AUTH を設定
        os.environ["MLFLOW_TRACKING_AUTH"] = "arn"
        logger.info("MLFLOW_TRACKING_AUTH=arn を設定しました")
        
        # 実験名の設定
        experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME", "/litellm-monitoring")
        if not experiment_name.startswith("/"):
            experiment_name = f"/{experiment_name}"
        
        mlflow.set_experiment(experiment_name)
        logger.info(f"実験 '{experiment_name}' を設定しました")
        
        return True
    except Exception as e:
        logger.error(f"MLflow の設定に失敗: {str(e)}")
        logger.debug("詳細なエラー情報:", exc_info=True)
        return False

def test_litellm_api():
    """LiteLLM API をテストし、MLflow にログが送信されるかを確認する"""
    
    # MLflow の設定
    if not setup_mlflow():
        logger.error("MLflow の設定に失敗したため、テストを中止します")
        return False
    
    # 環境変数からAPIキーを取得（なければデフォルト値を使用）
    api_key = os.environ.get("LITELLM_MASTER_KEY", "sk-litellm-test-key")
    
    # APIエンドポイント
    url = "http://localhost:4001/chat/completions"
    
    # リクエストヘッダー
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    # リクエストボディ
    data = {
        "model": "bedrock-converse-us-claude-3-7-sonnet-v1",  # Bedrockモデルを使用
        "messages": [
            {
                "role": "user",
                "content": "こんにちは、今日の天気を教えてください。"
            }
        ],
        "user": "mlflow-test-user",
        "temperature": 0.2,
        "max_tokens": 100
    }
    
    try:
        logger.info(f"LiteLLM API にリクエストを送信: {url}")
        logger.info(f"リクエストデータ: {json.dumps(data, ensure_ascii=False, indent=2)}")
        
        # リクエスト送信
        response = requests.post(url, headers=headers, json=data)
        
        # レスポンスの確認
        if response.status_code == 200:
            response_json = response.json()
            logger.info("リクエスト成功!")
            logger.info(f"モデル: {response_json.get('model', 'unknown')}")
            logger.info(f"使用トークン: {response_json.get('usage', {}).get('total_tokens', 0)}")
            
            # レスポンスの内容を表示
            content = response_json.get("choices", [{}])[0].get("message", {}).get("content", "")
            logger.info(f"レスポンス内容: {content}")
            
            logger.info("MLflow にログが送信されたかを確認してください。")
            return True
        else:
            logger.error(f"リクエスト失敗: ステータスコード {response.status_code}")
            logger.error(f"エラーメッセージ: {response.text}")
            return False
    
    except Exception as e:
        logger.error(f"エラーが発生しました: {str(e)}")
        return False

if __name__ == "__main__":
    logger.info("LiteLLM API テストを開始します...")
    
    # 環境変数の確認
    tracking_arn = os.getenv("MLFLOW_TRACKING_ARN")
    if not tracking_arn:
        logger.error("MLFLOW_TRACKING_ARN が設定されていません")
        sys.exit(1)
    
    # AWS認証情報の確認
    aws_access_key = os.getenv("AWS_ACCESS_KEY_ID")
    aws_secret_key = os.getenv("AWS_SECRET_ACCESS_KEY")
    aws_region = os.getenv("AWS_REGION_NAME")
    if not all([aws_access_key, aws_secret_key, aws_region]):
        logger.warning("AWS認証情報が不完全です")
    
    # テスト実行
    success = test_litellm_api()
    
    if success:
        logger.info("テスト完了: 成功")
        logger.info("MLflow UI で実際にログが記録されているか確認してください")
        sys.exit(0)
    else:
        logger.error("テスト完了: 失敗")
        sys.exit(1)
