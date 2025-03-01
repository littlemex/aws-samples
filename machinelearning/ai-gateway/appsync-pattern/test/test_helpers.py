#!/usr/bin/env python3
"""
テストヘルパー関数
"""
import copy
import asyncio
import os
import logging
from urllib.parse import urlparse, quote
import boto3
from botocore.exceptions import ClientError
from enum import Enum
from dotenv import load_dotenv
from gql import gql, Client
from gql.transport.websockets import WebsocketsTransport
import uuid
from datetime import datetime
from pathlib import Path
from typing import Tuple, Optional, Dict, Any
import base64
import json
from tenacity import retry, stop_after_attempt, wait_exponential

# デバッグログの設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class JobStatus(str, Enum):
    """ジョブステータスの定義"""
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class StatusTransition:
    """ステータス遷移を管理するクラス"""
    def __init__(self):
        self.transitions = []
        
    def add_transition(self, status: JobStatus):
        """新しいステータスを記録"""
        self.transitions.append(status)
        
    def verify_sequence(self, expected_sequence: list[JobStatus]) -> bool:
        """期待されるステータス遷移シーケンスを検証"""
        return self.transitions == expected_sequence

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

def create_test_parameters(
    prompt: str,
    model: str,
    process_time: int = 30
) -> dict:
    """テストパラメータを生成"""
    job_id = str(uuid.uuid4())
    return {
        "input": {
            "jobId": job_id,
            "prompt": prompt,
            "model": model,
            "processTime": process_time
        }
    }

def initialize_test_environment() -> Tuple[str, str]:
    """
    テスト環境を初期化し、必要な設定を行う

    Returns:
        Tuple[str, str]: APIのURL と JWT トークン

    Raises:
        FileNotFoundError: 必要なファイルが見つからない場合
        ValueError: 環境変数が設定されていない場合
    """
    # .envファイルを読み込む
    env_path = Path(__file__).parent / '.env'
    if not env_path.exists():
        logger.error("Error: .envファイルが見つかりません")
        logger.error(".env.sampleをコピーして.envを作成し、適切な値を設定してください")
        raise FileNotFoundError(".env file not found")
    
    load_dotenv(env_path)
    
    # 環境変数から認証情報を取得
    email = os.getenv('TEST_USER_EMAIL')
    password = os.getenv('TEST_USER_PASSWORD')
    
    if not email or not password:
        logger.error("Error: 環境変数が設定されていません")
        logger.error("TEST_USER_EMAIL と TEST_USER_PASSWORD を.envファイルで設定してください")
        raise ValueError("Required environment variables not set")
    
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
        raise
    
    # 認証トークンを取得
    tokens = get_cognito_tokens(
        user_pool_id=user_pool_id,
        client_id=client_id,
        username=email,
        password=password
    )
    
    # CognitoのIdTokenにプレフィックスを追加してLambda認可トークンを作成
    lambda_auth_token = f"Lambda-Auth-{tokens['IdToken']}"
    
    return api_url, lambda_auth_token


def verify_job_status(status: dict, expected_status: JobStatus, job_id: str) -> None:
    """ジョブステータスを検証"""
    assert status['jobId'] == job_id, f"jobId mismatch. Expected {job_id}, got {status['jobId']}"
    assert status['status'] == expected_status, f"Status mismatch. Expected {expected_status}, got {status['status']}"
    
    if expected_status in [JobStatus.COMPLETED, JobStatus.FAILED]:
        assert 'endTime' in status, "endTime should be present for completed/failed jobs"
        assert status['endTime'] is not None, "endTime should not be null for completed/failed jobs"


