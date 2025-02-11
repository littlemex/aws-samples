#!/bin/bash

# モデルのダウンロード
echo "モデルをダウンロードします..."
python /home/littlemex/home/ml-samples/oss-apps/rembg/download_models.py

# SageMaker エンドポイントのデプロイ
echo "SageMaker エンドポイントをデプロイします..."
uv sync

uv run deploy_endpoint.py \
    --role-arn "arn:aws:iam::067150986393:role/RembgAsyncInferenceStack-SageMakerExecutionRole7843-OmcIhdyWVfgO" \
    --image-uri "067150986393.dkr.ecr.us-east-1.amazonaws.com/rembg-async" \
    --input-bucket "rembgasyncinferencestack-inputbucket3bf8630a-nnd5plof2oa1" \
    --output-bucket "rembgasyncinferencestack-outputbucket7114eb27-5guwa7nytcbt" \
    --use-gpu

echo "セットアップが完了しました。"