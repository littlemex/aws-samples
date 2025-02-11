#!/bin/bash

# 使用方法を表示する関数
usage() {
    echo "Usage: $0 [--gpu]"
    echo "  --gpu    GPUサポート付きのコンテナをビルド（省略時はCPUバージョン）"
    exit 1
}

# 引数の解析
USE_GPU=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --gpu) USE_GPU=true ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# ECRリポジトリURI
ECR_REPO="067150986393.dkr.ecr.us-east-1.amazonaws.com/rembg-async"

# ECRにログイン
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO

# ビルドプラットフォームとタグの設定
if [ "$USE_GPU" = true ]; then
    PLATFORM="gpu-base"
    TAG="gpu"
    echo "Building GPU-enabled container..."
else
    PLATFORM="cpu-base"
    TAG="cpu"
    echo "Building CPU container..."
fi

# Build container using buildx
cd container
docker buildx build --platform linux/amd64 \
    --build-arg TARGET_PLATFORM=$PLATFORM \
    -t rembg-async:$TAG \
    -f Dockerfile .

# イメージのタグ付け
docker tag rembg-async:$TAG $ECR_REPO:$TAG
docker tag rembg-async:$TAG $ECR_REPO:latest

# ECRにプッシュ
#docker push $ECR_REPO:$TAG
#docker push $ECR_REPO:latest

echo "イメージのビルドとプッシュが完了しました（$TAG バージョン）"