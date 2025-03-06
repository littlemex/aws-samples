#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Amazon Bedrock コスト分析スクリプト
部門ごとのコストと使用状況を分析するための機能を提供します。
"""

import boto3
import json
from datetime import datetime, timezone, timedelta
import logging
from profile_inspector import BedrockProfileInspector

# ロギングの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_config():
    """
    設定ファイルを読み込む関数
    
    Returns:
        dict: 設定情報
    """
    try:
        with open('config.json', 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        logger.warning("config.jsonが見つかりません。デフォルト設定を使用します。")
        config = {
            "profile_names": [
                "claims_dept_claude_3_sonnet_profile",
                "underwriting_dept_llama3_70b_profile"
            ]
        }
    except json.JSONDecodeError as e:
        logger.error(f"config.jsonの解析に失敗しました: {str(e)}")
        raise
    return config

def get_department_tags(profile_names):
    """
    プロファイル名からdeptタグの値を取得する関数
    
    Args:
        profile_names (list): プロファイル名のリスト
    
    Returns:
        list: deptタグの値のリスト
    """
    inspector = BedrockProfileInspector()
    dept_values = set()
    
    for profile_name in profile_names:
        try:
            details = inspector.get_profile_details(profile_name)
            if 'タグ' in details and 'dept' in details['タグ']:
                dept_values.add(details['タグ']['dept'])
        except Exception as e:
            logger.warning(f"プロファイル {profile_name} のタグ情報取得に失敗: {str(e)}")
    
    return list(dept_values)

def get_cost_by_department(start_date, end_date):
    """
    部門ごとのコストを取得する関数
    
    Args:
        start_date (str): 開始日 (YYYY-MM-DD形式)
        end_date (str): 終了日 (YYYY-MM-DD形式)
    
    Returns:
        dict: 部門ごとのコスト情報
    """
    config = load_config()
    dept_values = get_department_tags(config['profile_names'])
    
    ce_client = boto3.client('ce')
    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date,
                'End': end_date
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost', 'UsageQuantity'],
            GroupBy=[
                {'Type': 'TAG', 'Key': 'dept'}
            ],
            Filter={
                'And': [
                    {
                        'Dimensions': {
                            'Key': 'SERVICE',
                            'Values': ['Amazon Bedrock']
                        }
                    },
                    {
                        'Tags': {
                            'Key': 'dept',
                            'Values': dept_values
                        }
                    }
                ]
            }
        )
        logger.info("部門ごとのコスト情報を取得しました")
        return response
    except Exception as e:
        logger.error(f"コスト情報の取得中にエラーが発生: {str(e)}")
        raise

def get_usage_metrics(profile_name, hours=24):
    """
    CloudWatchメトリクスから使用状況を取得する関数
    
    Args:
        profile_name (str): 推論プロファイル名
        hours (int): 取得する期間（時間）
    
    Returns:
        dict: 使用状況メトリクス
    """
    cloudwatch = boto3.client('cloudwatch')
    try:
        # 各種メトリクスを取得
        metrics = {
            'InvocationCount': [],  # 呼び出し回数
            'ProcessingTime': [],   # 処理時間
            'TokenCount': [],       # トークン数
            'CharacterCount': []    # 文字数
        }
        
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=hours)
        
        for metric_name in metrics.keys():
            response = cloudwatch.get_metric_statistics(
                Namespace='AWS/Bedrock',
                MetricName=metric_name,
                Dimensions=[
                    {
                        'Name': 'InferenceProfileName',
                        'Value': profile_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,  # 1時間単位
                Statistics=['Sum', 'Average']
            )
            metrics[metric_name] = response['Datapoints']
        
        logger.info(f"使用状況メトリクスを取得: {profile_name}")
        return metrics
    except Exception as e:
        logger.error(f"メトリクス取得中にエラーが発生: {str(e)}")
        raise

def analyze_department_costs():
    """
    部門ごとのコストと使用状況を分析する関数
    """
    try:
        # 今月の日付範囲を設定
        today = datetime.now()
        start_date = today.replace(day=1).strftime('%Y-%m-%d')
        end_date = today.strftime('%Y-%m-%d')
        
        # コスト情報の取得
        logger.info("\n=== 部門別コスト分析 ===")
        cost_data = get_cost_by_department(start_date, end_date)
        
        # 設定ファイルからプロファイル名を読み込む
        logger.info("\n=== 部門別使用状況 ===")
        config = load_config()
        inspector = BedrockProfileInspector()
        
        # プロファイルごとの使用状況を取得
        usage_data = {}
        for profile_name in config['profile_names']:
            try:
                # プロファイルのタグ情報を取得
                details = inspector.get_profile_details(profile_name)
                dept = details['タグ'].get('dept')
                
                if dept:
                    usage_data[dept] = get_usage_metrics(profile_name)
                else:
                    logger.warning(f"プロファイル {profile_name} にdeptタグが設定されていません")
            except Exception as e:
                logger.warning(f"プロファイル {profile_name} の使用状況取得に失敗: {str(e)}")
        
        # 結果の表示
        logger.info("\n=== 分析結果 ===")
        logger.info("\n部門別コスト:")
        logger.info(json.dumps(cost_data, indent=2))
        
        logger.info("\n部門別使用状況:")
        logger.info(json.dumps(usage_data, indent=2))
        
        return {
            'costs': cost_data,
            'usage': usage_data
        }
        
    except Exception as e:
        logger.error(f"コスト分析中にエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    analyze_department_costs()