class WebSocketClient:
    """AppSync WebSocket接続を管理するクラス"""
    def __init__(self, api_url: str, jwt_token: str, job_id: str):
        self.api_url: str = api_url
        self.jwt_token: str = jwt_token
        self.job_id: str = job_id
        self.transport: Optional[WebsocketsTransport] = None
        self.client: Optional[Client] = None
        self._connection_lock = asyncio.Lock()
        self._session = None
        self._is_connected = False
        self.subscription_query = """
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
        """
        self.subscription = gql(self.subscription_query)
        self.host = urlparse(api_url).netloc
        self.start_subscription_message = {
            "id": job_id,
            "type": "start",
            "payload": {
                "data": json.dumps({
                    "query": self.subscription_query,
                    "variables": {
                        "jobId": job_id
                    }
                }),
                "extensions": {
                    "authorization": {
                        "Authorization": self.jwt_token,
                        "host": self.host
                    }
                }
            }
        }
        logger.info(f"start_subscription_message: {self.start_subscription_message}")

    def _build_websocket_url(self) -> str:
        """WebSocket URL を構築する"""

        ws_host = self.host.replace('appsync-api', 'appsync-realtime-api')
        header = {
            "Authorization": self.jwt_token,
            "host": self.host
        }
        header_json = json.dumps(header)
        header_base64 = base64.b64encode(header_json.encode('utf-8')).decode('utf-8')
        query_params = f"?header={quote(header_base64)}&payload=e30="  # e30= is base64 for '{}'
        ws_url = f"wss://{ws_host}/graphql{query_params}"
        logger.info(f"ws_url: {ws_url}")

        return ws_url

    def setup_transport(self) -> WebsocketsTransport:
        """WebSocketトランスポートの設定"""
        ws_url = self._build_websocket_url()
        logger.info("=== WebSocket設定 ===")
        logger.info(f"WebSocket URL: {ws_url}")

        self.transport = WebsocketsTransport(
            url=ws_url,
            subprotocols=['graphql-ws'],
            keep_alive_timeout=600,  # 10分（5分の処理 + バッファ）
            ping_interval=30,
            pong_timeout=20,
            connect_timeout=60,
            close_timeout=60,
            init_payload={
                "type": "connection_init",
                "payload": {}  # AppSyncの場合、init_payloadは空でOK
            }
        )

        self.client = Client(
            transport=self.transport,
            execute_timeout=None
        )

        logger.info("=== WebSocket設定完了 ===")
        return self.transport

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def ensure_connection(self):
        """
        コネクションが確立されていることを保証する
        
        3回まで再試行を行い、指数バックオフで待機時間を増やしていく
        - 1回目: 4秒待機
        - 2回目: 8秒待機
        - 3回目: 10秒待機（最大値に制限）
        """
        async with self._connection_lock:
            if not self._is_connected:
                if not self.client:
                    self.setup_transport()
                try:
                    await self.test_connection()
                    self._is_connected = True
                    return
                except Exception as e:
                    logger.error(f"接続試行に失敗: {str(e)}")
                    self._is_connected = False
                    raise

    async def test_connection(self) -> bool:
        """
        WebSocket接続のテストを実行する
        """
        try:
            self._session = await self.client.__aenter__()
            # connection_init メッセージを明示的に送信
            await self._session.transport.websocket.send(json.dumps({
                "type": "connection_init",
                "payload": {}
            }))
            
            # connection_ack を待つ
            while True:
                response = await self._session.transport.websocket.recv()
                data = json.loads(response)
                if data.get("type") == "connection_ack":
                    logger.info("WebSocket接続が確立されました")
                    return True
                elif data.get("type") == "error":
                    raise ConnectionError(f"Connection failed: {data}")
                elif data.get("type") == "ka":  # Keep-alive は無視
                    continue
                
        except Exception as e:
            logger.error(f"WebSocket接続エラー: {str(e)}")
            if self._session:
                await self._session.transport.close()
                self._session = None
            raise ConnectionError(f"WebSocket connection failed: {str(e)}")

    async def wait_for_status_change(self, job_id: str, timeout: int = 360) -> Dict[str, Any]:
        await self.ensure_connection()
        
        try:
            await self._session.transport.websocket.send(json.dumps(self.start_subscription_message))
            logger.debug(f"送信メッセージ: {self.start_subscription_message}")

            try:
                while True:
                    # メッセージ受信をタイムアウト付きで実行
                    message = await asyncio.wait_for(
                        self._session.transport.websocket.recv(),
                        timeout=timeout
                    )
                    data = json.loads(message)
                    logger.debug(f"受信メッセージ: {data}")

                    if data.get("type") == "ka":
                        continue
                    elif data.get("type") == "error":
                        error_msg = data.get("payload", {}).get("errors", [{}])[0].get("message", "Unknown error")
                        logger.error(f"サブスクリプションエラー: {error_msg}")
                        raise ConnectionError(f"Subscription error: {error_msg}")
                    elif data.get("type") == "data":
                        try:
                            status = data["payload"]["data"]["onInferenceStatusChange"]
                            current_status = status["status"]
                            
                            logger.info(f"ステータス更新: {current_status}")
                            
                            if current_status in [JobStatus.COMPLETED, JobStatus.FAILED]:
                                return status
                        except (KeyError, TypeError) as e:
                            logger.error(f"不正なレスポース形式: {e}")
                            logger.debug(f"受信データ: {data}")
                            continue

            except asyncio.TimeoutError:
                logger.error(f"タイムアウト: {timeout}秒を超えました")
                raise TimeoutError(f"Job {job_id} timed out after {timeout} seconds")

        except Exception as e:
            self._is_connected = False
            if self._session:
                await self._session.transport.close()
                self._session = None
            raise

    async def close(self):
        """クライアントの終了処理"""
        if self.transport:
            await self.transport.close()
        self._is_connected = False

    async def __aenter__(self):
        await self.ensure_connection()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()
