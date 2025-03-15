#!/usr/bin/env python3
import json
import argparse
import logging
import sys
import time
import boto3
import sagemaker
from sagemaker.huggingface import HuggingFaceModel, get_huggingface_llm_image_uri

# ロギングの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def get_gpu_count_for_instance(instance_type):
    """インスタンスタイプに基づいて GPU 数を取得"""
    gpu_counts = {
        'ml.g5.2xlarge': 1,
        'ml.g5.4xlarge': 1,
        'ml.g5.8xlarge': 1,
        'ml.g5.16xlarge': 1,
        'ml.g5.12xlarge': 4,
        'ml.g5.24xlarge': 4,
        'ml.g5.48xlarge': 8,
        # 他のインスタンスタイプも必要に応じて追加
    }
    return gpu_counts.get(instance_type, 1)  # デフォルトは 1

def create_sagemaker_execution_role():
    """SageMaker実行ロールを作成または更新する"""
    iam = boto3.client('iam')
    role_name = 'sagemaker_execution_role'
    
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "sagemaker.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    
    try:
        # ロールが存在するか確認
        try:
            role = iam.get_role(RoleName=role_name)
            # 既存のロールの信頼関係を更新
            iam.update_assume_role_policy(
                RoleName=role_name,
                PolicyDocument=json.dumps(trust_policy)
            )
            logger.info(f"既存のロール '{role_name}' の信頼関係を更新しました")
        except iam.exceptions.NoSuchEntityException:
            # ロールが存在しない場合は新規作成
            role = iam.create_role(
                RoleName=role_name,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description='Role for SageMaker execution'
            )
            logger.info(f"ロール '{role_name}' を作成しました")
        
        # 必要なポリシーをアタッチ
        policies = [
            'arn:aws:iam::aws:policy/AmazonSageMakerFullAccess',
            'arn:aws:iam::aws:policy/AmazonS3FullAccess'
        ]
        
        for policy_arn in policies:
            try:
                iam.attach_role_policy(
                    RoleName=role_name,
                    PolicyArn=policy_arn
                )
                logger.info(f"ポリシー {policy_arn} をアタッチしました")
            except iam.exceptions.EntityAlreadyExistsException:
                logger.info(f"ポリシー {policy_arn} は既にアタッチされています")
        
        # 最新のロール情報を取得
        role = iam.get_role(RoleName=role_name)
        return role['Role']['Arn']
    except Exception as e:
        logger.error(f"ロールの作成/更新中にエラーが発生しました: {e}")
        raise

def get_sagemaker_role():
    """SageMaker実行ロールを取得または作成"""
    try:
        role = sagemaker.get_execution_role()
        logger.info(f"既存のSageMaker実行ロールを使用: {role}")
        return role
    except ValueError:
        logger.info("SageMaker実行ロールが見つかりません。新しいロールを作成します...")
        return create_sagemaker_execution_role()

def clean_up_existing_resources(sm_client, endpoint_name):
    """既存のエンドポイントとエンドポイント設定を削除する"""
    # エンドポイントの削除
    try:
        sm_client.describe_endpoint(EndpointName=endpoint_name)
        logger.info(f"既存のエンドポイント '{endpoint_name}' を削除します")
        sm_client.delete_endpoint(EndpointName=endpoint_name)
        
        # エンドポイントの削除完了を待機
        logger.info("エンドポイントの削除完了を待機中...")
        waiter = sm_client.get_waiter('endpoint_deleted')
        waiter.wait(
            EndpointName=endpoint_name,
            WaiterConfig={'Delay': 30, 'MaxAttempts': 20}
        )
    except sm_client.exceptions.ClientError:
        logger.info(f"エンドポイント '{endpoint_name}' は存在しません")
    
    # エンドポイント設定の削除
    try:
        sm_client.describe_endpoint_config(EndpointConfigName=endpoint_name)
        logger.info(f"エンドポイント設定 '{endpoint_name}' を削除します")
        sm_client.delete_endpoint_config(EndpointConfigName=endpoint_name)
        logger.info("削除処理の完了を待機中...")
        time.sleep(5)  # 削除処理が反映されるのを少し待つ
    except sm_client.exceptions.ClientError:
        logger.info(f"エンドポイント設定 '{endpoint_name}' は存在しません")

