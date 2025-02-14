#!/usr/bin/env python3
import os
import json
import time
import boto3
import requests
import logging
from pathlib import Path
from typing import Optional, Dict, Any
from dotenv import load_dotenv
from botocore.exceptions import WaiterError

# ロガーの設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# .env ファイルから環境変数を読み込む
load_dotenv()

def request_background_removal_local(input_image_path: str, output_path: Path) -> bool:
    """
    ローカルサーバーに背景除去リクエストを送信
    
    Args:
        input_image_path: 入力画像のパス
        output_path: 出力先のパス
    Returns:
        bool: 処理が成功したかどうか
    """
    try:
        # 入力と出力のパスをs3://形式で指定（ローカルでもs3://形式を使用）
        request_data = {
            "InputLocation": f"s3://local-bucket/{input_image_path}",
            "OutputLocation": f"s3://local-bucket/{output_path}"
        }
        
        logger.info(f"Sending request to local server with input file: {input_image_path}")
        logger.debug(f"Request data: {json.dumps(request_data, indent=2)}")
        
        response = requests.post(
            'http://localhost:8080/invocations',
            json=request_data,
            headers={'Content-Type': 'application/json'}
        )
        
        logger.info(f"Response status code: {response.status_code}")
        logger.debug(f"Response headers: {dict(response.headers)}")
        
        if response.status_code != 200:
            logger.error(f"Error response body: {response.text}")
            return False
            
        logger.info(f"Output will be saved to: {output_path}")
        return True
            
    except Exception as e:
        logger.exception(f"Error during local processing: {str(e)}")
        return False

def wait_for_sns_notification(sns_client, sqs_client: boto3.client, queue_url: str, inference_id: str, timeout: int = 300) -> Dict[str, Any]:
    """
    SNS通知をSQSで受信して処理完了を待機
    
    Args:
        sns_client: SNSクライアント
        sqs_client: SQSクライアント
        queue_url: SQSキューのURL
        inference_id: 推論ID
        timeout: タイムアウト時間（秒）
    Returns:
        Dict[str, Any]: 処理結果
    """
    start_time = time.time()
    while (time.time() - start_time) < timeout:
        response = sqs_client.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=20
        )
        
        messages = response.get('Messages', [])
        for message in messages:
            body = json.loads(message['Body'])
            message_inference_id = json.loads(body['Message']).get('inferenceId')
            
            if message_inference_id == inference_id:
                # メッセージを処理したら削除
                sqs_client.delete_message(
                    QueueUrl=queue_url,
                    ReceiptHandle=message['ReceiptHandle']
                )
                return json.loads(body['Message'])
                
        logger.info(f"Waiting for processing completion... ({int(time.time() - start_time)}s elapsed)")
        
    raise TimeoutError(f"Timeout waiting for inference completion after {timeout} seconds")

def request_background_removal_aws(input_image_path: str, output_path: Path) -> bool:
    """
    SageMaker非同期推論エンドポイントに背景除去リクエストを送信
    
    Args:
        input_image_path: 入力画像のパス
        output_path: 出力先のパス
    Returns:
        bool: 処理が成功したかどうか
    """
    try:
        # AWS クライアントの初期化
        sagemaker = boto3.client('sagemaker-runtime')
        s3 = boto3.client('s3')
        sns = boto3.client('sns')
        sqs = boto3.client('sqs')
        
        # 環境変数の取得
        input_bucket = os.environ['INPUT_BUCKET']
        output_bucket = os.environ['OUTPUT_BUCKET']
        success_topic_arn = os.environ['SUCCESS_TOPIC_ARN']
        error_topic_arn = os.environ['ERROR_TOPIC_ARN']
        endpoint_name = os.environ['SAGEMAKER_ENDPOINT_NAME']
        queue_url = os.environ['SQS_QUEUE_URL']
        
        logger.info(f"AWS Mode - Input bucket: {input_bucket}, Output bucket: {output_bucket}")
        
        # 入力画像をS3にアップロード
        input_key = f"input/{Path(input_image_path).name}"
        with open(input_image_path, 'rb') as f:
            logger.info(f"Uploading input file to S3: {input_bucket}/{input_key}")
            s3.upload_fileobj(f, input_bucket, input_key)
        
        # 出力パスの設定
        output_key = f"output/{Path(input_image_path).stem}_output.png"
        
        # 非同期推論リクエストの送信
        logger.info(f"Sending async inference request to endpoint: {endpoint_name}")
        response = sagemaker.invoke_endpoint_async(
            EndpointName=endpoint_name,
            InputLocation=f"s3://{input_bucket}/{input_key}",
            OutputLocation=f"s3://{output_bucket}/{output_key}"
        )
        
        inference_id = response['InferenceId']
        logger.info(f"Request submitted. Request ID: {inference_id}")
        
        # SNSトピックからの通知を待機
        logger.info("Waiting for processing completion notification...")
        try:
            notification = wait_for_sns_notification(sns, sqs, queue_url, inference_id)
            
            if notification.get('status') == 'error':
                logger.error(f"Processing failed: {notification.get('errorMessage')}")
                return False
                
            # 処理が完了したら出力画像をダウンロード
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            logger.info(f"Downloading result from S3: {output_bucket}/{output_key}")
            s3.download_file(output_bucket, output_key, str(output_path))
            logger.info(f"Output image saved to: {output_path}")
            return True
            
        except TimeoutError as e:
            logger.error(f"Timeout waiting for processing completion: {str(e)}")
            return False
            
    except Exception as e:
        logger.exception(f"Error during AWS processing: {str(e)}")
        return False

def request_background_removal(input_image_path: str, output_dir: str = "outputs") -> bool:
    """
    背景除去リクエストを送信し、結果を取得する
    
    Args:
        input_image_path: 入力画像のパス
        output_dir: 出力ディレクトリ（デフォルト: "outputs"）
    Returns:
        bool: 処理が成功したかどうか
    """
    # 出力パスの設定
    output_path = Path(output_dir) / f"{Path(input_image_path).stem}_output.png"
    
    # USE_AWS環境変数に基づいて処理を分岐
    use_aws = os.getenv('USE_AWS', 'false').lower() == 'true'
    logger.info(f"Mode: {'AWS' if use_aws else 'Local'}")
    logger.info(f"Input path: {input_image_path}")
    logger.info(f"Output path: {output_path}")
    
    if use_aws:
        return request_background_removal_aws(input_image_path, output_path)
    else:
        return request_background_removal_local(input_image_path, output_path)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='背景除去リクエストを送信')
    parser.add_argument('input_image', help='入力画像のパス')
    parser.add_argument('--output-dir', default='outputs', help='出力ディレクトリ（デフォルト: outputs）')
    
    args = parser.parse_args()
    success = request_background_removal(args.input_image, args.output_dir)
    
    if not success:
        exit(1)