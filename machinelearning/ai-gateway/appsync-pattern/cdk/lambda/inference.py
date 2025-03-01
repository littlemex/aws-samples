import asyncio
import json
import logging
import os
from datetime import datetime
from typing import Optional, Dict, Any
import time
from gql import gql, Client
from gql.transport.requests import RequestsHTTPTransport

# ロギングの設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AppSync API URLの環境変数から取得
APPSYNC_API_URL = os.environ.get('APPSYNC_API_URL')
if not APPSYNC_API_URL:
    raise ValueError("APPSYNC_API_URL environment variable is required")


# AppSync GraphQLクライアントの初期化
transport = RequestsHTTPTransport(
    url=APPSYNC_API_URL,
    use_json=True,
    headers={
        'Content-Type': 'application/json',
    }
)

client = Client(
    transport=transport,
    fetch_schema_from_transport=True
)

async def update_inference_status(
    job_id: str,
    status: str,
    result: Optional[str] = None,
    error: Optional[str] = None
) -> Dict[str, Any]:
    """AppSync GraphQL APIを呼び出してステータスを更新"""
    mutation = """
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
    """
    
    variables = {
        "input": {
            "jobId": job_id,
            "status": status,
            "endTime": datetime.utcnow().isoformat() if status in ["COMPLETED", "FAILED"] else None,
            "result": result,
            "error": error
        }
    }
    
    try:
        logger.info(f"Updating inference status for job {job_id} to {status}")
        response = client.post_graphql_operation(
            apiId=APPSYNC_API_ID,
            operationName='UpdateInferenceStatus',
            query=mutation,
            variables=json.dumps(variables)
        )
        logger.info(f"Successfully updated status for job {job_id}")
        return response
    except Exception as e:
        logger.error(f"Failed to update status for job {job_id}: {str(e)}")
        raise

def create_inference_response(
    job_id: str,
    status: str,
    start_time: str,
    end_time: Optional[str] = None,
    result: Optional[str] = None,
    error: Optional[str] = None
) -> Dict[str, Any]:
    """GraphQLスキーマに準拠したレスポンスを生成"""
    return {
        "jobId": job_id,
        "status": status,
        "startTime": start_time,
        "endTime": end_time,
        "result": result,
        "error": error
    }

async def handle_inference_error(
    job_id: str,
    start_time: str,
    error_msg: str
) -> Dict[str, Any]:
    """エラー時の共通処理"""
    end_time = datetime.utcnow().isoformat()
    
    # エラー時は必ずFAILEDステータスを通知
    await update_inference_status(job_id, "FAILED", error=error_msg)
    
    return create_inference_response(
        job_id=job_id,
        status="FAILED",
        start_time=start_time,
        end_time=end_time,
        error=error_msg
    )
async def process_inference(event: Dict[str, Any], job_id: str) -> None:
    """推論処理のメイン関数"""
    try:
        # 入力パラメータの検証
        process_time = event.get('processTime', 0)
        prompt = event.get('prompt')
        model = event.get('model')
        
        if not prompt or not model:
            raise ValueError("Missing required fields: prompt and model")
        
        logger.info(f"Processing inference request - jobId: {job_id}, model: {model}, process_time: {process_time}")
        
        # モデルの検証
        valid_models = ['anthropic.claude-v2', 'anthropic.claude-instant-v1']
        if model not in valid_models:
            raise ValueError(f"Invalid model: {model}. Must be one of {valid_models}")
        
        # PROCESSINGステータスに遷移
        logger.info(f"Updating status to PROCESSING for job {job_id}")
        await update_inference_status(job_id, "PROCESSING")
        
        # 処理時間のシミュレーション
        if process_time > 0:
            logger.info(f"Simulating processing time of {process_time} seconds")
            await asyncio.sleep(process_time)
        
        # 処理結果
        result = {
            "message": "Inference completed successfully",
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # 完了ステータスの更新
        logger.info(f"Updating status to COMPLETED for job {job_id}")
        result_str = json.dumps(result)
        await update_inference_status(job_id, "COMPLETED", result=result_str)
        
    except Exception as e:
        logger.error(f"Error in process_inference: {str(e)}")
        # エラー時はFAILEDステータスを設定
        try:
            await update_inference_status(job_id, "FAILED", error=str(e))
        except Exception as update_error:
            logger.error(f"Failed to update error status: {str(update_error)}")
        raise

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler関数"""
    logger.info(f"Received event: {json.dumps(event)}")

    # クライアントから提供されたjobIdを取得
    job_id = event.get('jobId')
    if not job_id:
        logger.error("jobId is required but not provided")
        # 後で appsync mutation で FAILED status に更新する処理を入れる
    logger.info(f"Using client-provided jobId: {job_id}")
    
    start_time = time.time()
    # 実行時間 (5分 = 300秒)
    duration = 300
    # ログ出力間隔 (10秒)
    interval = 10

    while True:
        # 現在の経過時間を計算
        elapsed_time = time.time() - start_time
        
        # 5分経過したら終了
        if elapsed_time >= duration:
            print(f"処理終了: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            break
            
        # 現在時刻とともにログを出力
        print(f"実行中... 経過時間: {int(elapsed_time)}秒 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 10秒待機
        time.sleep(interval)

    # いったんここまでの処理を確認したい
    return 

    # イベントループを作成
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        # メイン処理を実行（戻り値は不要）
        loop.run_until_complete(process_inference(event, job_id))
    except Exception as e:
        logger.error(f"Error in handler: {str(e)}")
    finally:
        loop.close()