#!/usr/bin/env python3
"""
Cognitoテストユーザーを作成するスクリプト
"""

import json
import os
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv

def create_test_user(
    user_pool_id: str,
    username: str,
    email: str,
    temp_password: str
):
    """テストユーザーを作成する"""
    cognito = boto3.client('cognito-idp')
    
    try:
        # 既存のユーザーを削除（存在する場合）
        try:
            cognito.admin_delete_user(
                UserPoolId=user_pool_id,
                Username=username
            )
            print(f"既存のユーザー {username} を削除しました")
        except ClientError as e:
            if e.response['Error']['Code'] != 'UserNotFoundException':
                raise e
        
        # 新しいユーザーを作成
        response = cognito.admin_create_user(
            UserPoolId=user_pool_id,
            Username=username,
            TemporaryPassword=temp_password,
            UserAttributes=[
                {
                    'Name': 'email',
                    'Value': email
                },
                {
                    'Name': 'email_verified',
                    'Value': 'true'
                }
            ],
            MessageAction='SUPPRESS'  # 通知メールを送信しない
        )
        
        # 一時パスワードを永続的なパスワードに設定
        cognito.admin_set_user_password(
            UserPoolId=user_pool_id,
            Username=username,
            Password=temp_password,
            Permanent=True
        )
        
        print(f"""
テストユーザーを作成しました:
Username: {username}
Email: {email}
Password: {temp_password}
        """)
        
        return response['User']
        
    except Exception as e:
        print(f"エラー: {str(e)}")
        raise e

if __name__ == "__main__":
    # .envファイルを読み込む
    env_path = Path(__file__).parent / '.env'
    if not env_path.exists():
        print("Error: .envファイルが見つかりません")
        print(".env.sampleをコピーして.envを作成し、適切な値を設定してください")
        exit(1)
    
    load_dotenv(env_path)
    
    # 環境変数から認証情報を取得
    email = os.getenv('TEST_USER_EMAIL')
    password = os.getenv('TEST_USER_PASSWORD')
    
    if not email or not password:
        print("Error: 環境変数が設定されていません")
        print("TEST_USER_EMAIL と TEST_USER_PASSWORD を.envファイルで設定してください")
        exit(1)
    
    # CDKスタックの出力から User Pool ID を取得
    stack_outputs_file = os.path.join(
        os.path.dirname(__file__),
        "../cdk/cdk-outputs.json"
    )
    
    try:
        with open(stack_outputs_file, 'r') as f:
            outputs = json.load(f)
            user_pool_id = outputs['AiGatewayStack']['UserPoolId']
    except FileNotFoundError:
        print(f"Error: {stack_outputs_file} が見つかりません")
        print("CDKスタックのデプロイ後に実行してください")
        exit(1)
    
    # テストユーザーを作成
    create_test_user(
        user_pool_id=user_pool_id,
        username=email,  # メールアドレスをユーザー名として使用
        email=email,
        temp_password=password
    )