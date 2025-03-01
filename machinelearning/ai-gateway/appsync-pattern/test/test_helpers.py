"""
AppSync GraphQL APIテスト用のヘルパー関数
"""

import json
import logging
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime

# ロガーの設定
logger = logging.getLogger(__name__)

class JobStatus:
    """ジョブステータスの定数"""
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

    @staticmethod
    def is_valid(status: str) -> bool:
        """有効なステータスかどうかを確認"""
        return status in [
            JobStatus.PENDING,
            JobStatus.PROCESSING,
            JobStatus.COMPLETED,
            JobStatus.FAILED
        ]

class StatusTransition:
    """ステータス遷移を管理するクラス"""
    def __init__(self):
        self.transitions: List[Dict[str, Any]] = []

    def add_transition(self, status: Dict[str, Any]) -> None:
        """ステータス遷移を記録"""
        self.transitions.append({
            'status': status['status'],
            'timestamp': datetime.now().isoformat(),
            'result': status.get('result'),
            'error': status.get('error')
        })

    def verify_sequence(self) -> bool:
        """ステータス遷移シーケンスを検証"""
        if not self.transitions:
            return False

        # 最初のステータスはPENDINGまたはPROCESSING
        if self.transitions[0]['status'] not in [JobStatus.PENDING, JobStatus.PROCESSING]:
            logger.error(f"Invalid initial status: {self.transitions[0]['status']}")
            return False

        # 最後のステータスはCOMPLETEDまたはFAILED
        if self.transitions[-1]['status'] not in [JobStatus.COMPLETED, JobStatus.FAILED]:
            logger.error(f"Invalid final status: {self.transitions[-1]['status']}")
            return False

        # 遷移の検証
        valid_transitions = {
            JobStatus.PENDING: [JobStatus.PROCESSING],
            JobStatus.PROCESSING: [JobStatus.COMPLETED, JobStatus.FAILED],
            JobStatus.COMPLETED: [],
            JobStatus.FAILED: []
        }

        for i in range(len(self.transitions) - 1):
            current = self.transitions[i]['status']
            next_status = self.transitions[i + 1]['status']
            if next_status not in valid_transitions[current]:
                logger.error(f"Invalid transition: {current} -> {next_status}")
                return False

        return True

    def get_execution_time(self) -> Optional[float]:
        """実行時間を計算（秒）"""
        if len(self.transitions) < 2:
            return None

        try:
            start_time = datetime.fromisoformat(self.transitions[0]['timestamp'])
            end_time = datetime.fromisoformat(self.transitions[-1]['timestamp'])
            return (end_time - start_time).total_seconds()
        except Exception as e:
            logger.error(f"Error calculating execution time: {e}")
            return None

async def wait_for_job_completion(
    websocket_client,
    job_id: str,
    timeout: int = 360,
    subscription: Any = None
) -> Dict[str, Any]:
    """ジョブの完了を待機するヘルパー関数"""
    logger.info(f"Waiting for job completion: {job_id}")
    transition = StatusTransition()
    
    try:
        async with websocket_client as session:
            logger.info("WebSocket connection established")
            
            async for result in session.subscribe(
                document=session.client.status_subscription,
                variable_values={"jobId": job_id},
                timeout=timeout
            ):
                status = result['onInferenceStatusChange']
                logger.info(f"Status update for job {job_id}: {status['status']}")
                
                # ステータス遷移を記録
                transition.add_transition(status)
                
                if status['status'] in [JobStatus.COMPLETED, JobStatus.FAILED]:
                    # 遷移シーケンスを検証
                    if not transition.verify_sequence():
                        logger.error("Invalid status transition sequence detected")
                        raise ValueError("Invalid status transition sequence")
                    
                    # 実行時間をログに記録
                    execution_time = transition.get_execution_time()
                    if execution_time:
                        logger.info(f"Job execution time: {execution_time:.2f} seconds")
                    
                    return status
                
    except asyncio.TimeoutError:
        logger.error(f"Job {job_id} timed out after {timeout} seconds")
        raise
    except Exception as e:
        logger.error(f"Error waiting for job completion: {str(e)}")
        raise

def verify_job_status(
    status: Dict[str, Any],
    expected_status: str,
    job_id: str
) -> None:
    """ジョブステータスを検証するヘルパー関数"""
    logger.info(f"Verifying job status for {job_id}")
    
    # 基本的な検証
    assert 'status' in status, "Status object must contain 'status' field"
    assert 'jobId' in status, "Status object must contain 'jobId' field"
    assert status['jobId'] == job_id, f"Job ID mismatch: {status['jobId']} != {job_id}"
    
    # ステータスの検証
    assert JobStatus.is_valid(status['status']), f"Invalid status: {status['status']}"
    assert status['status'] == expected_status, \
        f"Status mismatch: {status['status']} != {expected_status}"
    
    # 完了時の検証
    if expected_status == JobStatus.COMPLETED:
        assert 'result' in status, "Completed job must have 'result'"
        assert status['result'] is not None, "Result cannot be None for completed job"
    
    # エラー時の検証
    if expected_status == JobStatus.FAILED:
        assert 'error' in status, "Failed job must have 'error'"
        assert status['error'] is not None, "Error cannot be None for failed job"
    
    logger.info(f"Job status verification passed for {job_id}")

def create_test_parameters(
    prompt: str,
    model: str = "anthropic.claude-v2",
    process_time: Optional[int] = None
) -> Dict[str, Any]:
    """テストパラメータを作成するヘルパー関数"""
    import uuid
    return {
        "input": {
            "jobId": str(uuid.uuid4()),
            "prompt": prompt,
            "model": model,
            "processTime": process_time
        }
    }