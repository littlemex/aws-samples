import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"イベント受信: {json.dumps(event)}")
    
    # 通知メッセージを作成
    message = event.get('message', 'デフォルト通知メッセージ')
    execution_id = event.get('executionId', 'unknown')
    execution_time = event.get('executionStartTime', 'unknown')
    
    # 実際のプロダクション環境では、SNSやSlackなどに通知を送信
    # この例ではログ出力のみ
    logger.info(f"通知: {message}")
    logger.info(f"実行ID: {execution_id}")
    logger.info(f"実行開始時間: {execution_time}")
    
    return {
        "success": True,
        "notificationType": "log",
        "message": message
    }
