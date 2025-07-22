#!/usr/bin/env python3
import boto3
import json
import os
import argparse
from datetime import datetime

def create_sample_data(bucket_name, prefix='data/', count=5):
    """
    S3バケットにサンプルデータを作成します。
    
    Args:
        bucket_name (str): S3バケット名
        prefix (str): オブジェクトのプレフィックス
        count (int): 作成するサンプルデータの数
    """
    s3 = boto3.client('s3')
    
    # バケットが存在するか確認
    try:
        s3.head_bucket(Bucket=bucket_name)
        print(f"バケット '{bucket_name}' が見つかりました。")
    except Exception as e:
        print(f"エラー: バケット '{bucket_name}' にアクセスできません。")
        print(f"詳細: {str(e)}")
        return
    
    # サンプルデータを作成
    for i in range(1, count + 1):
        # サンプルデータの作成
        sample_data = {
            "id": f"sample-{i}",
            "timestamp": datetime.now().isoformat(),
            "value": f"サンプル値 {i}",
            "metadata": {
                "type": "sample",
                "version": "1.0",
                "index": i
            }
        }
        
        # ファイル名の作成
        file_name = f"{prefix}sample-{i}.json"
        
        # S3にアップロード
        try:
            s3.put_object(
                Bucket=bucket_name,
                Key=file_name,
                Body=json.dumps(sample_data, ensure_ascii=False, indent=2),
                ContentType='application/json'
            )
            print(f"サンプルデータをアップロードしました: {file_name}")
        except Exception as e:
            print(f"エラー: ファイル '{file_name}' のアップロードに失敗しました。")
            print(f"詳細: {str(e)}")

def main():
    parser = argparse.ArgumentParser(description='S3バケットにサンプルデータを作成します。')
    parser.add_argument('bucket_name', help='S3バケット名')
    parser.add_argument('--prefix', default='data/', help='オブジェクトのプレフィックス (デフォルト: data/)')
    parser.add_argument('--count', type=int, default=5, help='作成するサンプルデータの数 (デフォルト: 5)')
    
    args = parser.parse_args()
    
    create_sample_data(args.bucket_name, args.prefix, args.count)

if __name__ == '__main__':
    main()
