#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# 使用方法を表示する関数
usage() {
    echo "Usage: $0 [--gpu]"
    echo "  --gpu    GPUサポート付きのコンテナをビルド（省略時はCPUバージョン）"
    exit 1
}

# 引数の解析
USE_GPU=${USE_GPU:-false}
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gpu) USE_GPU=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Check required environment variables
if [ -z "$AWS_REGION" ] || [ -z "$ECR_REPO" ]; then
    echo "Error: Required environment variables AWS_REGION and ECR_REPO must be set in .env file"
    exit 1
fi

# ECRにログイン
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# AWS ECRへのログイン (Base imageのため)
# aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 763104351884.dkr.ecr.us-east-1.amazonaws.com

# ビルドプラットフォームとタグの設定
if [ "$USE_GPU" = true ]; then
    TARGET_PLATFORM="gpu"
    TAG="gpu"
    echo "Building GPU-enabled container..."
else
    TARGET_PLATFORM="cpu"
    TAG="cpu"
    echo "Building CPU container..."
fi

# Build container using buildx
docker buildx build --platform linux/amd64 \
    --build-arg TARGET_PLATFORM=$TARGET_PLATFORM \
    -t rembg-async-app:$TAG \
    -f Dockerfile .

# イメージのタグ付け
docker tag rembg-async-app:$TAG $ECR_REPO:$TAG
docker tag rembg-async-app:$TAG $ECR_REPO:latest

# ECRにプッシュ
docker push $ECR_REPO:$TAG
docker push $ECR_REPO:latest

echo "イメージのビルドとプッシュが完了しました（$TAG バージョン）"
