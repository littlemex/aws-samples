#!/bin/bash

echo "環境変数検証..."
if [ -z "$AWS_REGION_NAME" ]; then
  echo "エラー: AWS_REGION_NAME が設定されていません"
  echo "export AWS_REGION_NAME=us-east-1 を実行してください"
  exit 1
fi

echo "AWS 認証情報検証..."
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "エラー: AWS 認証情報が正しく設定されていません"
  exit 1
fi

echo "Amazon Bedrock アクセス検証..."
aws bedrock list-foundation-models --region $AWS_REGION_NAME > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "エラー: Amazon Bedrock へのアクセス権限がありません"
  exit 1
fi

# Claude モデルへのアクセス権限確認
echo "Claude モデルアクセス権限検証..."
MODELS=(
  "anthropic.claude-3-7-sonnet-20250219-v1:0"
  "anthropic.claude-3-5-sonnet-20241022-v2:0"
  "anthropic.claude-3-5-sonnet-20240620-v1:0"
)

for MODEL in "${MODELS[@]}"; do
  echo "  モデル $MODEL のアクセス権限を確認中..."
  aws bedrock get-foundation-model --model-identifier $MODEL --region $AWS_REGION_NAME > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "  警告: モデル $MODEL へのアクセス権限がない可能性があります"
    echo "  Amazon Bedrock コンソールで「Model access」からアクセス権限を確認してください"
  else
    echo "  モデル $MODEL へのアクセス権限を確認しました"
  fi
done

# APAC リージョンのモデル確認
APAC_REGION="ap-northeast-1"
echo "APAC リージョン ($APAC_REGION) の Claude モデルアクセス権限検証..."
aws bedrock get-foundation-model --model-identifier "anthropic.claude-3-5-sonnet-20241022-v2:0" --region $APAC_REGION > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "  警告: APAC リージョンの Claude モデルへのアクセス権限がない可能性があります"
  echo "  Amazon Bedrock コンソールで「Model access」からアクセス権限を確認してください"
else
  echo "  APAC リージョンの Claude モデルへのアクセス権限を確認しました"
fi

echo "環境検証完了: すべての基本チェックに合格しました"
