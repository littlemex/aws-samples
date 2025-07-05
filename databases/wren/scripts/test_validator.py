#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AWS Bedrock モデルバリデーターのテストスクリプト

このスクリプトは model_validator.py の機能をテストするためのものです。
サンプル設定ファイルを作成し、モデルバリデーターを実行します。

使用方法:
    python test_validator.py [--region REGION]
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import tempfile
import yaml

# ロギングの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_validator")

def parse_args():
    """コマンドライン引数を解析します。"""
    parser = argparse.ArgumentParser(description='AWS Bedrock モデルバリデーターのテスト')
    parser.add_argument('--region', type=str, default='us-east-1', help='AWS リージョン')
    parser.add_argument('--verbose', action='store_true', help='詳細出力を有効にする')
    return parser.parse_args()

def create_sample_config():
    """サンプル設定ファイルを作成します。"""
    config = [
        {
            "type": "llm",
            "provider": "litellm_llm",
            "models": [
                {
                    "model": "bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0",
                    "timeout": 600,
                    "kwargs": {
                        "temperature": 0
                    },
                    "aws_region_name": "us-east-1"
                },
                {
                    "model": "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0",
                    "timeout": 600,
                    "kwargs": {
                        "temperature": 0
                    },
                    "aws_region_name": "us-east-1"
                }
            ]
        },
        {
            "type": "embedder",
            "provider": "litellm_embedder",
            "models": [
                {
                    "model": "bedrock/amazon.titan-embed-text-v2:0",
                    "timeout": 600,
                    "aws_region_name": "us-east-1"
                }
            ]
        },
        {
            "settings": {
                "litellm_settings": {
                    "fallbacks": [
                        {
                            "bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0": [
                                "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0"
                            ]
                        }
                    ],
                    "aws_region_name": "us-east-1",
                    "num_retries": 2,
                    "request_timeout": 30,
                    "aws_session_name": "litellm-bedrock-session",
                    "drop_params": True
                },
                "router_settings": {
                    "default_model": "bedrock/anthropic.claude-3-7-sonnet-20250219-v1:0",
                    "failover": True,
                    "timeout": 30,
                    "retries": 3
                }
            }
        }
    ]
    
    # 一時ファイルを作成
    fd, temp_path = tempfile.mkstemp(suffix='.yaml')
    with os.fdopen(fd, 'w') as f:
        yaml.dump_all(config, f)
    
    logger.info(f"サンプル設定ファイルを作成しました: {temp_path}")
    return temp_path

def run_validator(config_path, region, verbose=False):
    """モデルバリデーターを実行します。"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    validator_path = os.path.join(script_dir, "model_validator.py")
    
    cmd = [validator_path, "--config", config_path, "--region", region]
    if verbose:
        cmd.append("--verbose")
    
    logger.info(f"コマンドを実行: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        print("\n" + "="*80)
        print("標準出力:")
        print(result.stdout)
        
        if result.stderr:
            print("\n" + "="*80)
            print("標準エラー出力:")
            print(result.stderr)
        
        print("\n" + "="*80)
        print(f"終了コード: {result.returncode}")
        
        return result.returncode
    except Exception as e:
        logger.error(f"バリデーターの実行中にエラーが発生しました: {e}")
        return 1

def main():
    """メインエントリーポイント。"""
    args = parse_args()
    
    try:
        # サンプル設定ファイルを作成
        config_path = create_sample_config()
        
        # バリデーターを実行
        exit_code = run_validator(config_path, args.region, args.verbose)
        
        # 一時ファイルを削除
        os.unlink(config_path)
        logger.info(f"一時ファイルを削除しました: {config_path}")
        
        # 結果を表示
        if exit_code == 0:
            print("\n✅ テストは成功しました！すべてのモデルが有効です。")
        else:
            print("\n❌ テストは失敗しました。一部のモデルが有効になっていません。")
            print("AWS Bedrock コンソールでモデルを有効化してください:")
            print("https://console.aws.amazon.com/bedrock/home#/modelaccess")
        
        return exit_code
    except Exception as e:
        logger.error(f"テスト実行中にエラーが発生しました: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