def create_model_config(args):
    """モデル設定を作成する"""
    # インスタンスタイプに基づいて GPU 数を設定
    gpu_count = get_gpu_count_for_instance(args.instance_type)
    
    hub = {
        'HF_MODEL_ID': 'tokyotech-llm/Llama-3.3-Swallow-70B-v0.4',
        'SM_NUM_GPUS': json.dumps(gpu_count),
        'MAX_INPUT_LENGTH': '2048',
        'MAX_TOTAL_TOKENS': '4096',
        'HF_MODEL_QUANTIZE': 'bitsandbytes-nf4'
    }
    
    logger.info("モデル設定:")
    logger.info(f"- モデルID: {hub['HF_MODEL_ID']}")
    logger.info(f"- GPU数: {gpu_count} (インスタンスタイプ: {args.instance_type})")
    logger.info(f"- インスタンス数: {args.num_instances}")
    
    return hub

def deploy_model(args):
    """モデルのデプロイ"""
    try:
        # SageMakerクライアントの作成
        sm_client = boto3.client('sagemaker')
        
        # 既存のリソースをクリーンアップ
        clean_up_existing_resources(sm_client, args.endpoint_name)
        
        # モデル設定の作成
        hub = create_model_config(args)
        
        # SageMaker実行ロールの取得
        role = get_sagemaker_role()
        logger.info(f"使用するロール: {role}")

        # Hugging Faceモデルの作成
        huggingface_model = HuggingFaceModel(
            image_uri=get_huggingface_llm_image_uri("huggingface", version="3.0.1"),
            env=hub,
            role=role,
        )

        # モデルのデプロイ
        logger.info(f"モデルをデプロイします: {args.endpoint_name}")
        predictor = huggingface_model.deploy(
            initial_instance_count=args.num_instances,
            instance_type=args.instance_type,
            container_startup_health_check_timeout=args.timeout,
            endpoint_name=args.endpoint_name
        )

        # エンドポイントの準備待ち
        logger.info("エンドポイントの準備完了を待機中...")
        waiter = sm_client.get_waiter('endpoint_in_service')
        waiter.wait(
            EndpointName=args.endpoint_name,
            WaiterConfig={'Delay': 30, 'MaxAttempts': 60}
        )

        # テストリクエスト実行
        if args.test:
            test_endpoint(predictor)

        logger.info(f"モデルのデプロイが完了しました。エンドポイント名: {args.endpoint_name}")
        return predictor

    except Exception as e:
        logger.error(f"モデルのデプロイに失敗しました: {e}")
        raise

def test_endpoint(predictor):
    """エンドポイントのテスト"""
    logger.info("テストリクエストを送信...")
    response = predictor.predict({
        "inputs": "Hi, what can you help me with?",
        "parameters": {
            "max_new_tokens": 256,
            "temperature": 0.7,
            "top_p": 0.9
        }
    })
    logger.info(f"テスト応答: {response}")


def main():
    parser = argparse.ArgumentParser(description='SageMakerにLlamaモデルをデプロイ')
    parser.add_argument('--endpoint-name', type=str, required=True,
                      help='SageMakerエンドポイントの名前')
    parser.add_argument('--instance-type', type=str, default='ml.g5.2xlarge',
                      help='SageMakerインスタンスタイプ')
    parser.add_argument('--num-instances', type=int, default=1,
                      help='デプロイするインスタンス数')
    parser.add_argument('--timeout', type=int, default=900,
                      help='コンテナ起動ヘルスチェックのタイムアウト（秒）')
    parser.add_argument('--test', action='store_true',
                      help='デプロイ後にテスト推論を実行')
    parser.add_argument('--region', type=str,
                      help='AWSリージョン（デフォルト設定を上書き）')

    args = parser.parse_args()

    # リージョンの設定
    if args.region:
        boto3.setup_default_session(region_name=args.region)

    try:
        deploy_model(args)
    except Exception as e:
        logger.error(f"デプロイに失敗しました: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()