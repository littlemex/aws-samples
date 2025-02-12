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

# イメージのビルドとプッシュ
echo "コンテナイメージをビルドしてECRにプッシュします..."
if [ "$USE_GPU" = "true" ]; then
    ./build_and_push.sh --gpu
else
    ./build_and_push.sh
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