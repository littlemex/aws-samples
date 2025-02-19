#!/bin/bash

# コマンドライン引数の処理
SKIP_MODEL_UPLOAD=false
SKIP_IMAGE_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-model-upload)
            SKIP_MODEL_UPLOAD=true
            shift
            ;;
        --skip-image-build)
            SKIP_IMAGE_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-model-upload] [--skip-image-build]"
            exit 1
            ;;
    esac
done

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

if [ "$SKIP_IMAGE_BUILD" = "false" ]; then
    # イメージが既に存在するか確認
    IMAGE_EXISTS=$(aws ecr describe-images --repository-name $(echo $ECR_REPO | cut -d'/' -f2) --region $(echo $ECR_REPO | cut -d'.' -f4) --query 'length(imageDetails)' 2>/dev/null || echo "0")

    if [ "$IMAGE_EXISTS" = "0" ]; then
        # イメージのビルドとプッシュ
        echo "コンテナイメージをビルドしてECRにプッシュします..."
        bash -x ./build_and_push.sh --push
    else
        echo "コンテナイメージは既に存在するためスキップします"
    fi
else
    echo "イメージのビルドとプッシュをスキップします"
fi

# 依存関係のインストール
echo "依存関係をインストールします..."
uv sync

if [ "$SKIP_MODEL_UPLOAD" = "false" ]; then
    # モデルファイルの準備とアップロード
    echo "モデルファイルをtar.gzに圧縮します..."
    tar -czf model.tar.gz -C models u2net.onnx
    echo "model.tar.gz を作成しました"

    # S3にアップロード
    echo "model.tar.gz を S3 にアップロードします..."
    aws s3 cp model.tar.gz "${MODEL_DATA_URL}"
    echo "アップロードが完了しました"
else
    echo "モデルのtar作成とS3アップロードをスキップします"
fi

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

rm -rf model.tar.gz
