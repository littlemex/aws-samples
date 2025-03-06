#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Amazon Bedrock アプリケーション推論プロファイル検査ツール
推論プロファイルの詳細情報を確認するための機能を提供します。
"""

import boto3
import json
from datetime import datetime
import logging

# ロギングの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_profile_details(profile_name_or_arn):
    """
    推論プロファイルの詳細情報を取得する関数
    
    Args:
        profile_name_or_arn (str): プロファイル名またはARN
    
    Returns:
        dict: プロファイルの詳細情報
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.get_inference_profile(
            inferenceProfileIdentifier=profile_name_or_arn
        )
        
        # レスポンスから必要な情報を抽出
        profile_info = {
            'プロファイル名': response['inferenceProfileName'],
            'ARN': response['inferenceProfileArn'],
            'ステータス': response['status'],
            'モデルARN': response['modelArn'],
            '作成日時': response['creationTime'].strftime('%Y-%m-%d %H:%M:%S'),
            '最終更新': response['lastModifiedTime'].strftime('%Y-%m-%d %H:%M:%S'),
            'プロビジョニング済みユニット': response.get('provisionedInferenceUnits', 'N/A'),
            'エンドポイントステータス': response.get('endpointStatus', 'N/A')
        }
        
        return profile_info
    except Exception as e:
        logger.error(f"プロファイル情報の取得中にエラーが発生: {str(e)}")
        raise

def list_all_profiles(profile_type="APPLICATION"):
    """
    すべての推論プロファイルを一覧表示する関数
    
    Args:
        profile_type (str): プロファイルタイプ（"APPLICATION" または "SYSTEM_DEFINED"）
    
    Returns:
        list: プロファイル情報のリスト
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.list_inference_profiles(
            typeEquals=profile_type
        )
        
        profiles = []
        for profile in response['inferenceProfiles']:
            # 各プロファイルの詳細情報を取得
            detail = get_profile_details(profile['inferenceProfileArn'])
            profiles.append(detail)
        
        return profiles
    except Exception as e:
        logger.error(f"プロファイル一覧の取得中にエラーが発生: {str(e)}")
        raise

def get_profile_configuration(profile_name_or_arn):
    """
    推論プロファイルの設定情報を取得する関数
    
    Args:
        profile_name_or_arn (str): プロファイル名またはARN
    
    Returns:
        dict: 設定情報
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.get_inference_profile(
            inferenceProfileIdentifier=profile_name_or_arn
        )
        
        # 設定情報を抽出
        config = {
            'モデル設定': {
                'モデルID': response['modelArn'],
                'プロビジョニング設定': response.get('provisionedInferenceUnits', 'オンデマンド'),
            },
            'タグ': get_profile_tags(profile_name_or_arn),
            'メタデータ': {
                'プロファイルタイプ': response.get('type', 'N/A'),
                'リージョン': response.get('region', 'N/A')
            }
        }
        
        return config
    except Exception as e:
        logger.error(f"設定情報の取得中にエラーが発生: {str(e)}")
        raise

def get_profile_tags(profile_arn):
    """
    プロファイルに付与されているタグを取得する関数
    
    Args:
        profile_arn (str): プロファイルのARN
    
    Returns:
        dict: タグ情報
    """
    bedrock_client = boto3.client('bedrock')
    try:
        response = bedrock_client.list_tags_for_resource(
            resourceARN=profile_arn
        )
        return {tag['key']: tag['value'] for tag in response.get('tags', [])}
    except Exception as e:
        logger.error(f"タグ情報の取得中にエラーが発生: {str(e)}")
        raise

def inspect_profile(profile_name_or_arn):
    """
    推論プロファイルの総合的な情報を表示する関数
    
    Args:
        profile_name_or_arn (str): プロファイル名またはARN
    """
    try:
        logger.info(f"\n=== 推論プロファイル情報 ===")
        
        # 基本情報の取得
        details = get_profile_details(profile_name_or_arn)
        logger.info("\n基本情報:")
        logger.info(json.dumps(details, indent=2, ensure_ascii=False))
        
        # 設定情報の取得
        config = get_profile_configuration(profile_name_or_arn)
        logger.info("\n設定情報:")
        logger.info(json.dumps(config, indent=2, ensure_ascii=False))
        
    except Exception as e:
        logger.error(f"プロファイル検査中にエラーが発生: {str(e)}")
        raise

def main():
    """
    メイン実行関数
    """
    try:
        # すべてのアプリケーション推論プロファイルを一覧表示
        logger.info("\n=== アプリケーション推論プロファイル一覧 ===")
        profiles = list_all_profiles()
        logger.info(json.dumps(profiles, indent=2, ensure_ascii=False))
        
        # 特定のプロファイルの詳細を表示（例として最初のプロファイルを使用）
        if profiles:
            first_profile_arn = profiles[0]['ARN']
            inspect_profile(first_profile_arn)
        
    except Exception as e:
        logger.error(f"メイン処理でエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    main()