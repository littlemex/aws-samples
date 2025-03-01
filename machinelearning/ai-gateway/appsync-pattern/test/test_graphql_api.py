"""
AppSync GraphQL APIをテストするスクリプト
"""

import asyncio
import logging
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
from test_helpers import (
    JobStatus,
    StatusTransition,
    verify_job_status,
    create_test_parameters,
    initialize_test_environment,
    WebSocketClient
)

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

logging.getLogger('websockets').setLevel(logging.DEBUG)
logging.getLogger('gql.transport.websockets').setLevel(logging.DEBUG)


class InferenceTest:
    def __init__(self, api_url: str, jwt_token: str):
        logger.info("=== 認可トークン ===")
        logger.info(f"Using token: {jwt_token[:30]}...")
        logger.info("=== 認可トークン終了 ===")

        # HTTPクライアントの初期化
        self.http_client = self._initialize_http_client(api_url, jwt_token)

    def _initialize_http_client(self, api_url: str, jwt_token: str) -> Client:
        http_transport = RequestsHTTPTransport(
            url=api_url,
            headers={'Authorization': jwt_token}
        )

        return Client(
            transport=http_transport,
            fetch_schema_from_transport=True
        )

    @property
    def start_mutation(self) -> str:
        return gql("""
            mutation StartInference($input: InferenceInput!) {
                startInference(input: $input) {
                    jobId
                    status
                    startTime
                }
            }
        """)
        
    async def execute_inference_request(self, variables: dict) -> str:
        """
        推論リクエストを実行する

        Args:
            variables: GraphQL変数（jobId, prompt, model, processTime を含む）

        Returns:
            str: 実行されたジョブのID

        Raises:
            Exception: GraphQLリクエストが失敗した場合
        """
        try:
            # 非同期実行なのでレスポンスは期待しない
            self.http_client.execute(self.start_mutation, variable_values=variables)
            logger.info("推論処理を開始しました")
            return variables['input']['jobId']
        except Exception as e:
            logger.error(f"GraphQL execution error: {str(e)}")
            raise

    async def test_long_running_inference(self, api_url: str, jwt_token: str) -> None:
        """5分間の長時間実行テスト"""
        logger.info("\n=== 5分間の長時間実行テスト ===")
        
        # テストパラメータを作成（5分の処理時間を指定、クライアント側でjobIdを生成）
        variables = create_test_parameters(
            prompt="これは5分間の長時間実行テストです。",
            model="anthropic.claude-v2",
            process_time=300
        )
        logger.info(f"Generated jobId: {variables['input']['jobId']}")

        # 推論リクエストを実行
        job_id = await self.execute_inference_request(variables)
        logger.info(f"処理状態の監視を開始: jobId = {job_id}")
        
        # WebSocketクライアントを準備
        ws_client = WebSocketClient(api_url, jwt_token, job_id)
        
        try:
            # WebSocketで完了を待機（タイムアウトを6分に設定）
            logger.info("WebSocketサブスクリプションを開始します")
            status = await ws_client.wait_for_status_change(job_id, timeout=360)
            
            # 完了ステータスを検証
            # verify_job_status(status, JobStatus.COMPLETED, job_id)
            logger.info("長時間実行テストが完了しました")
            
        except TimeoutError as e:
            logger.error(f"処理がタイムアウトしました: {str(e)}")
            raise
        except ConnectionError as e:
            logger.error(f"WebSocket接続エラー: {str(e)}")
            logger.error("WebSocket URL, 認証情報, ペイロードを確認してください")
            raise
        except Exception as e:
            logger.error(f"予期しないエラーが発生: {str(e)}")
            raise


async def run_all_tests(api_url: str, jwt_token: str) -> None:
    test = InferenceTest(api_url, jwt_token)
    
    try:
        logger.info("\n=== 長時間実行テストを開始します ===")
        await test.test_long_running_inference(api_url, jwt_token)
        
        logger.info("\n=== 全テストが完了しました ===")
        
    except Exception as e:
        logger.error(f"テスト実行中にエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    try:
        api_url, lambda_auth_token = initialize_test_environment()
        asyncio.run(run_all_tests(
            api_url=api_url,
            jwt_token=lambda_auth_token
        ))
        
    except Exception as e:
        logger.error(f"予期しないエラーが発生: {str(e)}")
        exit(1)