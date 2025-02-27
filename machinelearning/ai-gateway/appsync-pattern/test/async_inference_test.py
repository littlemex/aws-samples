#!/usr/bin/env python3
"""
非同期での長時間のGenAI API実行をテストするためのスクリプト
"""

import asyncio
import time
import uuid
import json
from datetime import datetime


class MockGenAIClient:
    """長時間実行するGenAI APIのモッククライアント"""

    def __init__(self):
        # 実行中のジョブを保存する辞書
        self.running_jobs = {}

    async def start_inference(self, prompt, model="gpt-4", **kwargs):
        """推論ジョブを開始する"""
        job_id = str(uuid.uuid4())

        # ジョブ情報を保存
        self.running_jobs[job_id] = {
            "status": "RUNNING",
            "start_time": datetime.now().isoformat(),
            "prompt": prompt,
            "model": model,
            "params": kwargs,
            "result": None,
        }

        # 非同期でジョブを実行
        asyncio.create_task(self._process_job(job_id))

        return {"job_id": job_id, "status": "RUNNING"}

    async def _process_job(self, job_id):
        """バックグラウンドでジョブを処理する"""
        try:
            # 実際のAPIでは、ここで外部サービスを呼び出す
            # このモックでは、単に5〜15秒待機して長時間実行を模擬
            job_info = self.running_jobs[job_id]
            prompt = job_info["prompt"]

            # ランダムな処理時間（5〜15秒）
            import random

            process_time = random.randint(5, 15)

            print(f"ジョブ {job_id} を処理中... 処理時間: {process_time}秒")
            await asyncio.sleep(process_time)

            # 結果を生成
            result = f"プロンプト「{prompt}」に対する応答です。処理時間: {process_time}秒"

            # ジョブ情報を更新
            self.running_jobs[job_id]["status"] = "COMPLETED"
            self.running_jobs[job_id]["result"] = result
            self.running_jobs[job_id]["end_time"] = datetime.now().isoformat()

            print(f"ジョブ {job_id} が完了しました")

        except Exception as e:
            # エラー発生時
            self.running_jobs[job_id]["status"] = "FAILED"
            self.running_jobs[job_id]["error"] = str(e)
            print(f"ジョブ {job_id} でエラーが発生しました: {e}")

    async def get_job_status(self, job_id):
        """ジョブのステータスを取得する"""
        if job_id not in self.running_jobs:
            return {"error": "Job not found"}

        job_info = self.running_jobs[job_id]

        return {
            "job_id": job_id,
            "status": job_info["status"],
            "start_time": job_info["start_time"],
            "end_time": job_info.get("end_time"),
            "result": job_info.get("result") if job_info["status"] == "COMPLETED" else None,
            "error": job_info.get("error") if job_info["status"] == "FAILED" else None,
        }


async def test_async_inference():
    """非同期推論のテスト"""
    client = MockGenAIClient()

    # 複数のジョブを開始
    jobs = []
    for i in range(3):
        prompt = f"テスト用プロンプト {i + 1}"
        result = await client.start_inference(prompt)
        jobs.append(result["job_id"])
        print(f"ジョブ {result['job_id']} を開始しました")

    # すべてのジョブが完了するまで定期的にステータスをチェック
    all_completed = False
    while not all_completed:
        all_completed = True

        for job_id in jobs:
            status = await client.get_job_status(job_id)
            print(f"ジョブ {job_id} のステータス: {status['status']}")

            if status["status"] == "RUNNING":
                all_completed = False

        if not all_completed:
            print("まだ実行中のジョブがあります。3秒後に再確認します...")
            await asyncio.sleep(3)

    # すべてのジョブの結果を表示
    print("\n=== すべてのジョブが完了しました ===\n")
    for job_id in jobs:
        status = await client.get_job_status(job_id)
        print(f"ジョブ ID: {job_id}")
        print(f"ステータス: {status['status']}")
        print(f"開始時間: {status['start_time']}")
        print(f"終了時間: {status['end_time']}")
        print(f"結果: {status['result']}")
        print("-" * 50)


if __name__ == "__main__":
    asyncio.run(test_async_inference())
