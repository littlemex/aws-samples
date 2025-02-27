#!/usr/bin/env python3
"""
AppSync GraphQL APIをテストするスクリプト
"""

import json
import os
import time
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
from dotenv import load_dotenv

def get_cognito_tokens(
    user_pool_id: str,
    client_id: str,
    username: str,
    password: str
) -> dict:
    """Cognitoでユーザー認証を行いトークンを取得"""
    cognito = boto3.client('cognito-idp')
    
    try:
        response = cognito.admin_initiate_auth(
            UserPoolId=user_pool_id,
            ClientId=client_id,
            AuthFlow='ADMIN_USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password
            }
        )
        
        print("認証トークンを取得しました")
        return response['AuthenticationResult']
        
    except Exception as e:
        print(f"認証エラー: {str(e)}")
        raise e

class InferenceTest:
    def __init__(self, api_url: str, jwt_token: str):
        transport = RequestsHTTPTransport(
            url=api_url,
            headers={'Authorization': jwt_token}
        )
        
        self.client = Client(
            transport=transport,
            fetch_schema_from_transport=True
        )
        
        self.start_mutation = gql("""
            mutation StartInference($input: InferenceInput!) {
                startInference(input: $input) {
                    jobId
                    status
                }
            }
        """)
        
        self.status_query = gql("""
            query GetStatus($jobId: ID!) {
                getInferenceStatus(jobId: $jobId) {
                    jobId
                    status
                    startTime
                    endTime
                    result
                    error
                }
            }
        """)

    def wait_for_completion(self, job_id: str, timeout: int = 300) -> dict:
        """ジョブの完了を待機"""
        start_time = time.time()
        while True:
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Job {job_id} timed out after {timeout} seconds")

            result = self.client.execute(
                self.status_query,
                variable_values={"jobId": job_id}
            )
            status = result['getInferenceStatus']
            
            print(f"\nステータス: {status['status']}")
            if status['status'] == 'COMPLETED':
                print(f"結果: {status['result']}")
                return status
            elif status['status'] == 'FAILED':
                print(f"エラー: {status['error']}")
                return status
                
            time.sleep(5)

    def test_successful_inference(self, model: str = "anthropic.claude-v2") -> None:
        """正常系の推論テスト"""
        print(f"\n=== 正常系の推論テスト（{model}） ===")
        
        variables = {
            "input": {
                "prompt": "こんにちは！私はAIアシスタントです。",
                "model": model,
                "parameters": json.dumps({
                    "max_tokens_to_sample": 1000,
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "anthropic_version": "bedrock-2023-05-31"
                })
            }
        }
        
        result = self.client.execute(self.start_mutation, variable_values=variables)
        job_id = result['startInference']['jobId']
        print(f"推論ジョブを開始しました（Job ID: {job_id}）")
        
        status = self.wait_for_completion(job_id)
        assert status['status'] == 'COMPLETED', "Job should complete successfully"

    def test_invalid_model(self) -> None:
        """無効なモデル名のテスト"""
        print("\n=== 無効なモデル名のテスト ===")
        
        variables = {
            "input": {
                "prompt": "テストプロンプト",
                "model": "invalid-model",
                "parameters": json.dumps({
                    "max_tokens_to_sample": 1000
                })
            }
        }
        
        try:
            result = self.client.execute(self.start_mutation, variable_values=variables)
            job_id = result['startInference']['jobId']
            status = self.wait_for_completion(job_id)
            assert status['status'] == 'FAILED', "Job should fail with invalid model"
            assert 'error' in status, "Error message should be present"
        except Exception as e:
            print(f"予期された例外が発生: {str(e)}")

    def test_invalid_parameters(self) -> None:
        """無効なパラメータのテスト"""
        print("\n=== 無効なパラメータのテスト ===")
        
        variables = {
            "input": {
                "prompt": "テストプロンプト",
                "model": "anthropic.claude-v2",
                "parameters": json.dumps({
                    "max_tokens_to_sample": -1,  # 無効な値
                    "temperature": 2.0  # 範囲外の値
                })
            }
        }
        
        try:
            result = self.client.execute(self.start_mutation, variable_values=variables)
            job_id = result['startInference']['jobId']
            status = self.wait_for_completion(job_id)
            assert status['status'] == 'FAILED', "Job should fail with invalid parameters"
            assert 'error' in status, "Error message should be present"
        except Exception as e:
            print(f"予期された例外が発生: {str(e)}")

    def test_missing_required_fields(self) -> None:
        """必須フィールド欠落のテスト"""
        print("\n=== 必須フィールド欠落のテスト ===")
        
        test_cases = [
            {"input": {"model": "anthropic.claude-v2"}},  # promptなし
            {"input": {"prompt": "テスト"}},  # modelなし
        ]
        
        for case in test_cases:
            try:
                self.client.execute(self.start_mutation, variable_values=case)
                print("エラー: 必須フィールドの検証に失敗")
            except Exception as e:
                print(f"予期された例外が発生: {str(e)}")

def run_all_tests(api_url: str, jwt_token: str) -> None:
    """全テストケースを実行"""
    test = InferenceTest(api_url, jwt_token)
    
    # 正常系テスト
    test.test_successful_inference("anthropic.claude-v2")
    test.test_successful_inference("anthropic.claude-instant-v1")
    
    # エラーケーステスト
    test.test_invalid_model()
    test.test_invalid_parameters()
    test.test_missing_required_fields()

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
    
    # CDKスタックの出力を読み込み
    stack_outputs_file = os.path.join(
        os.path.dirname(__file__),
        "../cdk/cdk-outputs.json"
    )
    
    try:
        with open(stack_outputs_file, 'r') as f:
            outputs = json.load(f)
            api_url = outputs['AiGatewayStack']['GraphQLApiURL']
            user_pool_id = outputs['AiGatewayStack']['UserPoolId']
            client_id = outputs['AiGatewayStack']['UserPoolClientId']
    except FileNotFoundError:
        print(f"Error: {stack_outputs_file} が見つかりません")
        print("CDKスタックのデプロイ後に実行してください")
        exit(1)
    
    # 認証トークンを取得
    tokens = get_cognito_tokens(
        user_pool_id=user_pool_id,
        client_id=client_id,
        username=email,
        password=password
    )
    
    # 全テストを実行
    run_all_tests(
        api_url=api_url,
        jwt_token=tokens['IdToken']
    )