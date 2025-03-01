#!/usr/bin/env python3
"""
AppSync GraphQL APIを使用した非同期推論のテストスクリプト
"""

import asyncio
import json
import argparse
from datetime import datetime
from gql import gql, Client
from gql.transport.websockets import WebsocketsTransport
from gql.transport.requests import RequestsHTTPTransport
import os
import logging

# ロギングの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# GraphQL Queries/Mutations/Subscriptions
START_INFERENCE = gql("""
    mutation StartInference($input: InferenceInput!) {
        startInference(input: $input) {
            jobId
            status
            startTime
        }
    }
""")

ON_INFERENCE_STATUS_CHANGE = gql("""
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

class AsyncInferenceClient:
    """AppSync GraphQL APIクライアント"""

    def __init__(self, api_url, ws_url, auth_token):
        self.api_url = api_url
        self.ws_url = ws_url
        self.auth_token = auth_token
        
        # HTTP Transport for mutations
        self.http_transport = RequestsHTTPTransport(
            url=api_url,
            headers={'Authorization': f'Lambda-Auth-{auth_token}'}
        )
        
        # WebSocket Transport for subscriptions
        self.ws_transport = WebsocketsTransport(
            url=ws_url,
            headers={'Authorization': f'Lambda-Auth-{auth_token}'}
        )
        
        # GraphQL clients
        self.http_client = Client(transport=self.http_transport)
        self.ws_client = Client(transport=self.ws_transport)

    async def start_inference(self, prompt, model="gpt-4", process_time=None):
        """推論ジョブを開始する"""
        variables = {
            "input": {
                "prompt": prompt,
                "model": model,
                "processTime": process_time
            }
        }
        
        try:
            result = await self.http_client.execute_async(
                START_INFERENCE,
                variable_values=variables
            )
            return result["startInference"]
        except Exception as e:
            logger.error(f"Failed to start inference: {e}")
            raise

    async def subscribe_to_status(self, job_id):
        """ステータス変更をサブスクライブする"""
        try:
            async for result in self.ws_client.subscribe(
                ON_INFERENCE_STATUS_CHANGE,
                variable_values={"jobId": job_id}
            ):
                yield result["onInferenceStatusChange"]
        except Exception as e:
            logger.error(f"Subscription error: {e}")
            raise

async def test_async_inference(api_url, ws_url, auth_token, process_time=None):
    """非同期推論のテスト"""
    client = AsyncInferenceClient(api_url, ws_url, auth_token)
    
    # テストジョブを開始
    prompts = [
        "テスト用プロンプト 1",
        "テスト用プロンプト 2",
        "テスト用プロンプト 3"
    ]
    
    jobs = []
    for prompt in prompts:
        try:
            result = await client.start_inference(prompt, process_time=process_time)
            jobs.append(result["jobId"])
            logger.info(f"Started job {result['jobId']} with status {result['status']}")
        except Exception as e:
            logger.error(f"Failed to start job for prompt '{prompt}': {e}")
            continue

    # 各ジョブのステータス変更を監視
    async def monitor_job(job_id):
        async for status in client.subscribe_to_status(job_id):
            logger.info(f"Job {job_id} status update: {status['status']}")
            if status["status"] in ["COMPLETED", "FAILED"]:
                if status["status"] == "COMPLETED":
                    logger.info(f"Job {job_id} completed with result: {status['result']}")
                else:
                    logger.error(f"Job {job_id} failed with error: {status['error']}")
                return status

    # すべてのジョブを並行して監視
    tasks = [monitor_job(job_id) for job_id in jobs]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    # 結果の表示
    logger.info("\n=== Test Results ===")
    for job_id, result in zip(jobs, results):
        if isinstance(result, Exception):
            logger.error(f"Job {job_id} monitoring failed: {result}")
        else:
            logger.info(f"\nJob ID: {job_id}")
    if args.process_time:
        print(f"指定された処理時間: {args.process_time}秒")
    else:
        print("処理時間: 5-60秒のランダム")

    asyncio.run(test_async_inference(args.process_time))
