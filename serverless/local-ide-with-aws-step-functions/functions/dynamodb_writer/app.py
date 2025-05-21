import boto3
import os
import json
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    logger.info(f"イベント受信: {json.dumps(event)}")
    
    try:
        # 入力データの検証
        if not isinstance(event, dict):
            raise ValueError("入力データは辞書形式である必要があります")
        
        # 必須フィールドの確認
        required_fields = ['id', 'timestamp']
        for field in required_fields:
            if field not in event:
                raise ValueError(f"必須フィールド '{field}' が見つかりません")
        
        # DynamoDBに保存するアイテムを作成
        item = {
            'id': event['id'],
            'timestamp': event['timestamp'],
            'createdAt': datetime.now().isoformat()
        }
        
        # fileInfoフィールドがあれば追加
        if 'fileInfo' in event:
            item['fileInfo'] = event['fileInfo']
        
        # contentフィールドがあれば追加
        if 'content' in event:
            item['content'] = event['content']
        
        # DynamoDBにアイテムを保存
        table.put_item(Item=item)
        
        logger.info(f"DynamoDBにデータを保存しました: {item['id']}")
        
        return {
            "success": True,
            "itemId": item['id'],
            "message": f"データをDynamoDBテーブル {table_name} に保存しました"
        }
    
    except Exception as e:
        logger.error(f"エラーが発生しました: {str(e)}")
        raise
