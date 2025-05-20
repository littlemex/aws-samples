import boto3
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
bucket_name = os.environ['BUCKET_NAME']
prefix = os.environ.get('PREFIX', '')  # オプションのプレフィックス

def lambda_handler(event, context):
    logger.info(f"イベント受信: {json.dumps(event)}")
    
    try:
        # S3バケット内のオブジェクト一覧を取得
        response = s3.list_objects_v2(
            Bucket=bucket_name,
            Prefix=prefix,
            MaxKeys=10
        )
        
        # オブジェクトが存在するか確認
        if 'Contents' in response and len(response['Contents']) > 0:
            # 最新のオブジェクトを取得（最終更新日時でソート）
            latest_object = sorted(
                response['Contents'], 
                key=lambda obj: obj['LastModified'], 
                reverse=True
            )[0]
            
            # オブジェクトの内容を取得
            file_key = latest_object['Key']
            file_obj = s3.get_object(Bucket=bucket_name, Key=file_key)
            file_content = file_obj['Body'].read().decode('utf-8')
            
            try:
                # JSONとして解析を試みる
                content_json = json.loads(file_content)
            except json.JSONDecodeError:
                # JSONでない場合はテキストとして扱う
                content_json = {"text": file_content}
            
            logger.info(f"S3からデータを読み取りました: {file_key}")
            
            return {
                "hasData": True,
                "data": {
                    "fileInfo": {
                        "bucket": bucket_name,
                        "key": file_key,
                        "lastModified": latest_object['LastModified'].isoformat(),
                        "size": latest_object['Size']
                    },
                    "content": content_json
                }
            }
        else:
            logger.info(f"S3バケット {bucket_name} にデータが見つかりませんでした")
            return {
                "hasData": False,
                "message": f"S3バケット {bucket_name} にデータが見つかりませんでした"
            }
    
    except Exception as e:
        logger.error(f"エラーが発生しました: {str(e)}")
        raise
