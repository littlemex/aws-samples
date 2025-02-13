#!/usr/bin/env python3
import os
import json
import time
import boto3
from pathlib import Path

# FIXME: ローカルテストと SageMaker async inference へのテスト両方を実現したいです。.env の USE_AWS で AWS 利用とローカルでの利用を切り替えています。 

def request_background_removal(input_image_path: str, output_dir: str = "output"):
    """
    背景除去リクエストを送信し、結果を取得する
    
    Args:
        input_image_path: 入力画像のパス
        output_dir: 出力ディレクトリ（デフォルト: "output"）
    """
    # AWS クライアントの初期化
    sagemaker = boto3.client('sagemaker-runtime')
    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    
    # 環境変数の取得
    input_bucket = os.environ['INPUT_BUCKET']
    output_bucket = os.environ['OUTPUT_BUCKET']
    success_topic_arn = os.environ['SUCCESS_TOPIC_ARN']
    error_topic_arn = os.environ['ERROR_TOPIC_ARN']
    endpoint_name = os.environ['SAGEMAKER_ENDPOINT_NAME']
    
    # 入力画像をS3にアップロード
    input_key = f"input/{Path(input_image_path).name}"
    with open(input_image_path, 'rb') as f:
        s3.upload_fileobj(f, input_bucket, input_key)
    
    # 出力パスの設定
    output_key = f"output/{Path(input_image_path).stem}_output.png"
    
    # 非同期推論リクエストの送信
    response = sagemaker.invoke_endpoint_async(
        EndpointName=endpoint_name,
        InputLocation=f"s3://{input_bucket}/{input_key}",
        OutputLocation=f"s3://{output_bucket}/{output_key}"
    )
    
    print(f"Request submitted. Request ID: {response['InferenceId']}")
    
    # SNSトピックからの通知を待機
    print("Waiting for processing completion...")
    waiter = sns.get_waiter('topic_exists')
    waiter.wait(TopicArn=success_topic_arn)
    
    # 処理が完了したら出力画像をダウンロード
    output_path = Path(output_dir) / Path(output_key).name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    try:
        s3.download_file(output_bucket, output_key, str(output_path))
        print(f"Output image saved to: {output_path}")
    except Exception as e:
        print(f"Error downloading output image: {str(e)}")
        return

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='背景除去リクエストを送信')
    parser.add_argument('input_image', help='入力画像のパス')
    parser.add_argument('--output-dir', default='output', help='出力ディレクトリ（デフォルト: output）')
    
    args = parser.parse_args()
    request_background_removal(args.input_image, args.output_dir)