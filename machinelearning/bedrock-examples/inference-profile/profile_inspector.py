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

class BedrockProfileInspector:
    def __init__(self, region='us-east-1'):
        """
        BedrockProfileInspectorの初期化
        
        Args:
            region (str): AWSリージョン名（デフォルト: us-east-1）
        """
        self.region = region
        self.bedrock_client = boto3.client('bedrock', region_name=self.region)

    def get_profile_arn(self, profile_name):
        """
        プロファイル名からARNを取得する関数
        
        Args:
            profile_name (str): プロファイル名
            
        Returns:
            str: プロファイルのARN
            
        Raises:
            Exception: プロファイルが見つからない場合
        """
        profiles = self.list_all_profiles()
        for profile in profiles:
            if profile['プロファイル名'] == profile_name:
                return profile['ARN']
        raise Exception(f"指定されたプロファイル '{profile_name}' が見つかりません。")

    def get_profile_details(self, profile_identifier):
        """
        推論プロファイルの詳細情報を取得する関数
        
        Args:
            profile_identifier (str): プロファイル名、ARN、またはID
        
        Returns:
            dict: プロファイルの詳細情報
        """
        try:
            # プロファイル名が指定された場合はARNに変換
            if not (profile_identifier.startswith('arn:') or profile_identifier.startswith('ip-')):
                profile_identifier = self.get_profile_arn(profile_identifier)
            
            response = self.bedrock_client.get_inference_profile(
                inferenceProfileIdentifier=profile_identifier
            )
            # レスポンスから必要な情報を抽出
            profile_info = {
                'プロファイル名': response['inferenceProfileName'],
                'プロファイルID': response['inferenceProfileId'],
                'ARN': response['inferenceProfileArn'],
                'ステータス': response['status'],
                'タイプ': response['type'],
                '説明': response.get('description', 'N/A'),
                'モデル': [{'モデルARN': model['modelArn']} for model in response.get('models', [])],
                '作成日時': response['createdAt'].strftime('%Y-%m-%d %H:%M:%S'),
                '最終更新': response['updatedAt'].strftime('%Y-%m-%d %H:%M:%S'),
                'タグ': self.get_profile_tags(response['inferenceProfileArn'])
            }
            
            return profile_info
        except Exception as e:
            logger.error(f"プロファイル情報の取得中にエラーが発生: {str(e)}")
            raise

    def list_all_profiles(self, profile_type="APPLICATION"):
        """
        すべての推論プロファイルを一覧表示する関数
        
        Args:
            profile_type (str): プロファイルタイプ（"APPLICATION" または "SYSTEM_DEFINED"）
        
        Returns:
            list: プロファイル情報のリスト
        """
        try:
            response = self.bedrock_client.list_inference_profiles(
                typeEquals=profile_type
            )
            
            # レスポンスの内容をログ出力
            logger.info("API Response:")
            logger.info(json.dumps(response, indent=2, default=str))
            
            profiles = []
            for profile in response['inferenceProfileSummaries']:
                # 基本的な情報を抽出
                profile_info = {
                    'プロファイル名': profile['inferenceProfileName'],
                    'プロファイルID': profile['inferenceProfileId'],
                    'ARN': profile['inferenceProfileArn'],
                    'ステータス': profile['status'],
                    'タイプ': profile['type']
                }
                profiles.append(profile_info)
            
            return profiles
        except Exception as e:
            logger.error(f"プロファイル一覧の取得中にエラーが発生: {str(e)}")
            raise

    def get_profile_configuration(self, profile_identifier):
        """
        推論プロファイルの設定情報を取得する関数
        
        Args:
            profile_identifier (str): プロファイル名、ARN、またはID
        
        Returns:
            dict: 設定情報
        """
        try:
            # プロファイル名が指定された場合はARNに変換
            if not (profile_identifier.startswith('arn:') or profile_identifier.startswith('ip-')):
                profile_identifier = self.get_profile_arn(profile_identifier)
            
            response = self.bedrock_client.get_inference_profile(
                inferenceProfileIdentifier=profile_identifier
            )
            
            # 設定情報を抽出
            config = {
                'モデル設定': {
                    'モデル': [{'モデルARN': model['modelArn']} for model in response.get('models', [])],
                },
                'タグ': self.get_profile_tags(profile_identifier),
                'メタデータ': {
                    'プロファイルID': response['inferenceProfileId'],
                    'プロファイルタイプ': response['type'],
                    'リージョン': self.region,
                    '説明': response.get('description', 'N/A')
                }
            }
            
            return config
        except Exception as e:
            logger.error(f"設定情報の取得中にエラーが発生: {str(e)}")
            raise

    def get_profile_tags(self, profile_arn):
        """
        プロファイルに付与されているタグを取得する関数
        
        Args:
            profile_arn (str): プロファイルのARN
        
        Returns:
            dict: タグ情報
        """
        try:
            response = self.bedrock_client.list_tags_for_resource(
                resourceARN=profile_arn
            )
            return {tag['key']: tag['value'] for tag in response.get('tags', [])}
        except Exception as e:
            logger.error(f"タグ情報の取得中にエラーが発生: {str(e)}")
            raise

    def inspect_profile(self, profile_name_or_arn):
        """
        推論プロファイルの総合的な情報を表示する関数
        
        Args:
            profile_name_or_arn (str): プロファイル名またはARN
        """
        try:
            logger.info(f"\n=== 推論プロファイル情報 ===")
            
            # 基本情報の取得
            details = self.get_profile_details(profile_name_or_arn)
            logger.info("\n基本情報:")
            logger.info(json.dumps(details, indent=2, ensure_ascii=False))
            
            # 設定情報の取得
            config = self.get_profile_configuration(profile_name_or_arn)
            logger.info("\n設定情報:")
            logger.info(json.dumps(config, indent=2, ensure_ascii=False))
            
        except Exception as e:
            logger.error(f"プロファイル検査中にエラーが発生: {str(e)}")
            raise

def main():
    """
    メイン実行関数
    """
    import argparse
    
    parser = argparse.ArgumentParser(description='Bedrock推論プロファイル検査ツール')
    parser.add_argument('--profile-name', type=str, help='検査対象の推論プロファイル名')
    parser.add_argument('--list', action='store_true', help='すべてのプロファイルを一覧表示')
    parser.add_argument('--region', type=str, default='us-east-1', help='AWSリージョン名（デフォルト: us-east-1）')
    args = parser.parse_args()

    try:
        inspector = BedrockProfileInspector(region=args.region)
        
        # すべてのアプリケーション推論プロファイルを一覧表示
        logger.info("\n=== アプリケーション推論プロファイル一覧 ===")
        profiles = inspector.list_all_profiles()
        if profiles:
            logger.info(json.dumps(profiles, indent=2, ensure_ascii=False))
        else:
            logger.info("推論プロファイルが存在しません。")

        # プロファイル名が指定された場合のみ詳細を表示
        if args.profile_name:
            try:
                logger.info(f"\n=== プロファイル '{args.profile_name}' の詳細情報 ===")
                inspector.inspect_profile(args.profile_name)
            except Exception as e:
                if 'ResourceNotFoundException' in str(e):
                    logger.error(f"指定されたプロファイル '{args.profile_name}' が見つかりません。")
                    logger.info("利用可能なプロファイルは上記の一覧をご確認ください。")
                else:
                    raise
    except Exception as e:
        logger.error(f"メイン処理でエラーが発生: {str(e)}")
        raise

if __name__ == "__main__":
    main()