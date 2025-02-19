#!/usr/bin/env python3
import json
from pathlib import Path


def update_env():
    """Update .env file with CDK outputs while preserving existing variables"""
    env_path = Path(".env")

    # デフォルト値の設定
    default_vars = {
        "AWS_ACCOUNT_ID": "",  # AWS CLIの設定から取得することを推奨
        "AWS_REGION": "us-east-1",  # デフォルトリージョン
        "ECR_REPO": "",  # AWS_ACCOUNT_IDとAWS_REGIONから自動生成される
        "SAGEMAKER_ROLE_ARN": "",  # CDKで生成される
        "SAGEMAKER_MODEL_NAME": "rembg-async-app",
        "SAGEMAKER_ENDPOINT_NAME": "rembg-async-app",
        "SAGEMAKER_INSTANCE_TYPE": "ml.g4dn.xlarge",
        "USE_AWS": "true",
        "USE_GPU": "false",
        "MAX_CONCURRENT_INVOCATIONS": "4",
        "MODEL_NAME": "u2net",
        "MODEL_PATH": "/opt/ml/model",
        "INPUT_BUCKET": "",  # CDKで生成される
        "OUTPUT_BUCKET": "",  # CDKで生成される
        "SUCCESS_TOPIC_ARN": "",  # CDKで生成される
        "ERROR_TOPIC_ARN": "",  # CDKで生成される
        "MODEL_DATA_URL": "",  # {INPUT_BUCKET}/models/model.tar.gz として設定される
        "LOCAL_ENDPOINT_HOST": "localhost:8080",
    }

    # 既存の.envファイルを読み込む
    env_vars = default_vars.copy()
    if env_path.exists():
        with open(env_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    try:
                        key, value = line.split("=", 1)
                        env_vars[key.strip()] = value.strip()
                    except ValueError:
                        continue

    # CDKアウトプットから値を取得して設定
    try:
        with open("../cdk/cdk-outputs.json", "r") as f:
            outputs = json.load(f)
            stack_outputs = list(outputs.values())[0]

            # ECRRepositoryUriからAWS_ACCOUNT_IDを抽出
            if "ECRRepositoryUri" in stack_outputs:
                ecr_uri = stack_outputs["ECRRepositoryUri"]
                # ECRRepositoryUriの形式: {account}.dkr.ecr.{region}.amazonaws.com/rembg-async
                aws_account_id = ecr_uri.split(".")[0]
                env_vars["AWS_ACCOUNT_ID"] = aws_account_id
                env_vars["ECR_REPO"] = ecr_uri

            # SageMakerRoleArnを設定
            if "SageMakerRoleArn" in stack_outputs:
                env_vars["SAGEMAKER_ROLE_ARN"] = stack_outputs["SageMakerRoleArn"]

            # NotificationTopicArnを設定
            if "NotificationTopicArn" in stack_outputs:
                env_vars["SUCCESS_TOPIC_ARN"] = stack_outputs["NotificationTopicArn"]
                env_vars["ERROR_TOPIC_ARN"] = stack_outputs["NotificationTopicArn"]
            # S3バケット名を設定
            if "InputBucketName" in stack_outputs:
                env_vars["INPUT_BUCKET"] = stack_outputs["InputBucketName"]
                # MODEL_DATA_URLを設定
                env_vars["MODEL_DATA_URL"] = (
                    f"s3://{stack_outputs['InputBucketName']}/models/model.tar.gz"
                )
            if "OutputBucketName" in stack_outputs:
                env_vars["OUTPUT_BUCKET"] = stack_outputs["OutputBucketName"]
                env_vars["OUTPUT_BUCKET"] = stack_outputs["OutputBucketName"]
    except FileNotFoundError:
        print("Warning: cdk-outputs.json not found")
    except json.JSONDecodeError:
        print("Warning: Invalid JSON in cdk-outputs.json")
    except Exception as e:
        print(f"Warning: Error processing CDK outputs: {str(e)}")

    # ECR_REPOを自動生成（AWS_ACCOUNT_IDとAWS_REGIONが設定されている場合）
    if (
        env_vars["AWS_ACCOUNT_ID"]
        and env_vars["AWS_REGION"]
        and not env_vars["ECR_REPO"]
    ):
        env_vars["ECR_REPO"] = (
            f"{env_vars['AWS_ACCOUNT_ID']}.dkr.ecr.{env_vars['AWS_REGION']}.amazonaws.com/rembg-async"
        )

    # 更新された環境変数を.envファイルに書き込む
    with open(env_path, "w") as f:
        # セクション分けして書き込む
        f.write("# AWS Account and Region\n")
        f.write(f"AWS_ACCOUNT_ID={env_vars['AWS_ACCOUNT_ID']}\n")
        f.write(f"AWS_REGION={env_vars['AWS_REGION']}\n\n")

        f.write("# ECR Repository\n")
        f.write(f"ECR_REPO={env_vars['ECR_REPO']}\n\n")

        f.write("# SageMaker Configuration\n")
        f.write(f"SAGEMAKER_ROLE_ARN={env_vars['SAGEMAKER_ROLE_ARN']}\n")
        f.write(f"SAGEMAKER_MODEL_NAME={env_vars['SAGEMAKER_MODEL_NAME']}\n")
        f.write(f"SAGEMAKER_ENDPOINT_NAME={env_vars['SAGEMAKER_ENDPOINT_NAME']}\n")
        f.write(f"SAGEMAKER_INSTANCE_TYPE={env_vars['SAGEMAKER_INSTANCE_TYPE']}\n\n")

        f.write("# S3 Buckets\n")
        f.write(f"INPUT_BUCKET={env_vars['INPUT_BUCKET']}\n")
        f.write(f"OUTPUT_BUCKET={env_vars['OUTPUT_BUCKET']}\n\n")

        f.write("# SNS Topics\n")
        f.write(f"SUCCESS_TOPIC_ARN={env_vars['SUCCESS_TOPIC_ARN']}\n")
        f.write(f"ERROR_TOPIC_ARN={env_vars['ERROR_TOPIC_ARN']}\n\n")

        f.write("# Runtime Configuration\n")
        f.write(f"USE_AWS={env_vars['USE_AWS']}\n")
        f.write(f"USE_GPU={env_vars['USE_GPU']}\n")
        f.write(
            f"MAX_CONCURRENT_INVOCATIONS={env_vars['MAX_CONCURRENT_INVOCATIONS']}\n"
        )
        f.write(f"MODEL_NAME={env_vars['MODEL_NAME']}\n")
        f.write(f"MODEL_PATH={env_vars['MODEL_PATH']}\n")
        f.write(f"MODEL_DATA_URL={env_vars['MODEL_DATA_URL']}\n\n")

        f.write("# [Local use] Request Client Configuration\n")
        f.write(f"LOCAL_ENDPOINT_HOST={env_vars['LOCAL_ENDPOINT_HOST']}\n")


if __name__ == "__main__":
    update_env()
