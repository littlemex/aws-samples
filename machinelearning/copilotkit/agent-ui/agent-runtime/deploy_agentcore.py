#!/usr/bin/env python3
"""
AgentCore Runtime configure と launch を実行するスクリプト
"""
from bedrock_agentcore_starter_toolkit import Runtime
from boto3.session import Session
import time
import sys
import os

def main():
    boto_session = Session()
    region = boto_session.region_name or os.getenv('AWS_REGION', 'us-east-1')  # 環境変数から取得
    
    agentcore_runtime = Runtime()
    agent_name = os.getenv('AGENT_NAME', 'simple_agent_copilotkit')  # 環境変数から取得
    
    print(f'Configuring agent: {agent_name} in region: {region}')
    
    try:
        # Configure
        response = agentcore_runtime.configure(
            entrypoint='runtime_agent.py',
            auto_create_execution_role=True,
            auto_create_ecr=True,
            requirements_file='requirements.txt',
            region=region,
            agent_name=agent_name
        )
        
        print('Configure response:', response)
        print('\n--- Starting Launch ---')
        
        # Launch
        launch_result = agentcore_runtime.launch()
        print('Launch result:', launch_result)
        
        # Wait for deployment to complete
        print('\n--- Checking Status ---')
        status_response = agentcore_runtime.status()
        status = status_response.endpoint['status']
        print(f'Initial status: {status}')
        
        end_status = ['READY', 'CREATE_FAILED', 'DELETE_FAILED', 'UPDATE_FAILED']
        attempts = 0
        max_attempts = 30  # 最大5分程度待機
        
        while status not in end_status and attempts < max_attempts:
            print(f'Waiting... Status: {status} (attempt {attempts + 1}/{max_attempts})')
            time.sleep(10)
            status_response = agentcore_runtime.status()
            status = status_response.endpoint['status']
            attempts += 1
        
        print(f'Final status: {status}')
        
        if hasattr(launch_result, 'agent_arn'):
            print(f'Agent ARN: {launch_result.agent_arn}')
        elif hasattr(launch_result, 'endpoint'):
            print(f'Endpoint info: {launch_result.endpoint}')
        
        # Runtime情報を保存
        if status == 'READY':
            save_runtime_info(launch_result)
            
    except Exception as e:
        print(f'Error during deployment: {e}', file=sys.stderr)
        sys.exit(1)

def save_runtime_info(launch_result):
    """Runtime ARN等の情報をファイルに保存"""
    try:
        info = {
            'status': 'deployed',
            'agent_arn': getattr(launch_result, 'agent_arn', 'N/A'),
            'agent_id': getattr(launch_result, 'agent_id', 'N/A'),
            'endpoint': getattr(launch_result, 'endpoint', 'N/A')
        }
        
        with open('runtime_info.txt', 'w') as f:
            for key, value in info.items():
                f.write(f'{key}: {value}\n')
        
        print('\n--- Runtime Info Saved ---')
        print(f'Runtime information saved to runtime_info.txt')
        
    except Exception as e:
        print(f'Warning: Failed to save runtime info: {e}')

if __name__ == "__main__":
    main()
