#!/usr/bin/env python3
"""
AgentCore Runtime呼び出しテストスクリプト
"""
import boto3
import json
import time
import os
from typing import Dict, Any

def call_agentcore_runtime(agent_arn: str, payload: Dict[str, Any], region: str = None) -> str:
    """
    AgentCore Runtimeを呼び出す
    
    Args:
        agent_arn: Agent Runtime ARN
        payload: 送信するペイロード
        region: AWSリージョン
    
    Returns:
        エージェントからの応答
    """
    try:
        # AgentCore クライアントを初期化
        agentcore_client = boto3.client('bedrock-agentcore', region_name=region)
        
        print(f"Calling AgentCore Runtime: {agent_arn}")
        print(f"Payload: {json.dumps(payload, ensure_ascii=False, indent=2)}")
        
        # エージェントを呼び出し
        response = agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=agent_arn,
            qualifier="DEFAULT",
            payload=json.dumps(payload, ensure_ascii=False)
        )
        
        print(f"Response content type: {response.get('contentType', 'unknown')}")
        
        # レスポンス処理
        if "text/event-stream" in response.get("contentType", ""):
            # ストリーミングレスポンス
            content = []
            for line in response["response"].iter_lines(chunk_size=1):
                if line:
                    line = line.decode("utf-8")
                    if line.startswith("data: "):
                        line = line[6:]
                        print(f"Stream: {line}")
                        content.append(line)
            return "\n".join(content)
        else:
            # 通常のレスポンス
            try:
                events = []
                for event in response.get("response", []):
                    events.append(event)
                if events:
                    result = json.loads(events[0].decode("utf-8"))
                    return str(result)
                else:
                    return "No response events"
            except Exception as e:
                return f"Error processing response: {e}"
                
    except Exception as e:
        return f"Error calling AgentCore Runtime: {e}"

def test_various_prompts(agent_arn: str, region: str = None):
    """
    様々なプロンプトでエージェントをテスト
    """
    test_cases = [
        {"prompt": "こんにちは"},
        {"prompt": "今日の天気はどうですか？"},
        {"prompt": "2 + 3 の計算をしてください"},
        {"prompt": "10 * 15 はいくつですか？"},
        {"prompt": "あなたの機能について教えてください"}
    ]
    
    print("=== AgentCore Runtime テスト開始 ===\n")
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"--- テスト {i} ---")
        result = call_agentcore_runtime(agent_arn, test_case, region)
        print(f"Result: {result}")
        print("-" * 50)
        time.sleep(1)  # 短い待機時間
    
    print("=== テスト完了 ===")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python3 test_agent_caller.py <agent_runtime_arn> [region]")
        print("Example: python3 test_agent_caller.py arn:aws:bedrock-agentcore:us-east-1:123456789012:agent-runtime/XXXXX us-east-1")
        sys.exit(1)
    
    agent_arn = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else os.getenv('AWS_REGION', 'us-east-1')
    
    test_various_prompts(agent_arn, region)
