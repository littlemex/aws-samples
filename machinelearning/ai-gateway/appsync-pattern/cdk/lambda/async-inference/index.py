import asyncio
import json
import os
import uuid
from datetime import datetime
import boto3
from typing import Dict, Any

bedrock = boto3.client('bedrock-runtime')

class AsyncInferenceManager:
    def __init__(self):
        self.running_jobs: Dict[str, Dict[str, Any]] = {}

    async def start_inference(self, prompt: str, model: str = "anthropic.claude-v2", parameters: dict = None) -> dict:
        """推論ジョブを開始する"""
        job_id = str(uuid.uuid4())
        
        # デフォルトのパラメータ設定
        default_params = {
            "max_tokens_to_sample": 1000,
            "temperature": 0.7,
            "top_p": 0.9,
            "anthropic_version": "bedrock-2023-05-31"
        }
        
        # ユーザー指定のパラメータでデフォルト値を上書き
        if parameters:
            default_params.update(parameters)

        # ジョブ情報を保存
        self.running_jobs[job_id] = {
            "status": "RUNNING",
            "start_time": datetime.now().astimezone().isoformat(),
            "prompt": prompt,
            "model": model,
            "parameters": default_params,
            "result": None,
        }

        # 非同期でジョブを実行
        asyncio.create_task(self._process_job(job_id))

        return {
            "jobId": job_id,
            "status": "RUNNING"
        }

    async def _process_job(self, job_id: str):
        """バックグラウンドでジョブを処理する"""
        try:
            job_info = self.running_jobs[job_id]
            prompt = job_info["prompt"]
            model = job_info["model"]
            parameters = job_info["parameters"]

            # Anthropic Claudeモデル用のプロンプトフォーマット
            if model.startswith("anthropic.claude"):
                body = {
                    "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
                    "max_tokens_to_sample": parameters["max_tokens_to_sample"],
                    "temperature": parameters["temperature"],
                    "top_p": parameters["top_p"],
                    "anthropic_version": parameters["anthropic_version"]
                }
            else:
                # 他のモデル用のフォーマット（必要に応じて追加）
                body = {
                    "prompt": prompt,
                    **parameters
                }

            # Bedrockを呼び出して推論を実行
            response = bedrock.invoke_model(
                modelId=model,
                body=json.dumps(body)
            )
            
            response_body = json.loads(response.get('body').read())
            
            # レスポンスの形式はモデルによって異なる
            if model.startswith("anthropic.claude"):
                result = response_body.get('completion', '')
            else:
                result = response_body

            # ジョブ情報を更新
            self.running_jobs[job_id].update({
                "status": "COMPLETED",
                "result": result,
                "end_time": datetime.now().astimezone().isoformat()
            })

        except Exception as e:
            # エラー発生時
            self.running_jobs[job_id].update({
                "status": "FAILED",
                "error": str(e),
                "end_time": datetime.now().astimezone().isoformat()
            })

    def get_job_status(self, job_id: str) -> dict:
        """ジョブのステータスを取得する"""
        if job_id not in self.running_jobs:
            raise Exception("Job not found")

        job_info = self.running_jobs[job_id]
        
        return {
            "jobId": job_id,
            "status": job_info["status"],
            "startTime": job_info["start_time"],
            "endTime": job_info.get("end_time"),
            "result": job_info.get("result") if job_info["status"] == "COMPLETED" else None,
            "error": job_info.get("error") if job_info["status"] == "FAILED" else None,
        }

# グローバルなインスタンスを作成
inference_manager = AsyncInferenceManager()

def handler(event, context):
    """Lambda handler"""
    try:
        # AppSync からのリクエストを処理
        field = event['info']['fieldName']
        
        if field == 'startInference':
            input_data = event['arguments']['input']
            loop = asyncio.get_event_loop()
            result = loop.run_until_complete(
                inference_manager.start_inference(
                    prompt=input_data['prompt'],
                    model=input_data.get('model', 'anthropic.claude-v2'),
                    parameters=input_data.get('parameters')
                )
            )
            return result
            
        elif field == 'getInferenceStatus':
            job_id = event['arguments']['jobId']
            return inference_manager.get_job_status(job_id)
            
        else:
            raise Exception(f"Unknown field: {field}")
            
    except Exception as e:
        raise Exception(f"Error processing request: {str(e)}")