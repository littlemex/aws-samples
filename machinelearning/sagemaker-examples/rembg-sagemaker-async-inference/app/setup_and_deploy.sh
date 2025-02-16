#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Check required environment variables
if [ -z "$SAGEMAKER_ROLE_ARN" ] || [ -z "$ECR_REPO" ] || [ -z "$INPUT_BUCKET" ] || [ -z "$OUTPUT_BUCKET" ]; then
    echo "Error: Required environment variables must be set in .env file"
    exit 1
fi

# イメージが既に存在するか確認
IMAGE_EXISTS=$(aws ecr describe-images --repository-name $(echo $ECR_REPO | cut -d'/' -f2) --region $(echo $ECR_REPO | cut -d'.' -f4) --query 'length(imageDetails)' 2>/dev/null || echo "0")

if [ "$IMAGE_EXISTS" = "0" ]; then
    # イメージのビルドとプッシュ
    echo "コンテナイメージをビルドしてECRにプッシュします..."
    bash -x ./build_and_push.sh --push
else
    echo "コンテナイメージは既に存在するためスキップします"
fi

# 依存関係のインストール
echo "依存関係をインストールします..."
uv sync

# SageMaker エンドポイントのデプロイ
echo "SageMaker エンドポイントをデプロイします..."
GPU_FLAG=""
if [ "$USE_GPU" = "true" ]; then
    GPU_FLAG="--use-gpu"
fi

uv run deploy_endpoint.py \
    --role-arn "$SAGEMAKER_ROLE_ARN" \
    --image-uri "$ECR_REPO" \
    --input-bucket "$INPUT_BUCKET" \
    --output-bucket "$OUTPUT_BUCKET" \
    $GPU_FLAG

echo "セットアップが完了しました。"