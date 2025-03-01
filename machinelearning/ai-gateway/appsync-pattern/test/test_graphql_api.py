#!/usr/bin/env python3
"""
AppSync GraphQL APIをテストするスクリプト
"""

import json
import os
import asyncio
import logging
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
from gql.transport.websockets import WebsocketsTransport
from dotenv import load_dotenv
from test_helpers import (
    JobStatus,
    StatusTransition,
    wait_for_job_completion,
    verify_job_status,
    create_test_parameters
)

# デバッグログの設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# WebSocketのデバッグログを有効化
logging.getLogger('websockets').setLevel(logging.DEBUG)
logging.getLogger('gql.transport.websockets').setLevel(logging.DEBUG)

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
        
        logger.info("=== Cognito認証情報 ===")
        logger.info(f"AccessToken: {response['AuthenticationResult'].get('AccessToken')[:20]}...")
        logger.info(f"IdToken: {response['AuthenticationResult'].get('IdToken')[:20]}...")
        logger.info(f"RefreshToken: {response['AuthenticationResult'].get('RefreshToken')[:20]}...")
        logger.info(f"TokenType: {response['AuthenticationResult'].get('TokenType')}")
        logger.info("=== 認証情報終了 ===")
        return response['AuthenticationResult']
        
    except Exception as e:
        logger.error(f"認証エラー: {str(e)}")
        raise

class InferenceTest:
    def __init__(self, api_url: str, jwt_token: str):
        logger.info("=== 認可トークン ===")
        logger.info(f"Using token: {jwt_token[:30]}...")
        logger.info("=== 認可トークン終了 ===")

        self.http_transport = RequestsHTTPTransport(
            url=api_url,
            headers={'Authorization': jwt_token}
        )
        
        from urllib.parse import urlparse

        # WebSocket transport for subscriptions
        parsed_url = urlparse(api_url)
        host = parsed_url.netloc
        ws_url = f"wss://{host.replace('appsync-api', 'appsync-realtime-api')}/graphql"
        
        logger.debug(f"WebSocket URL: {ws_url}")
        
        # WebSocket用のホストを取得
        ws_host = host.replace('appsync-api', 'appsync-realtime-api')
        
        # AppSync WebSocket用のヘッダーを設定
        auth_token = jwt_token.replace('Lambda-Auth-', '')
        headers = {
            'Authorization': auth_token
        }

        # AppSync WebSocket用の初期化ペイロードを設定
        init_payload = {
            "type": "connection_init",
            "payload": {
                "host": ws_host,
                "Authorization": auth_token
            }
        }

        self.ws_transport = WebsocketsTransport(
            url=ws_url,
            headers=headers,
            subprotocols=['graphql-ws'],
            keep_alive_timeout=600,  # 10分（5分の処理 + バッファ）
            ping_interval=30,
            pong_timeout=20,
            connect_timeout=60,
            close_timeout=60,
            init_payload=init_payload
        )
        
        # Create separate clients for HTTP and WebSocket
        self.http_client = Client(
            transport=self.http_transport,
            fetch_schema_from_transport=True
        )
        
        self.ws_client = Client(
            transport=self.ws_transport,
            fetch_schema_from_transport=True,
            execute_timeout=None
        )
        
        # GraphQL operations
        self.start_mutation = gql("""
            mutation StartInference($input: InferenceInput!) {
                startInference(input: $input) {
                    jobId
                    status
                    startTime
                }
            }
        """)
        
        self.status_subscription = gql("""
            subscription OnInferenceStatusChange($jobId: ID!) {
                onInferenceStatusChange(jobId: $jobId) {
                    jobId
                    status
                    startTime
                    endTime
                    result
                    error
                }
            }
        """)


    async def test_long_running_inference(self) -> None:
        """5分間の長時間実行テスト"""
        logger.info("\n=== 5分間の長時間実行テスト ===")
        
        # テストパラメータを作成（5分の処理時間を指定、クライアント側でjobIdを生成）
        variables = create_test_parameters(
            prompt="これは5分間の長時間実行テストです。",
            model="anthropic.claude-v2",
            process_time=300
        )
        logger.info(f"Generated jobId: {variables['input']['jobId']}")

        # 推論を開始
        try:
            # 非同期実行すると Response Mapping Template で何を設定しても結果は返ってこない
            # 帰り値の方を InferenceStatus! にするとエラーする
            self.http_client.execute(self.start_mutation, variable_values=variables)
        except Exception as e:
            logger.error(f"GraphQL execution error: {str(e)}")
        
        exit()
        # WebSocketクライアントを準備
        async with self.ws_client as session:

            logger.info("WebSocket connection established")
            
            
            # 初期ステータスを検証
            verify_job_status(result['startInference'], JobStatus.PENDING, job_id)
            
            # WebSocketで完了を待機（タイムアウトを6分に設定）
            status = await wait_for_job_completion(
                session,
                job_id,
                timeout=360,
                subscription=self.status_subscription
            )
        
        # 完了ステータスを検証
        verify_job_status(status, JobStatus.COMPLETED, job_id)
        logger.info("長時間実行テストが完了しました")


async def run_all_tests(api_url: str, jwt_token: str) -> None:
    """全テストケースを実行"""
    test = InferenceTest(api_url, jwt_token)
    
    try:
        # 5分間の長時間実行テスト
        logger.info("\n=== 長時間実行テストを開始します ===")
        await test.test_long_running_inference()
        
        logger.info("\n=== 全テストが完了しました ===")
        
    except Exception as e:
        logger.error(f"テスト実行中にエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        # .envファイルを読み込む
        env_path = Path(__file__).parent / '.env'
        if not env_path.exists():
            logger.error("Error: .envファイルが見つかりません")
            logger.error(".env.sampleをコピーして.envを作成し、適切な値を設定してください")
            exit(1)
        
        load_dotenv(env_path)
        
        # 環境変数から認証情報を取得
        email = os.getenv('TEST_USER_EMAIL')
        password = os.getenv('TEST_USER_PASSWORD')
        
        if not email or not password:
            logger.error("Error: 環境変数が設定されていません")
            logger.error("TEST_USER_EMAIL と TEST_USER_PASSWORD を.envファイルで設定してください")
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
            logger.error(f"Error: {stack_outputs_file} が見つかりません")
            logger.error("CDKスタックのデプロイ後に実行してください")
            exit(1)
        
        # 認証トークンを取得
        tokens = get_cognito_tokens(
            user_pool_id=user_pool_id,
            client_id=client_id,
            username=email,
            password=password
        )
        
        # CognitoのIdTokenにプレフィックスを追加してLambda認可トークンを作成
        lambda_auth_token = f"Lambda-Auth-{tokens['IdToken']}"
        
        # 全テストを実行
        asyncio.run(run_all_tests(
            api_url=api_url,
            jwt_token=lambda_auth_token
        ))
        
    except Exception as e:
        logger.error(f"予期しないエラーが発生: {str(e)}")
        exit(1)