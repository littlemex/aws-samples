#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import yaml
import argparse
import os
import sys
import signal
import time
import boto3
import threading
import subprocess
from typing import List, Dict, Any

def load_config(config_path: str) -> Dict[str, Any]:
    """設定ファイルを読み込む"""
    try:
        with open(config_path, 'r') as file:
            config = yaml.safe_load(file)
            return config
    except Exception as e:
        print(f"設定ファイルの読み込みに失敗しました: {e}")
        sys.exit(1)

def start_port_forwarding_with_boto3(instance_id: str, region: str, local_port: int, remote_port: int) -> subprocess.Popen:
    """
    boto3を使用してポートフォワーディングを開始する
    
    注意: boto3のSSM start_sessionはWebSocketを返しますが、
    実際のポートフォワーディングはAWS CLIのプラグインに依存しているため、
    結局はAWS CLIを使用する必要があります
    """
    cmd = [
        "aws", "ssm", "start-session",
        "--target", instance_id,
        "--region", region,
        "--document-name", "AWS-StartPortForwardingSession",
        "--parameters", f"portNumber=[\"{remote_port}\"],localPortNumber=[\"{local_port}\"]"
    ]
    
    print(f"ポートフォワーディングを開始: ローカル {local_port} -> リモート {remote_port}")
    process = subprocess.Popen(cmd)
    return process

def main():
    parser = argparse.ArgumentParser(description='EC2インスタンスへのSSMポートフォワーディング')
    parser.add_argument('-c', '--config', default='config.yaml', help='設定ファイルのパス')
    parser.add_argument('-i', '--instance-id', help='EC2インスタンスID（環境変数 EC2_INSTANCE_ID より優先）')
    parser.add_argument('-r', '--region', help='AWSリージョン（環境変数 AWS_REGION より優先）')
    args = parser.parse_args()
    
    # 設定ファイルのパスを解決
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, args.config)
    
    # 設定を読み込む
    config = load_config(config_path)
    
    # インスタンスIDの取得順序:
    # 1. コマンドライン引数
    # 2. 環境変数
    # 3. 設定ファイル
    instance_id = args.instance_id or os.environ.get('EC2_INSTANCE_ID') or config.get('instance_id')
    if not instance_id:
        print("エラー: インスタンスIDが指定されていません。コマンドライン引数(-i)、環境変数(EC2_INSTANCE_ID)、または設定ファイルで指定してください。")
        sys.exit(1)
    
    # リージョンの取得順序:
    # 1. コマンドライン引数
    # 2. 環境変数
    # 3. 設定ファイル
    # 4. デフォルト値
    region = args.region or os.environ.get('AWS_REGION') or config.get('region', 'us-east-1')
    
    if 'ports' not in config or not config['ports']:
        print("エラー: ポート設定が見つかりません")
        sys.exit(1)
    
    # 各ポートのフォワーディングを開始
    processes = []
    try:
        for port_config in config['ports']:
            local_port = port_config['local']
            remote_port = port_config['remote']
            process = start_port_forwarding_with_boto3(instance_id, region, local_port, remote_port)
            processes.append(process)
        
        print(f"\nすべてのポートフォワーディングが開始されました。インスタンスID: {instance_id}, リージョン: {region}")
        print("Ctrl+Cで終了します。")
        
        # プロセスが終了するまで待機
        while True:
            time.sleep(1)
    
    except KeyboardInterrupt:
        print("\nポートフォワーディングを終了します...")
    finally:
        # すべてのプロセスを終了
        for process in processes:
            process.send_signal(signal.SIGTERM)
            process.wait()
        
        print("すべてのポートフォワーディングが終了しました。")

if __name__ == "__main__":
    main()
