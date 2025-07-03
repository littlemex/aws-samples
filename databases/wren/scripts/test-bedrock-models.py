#!/usr/bin/env python3

import boto3
import os
import json
import sys

def test_model_access(model_id, region):
    """指定されたモデルへのアクセスをテストする"""
    try:
        print(f"モデル {model_id} (リージョン: {region}) をテスト中...")
        bedrock = boto3.client('bedrock-runtime', region_name=region)
        
        # シンプルなプロンプト
        prompt = "こんにちは、元気ですか？簡単な返答をお願いします。"
        
        # Claude モデル用のリクエスト形式
        request = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 100,
            "messages": [
                {"role": "user", "content": prompt}
            ]
        }
        
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps(request)
        )
        
        response_body = json.loads(response['body'].read())
        print(f"  モデル {model_id} テスト成功:")
        print(f"  応答: {response_body['content'][0]['text']}")
        return True
        
    except Exception as e:
        print(f"  モデル {model_id} テスト失敗: {str(e)}")
        return False

def main():
    region = os.environ.get('AWS_REGION_NAME', 'us-east-1')
    print(f"使用するデフォルトリージョン: {region}")
    
    # テスト対象のモデル
    models = [
        "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        "us.anthropic.claude-3-5-sonnet-20241022-v2:0",
        "us.anthropic.claude-3-5-sonnet-20240620-v1:0"
    ]
    
    # APAC リージョンのモデル
    apac_region = "ap-northeast-1"
    apac_models = [
        "apac.anthropic.claude-3-5-sonnet-20241022-v2:0"
    ]
    
    success = True
    
    print("=== 米国リージョンのモデルテスト ===")
    # 米国リージョンのモデルをテスト
    for model in models:
        if not test_model_access(model, region):
            success = False
    
    print("\n=== APAC リージョンのモデルテスト ===")
    # APAC リージョンのモデルをテスト
    for model in apac_models:
        if not test_model_access(model, apac_region):
            success = False
    
    print("\n=== テスト結果サマリー ===")
    if success:
        print("すべてのモデルテストに成功しました")
        return 0
    else:
        print("一部のモデルテストに失敗しました")
        print("失敗したモデルについては、以下を確認してください:")
        print("1. Amazon Bedrock コンソールでモデルへのアクセス権限が付与されているか")
        print("2. モデル ID が正確か（特に日付を含むバージョン）")
        print("3. 指定したリージョンでモデルが利用可能か")
        return 1

if __name__ == "__main__":
    sys.exit(main())
