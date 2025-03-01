import logging
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport
import json
from enum import Enum
from typing import Dict, Any, Optional
from test_helpers import JobStatus, initialize_test_environment
import argparse
from datetime import datetime, timezone


# ログ設定
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class InferenceMutationClient:
    """AppSync Mutation操作を管理するクラス"""
    def __init__(self, api_url: str, jwt_token: str):
        self.api_url = api_url
        self.jwt_token = jwt_token
        self.client = self._initialize_http_client(api_url, jwt_token)
        logger.info("=== 認可トークン ===")
        logger.info(f"Using token: {jwt_token[:30]}...")
        logger.info("=== 認可トークン終了 ===")


    def _initialize_http_client(self, api_url: str, jwt_token: str) -> Client:
        http_transport = RequestsHTTPTransport(
            url=api_url,
            headers={'Authorization': jwt_token}
        )

        return Client(
            transport=http_transport,
            fetch_schema_from_transport=True
        )

    async def update_inference_status(
        self,
        job_id: str,
        status: str,
        result: Optional[str] = None,
        error: Optional[str] = None
    ) -> Dict[str, Any]:
        """AppSync GraphQL APIを呼び出してステータスを更新"""
        mutation = gql("""
        mutation UpdateInferenceStatus($input: UpdateStatusInput!) {
            updateInferenceStatus(input: $input) {
                jobId
                status
                startTime
                endTime
                result
                error
            }
        }
        """)
        
        variables = {
            "input": {
                "jobId": job_id,
                "status": status.value
            }
        }
        
        try:
            logger.info(f"Updating inference status for job {job_id} to {status}")
            response = self.client.execute(
                mutation,
                variable_values=variables
            )
            logger.info(f"Successfully updated status for job {job_id}")
            return response
        except Exception as e:
            logger.error(f"Failed to update status for job {job_id}: {str(e)}")
            raise


async def main(job_id: str, status: str, result: dict = None, error: str = None):
    api_url, jwt_token = initialize_test_environment()
    client = InferenceMutationClient(api_url, jwt_token)
    
    try:
        # PROCESSINGステータスに更新
        await client.update_inference_status(
            job_id=job_id,
            status=JobStatus(status),  # 文字列からenumに変換
            result=result,
            error=error
        )
        
        # 処理が完了したと仮定して、結果付きでCOMPLETEDに更新
        result = {
            "prediction": "テスト結果",
            "confidence": 0.95
        }
        await client.update_inference_status(
            job_id=job_id,
            status=JobStatus.COMPLETED,
            result=result
        )
        
    except Exception as e:
        logger.error(f"エラー発生: {str(e)}")
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='推論ジョブのステータスを更新')
    parser.add_argument('job_id', help='更新対象のジョブID')
    parser.add_argument('status', choices=[s.value for s in JobStatus], help='新しいステータス')
    parser.add_argument('--result', type=json.loads, help='結果（JSON形式）')
    parser.add_argument('--error', help='エラーメッセージ')

    args = parser.parse_args()

    import asyncio
    asyncio.run(main(
        job_id=args.job_id,
        status=args.status,
        result=args.result,
        error=args.error
    ))
