#!/bin/bash
set -e

# 作業ディレクトリ
cd /home/coder/aws-samples/databases/wren

# docker-compose.yaml のダウンロード
echo "Downloading docker-compose.yaml from Wren AI GitHub repository..."
curl -O https://raw.githubusercontent.com/Canner/WrenAI/main/docker/docker-compose.yaml

# .env.example のダウンロード
echo "Downloading .env.example from Wren AI GitHub repository..."
curl -O https://raw.githubusercontent.com/Canner/WrenAI/main/docker/.env.example

# .env.example.dev の作成
echo "Creating .env.example.dev for AWS Bedrock..."
cat > .env.example.dev << 'EOL'
COMPOSE_PROJECT_NAME=wrenai
PLATFORM=linux/amd64
PROJECT_DIR=.

# サービスポート
WREN_ENGINE_PORT=8080
WREN_ENGINE_SQL_PORT=7432
WREN_AI_SERVICE_PORT=5555
WREN_UI_PORT=3000
IBIS_SERVER_PORT=8000
WREN_UI_ENDPOINT=http://wren-ui:${WREN_UI_PORT}

# AI サービス設定
QDRANT_HOST=qdrant
SHOULD_FORCE_DEPLOY=1

# AWS Bedrock 設定
AWS_REGION_NAME=us-east-1
# IAM ロールが設定済みのため、以下は不要
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=

# バージョン
# 以下は .env.example から自動的に取得される最新バージョン
WREN_PRODUCT_VERSION=$(grep WREN_PRODUCT_VERSION .env.example | cut -d= -f2)
WREN_ENGINE_VERSION=$(grep WREN_ENGINE_VERSION .env.example | cut -d= -f2)
WREN_AI_SERVICE_VERSION=$(grep WREN_AI_SERVICE_VERSION .env.example | cut -d= -f2)
IBIS_SERVER_VERSION=$(grep IBIS_SERVER_VERSION .env.example | cut -d= -f2)
WREN_UI_VERSION=$(grep WREN_UI_VERSION .env.example | cut -d= -f2)
WREN_BOOTSTRAP_VERSION=$(grep WREN_BOOTSTRAP_VERSION .env.example | cut -d= -f2)

# ユーザーID (uuid v4)
USER_UUID=

# その他のサービス
POSTHOG_API_KEY=phc_nhF32aj4xHXOZb0oqr2cn4Oy9uiWzz6CCP4KZmRq9aE
POSTHOG_HOST=https://app.posthog.com
TELEMETRY_ENABLED=false

# 生成モデル
GENERATION_MODEL=bedrock/converse/us.anthropic.claude-3-7-sonnet-20250219-v1:0

# Langfuse（オプション）
LANGFUSE_SECRET_KEY=
LANGFUSE_PUBLIC_KEY=

# ホストポート
HOST_PORT=3000
AI_SERVICE_FORWARD_PORT=5555

# Wren UI
EXPERIMENTAL_ENGINE_RUST_VERSION=false
EOL

# バージョン情報を .env.example から取得して .env.example.dev に反映
sed -i "s/WREN_PRODUCT_VERSION=\$(grep WREN_PRODUCT_VERSION .env.example | cut -d= -f2)/WREN_PRODUCT_VERSION=$(grep WREN_PRODUCT_VERSION .env.example | cut -d= -f2)/g" .env.example.dev
sed -i "s/WREN_ENGINE_VERSION=\$(grep WREN_ENGINE_VERSION .env.example | cut -d= -f2)/WREN_ENGINE_VERSION=$(grep WREN_ENGINE_VERSION .env.example | cut -d= -f2)/g" .env.example.dev
sed -i "s/WREN_AI_SERVICE_VERSION=\$(grep WREN_AI_SERVICE_VERSION .env.example | cut -d= -f2)/WREN_AI_SERVICE_VERSION=$(grep WREN_AI_SERVICE_VERSION .env.example | cut -d= -f2)/g" .env.example.dev
sed -i "s/IBIS_SERVER_VERSION=\$(grep IBIS_SERVER_VERSION .env.example | cut -d= -f2)/IBIS_SERVER_VERSION=$(grep IBIS_SERVER_VERSION .env.example | cut -d= -f2)/g" .env.example.dev
sed -i "s/WREN_UI_VERSION=\$(grep WREN_UI_VERSION .env.example | cut -d= -f2)/WREN_UI_VERSION=$(grep WREN_UI_VERSION .env.example | cut -d= -f2)/g" .env.example.dev
sed -i "s/WREN_BOOTSTRAP_VERSION=\$(grep WREN_BOOTSTRAP_VERSION .env.example | cut -d= -f2)/WREN_BOOTSTRAP_VERSION=$(grep WREN_BOOTSTRAP_VERSION .env.example | cut -d= -f2)/g" .env.example.dev

# config.yaml ファイルをルートディレクトリにコピー
echo "Copying config.yaml to root directory..."
if [ -f "init/wren/config.yaml" ]; then
  cp init/wren/config.yaml .
  echo "config.yaml copied from init/wren/config.yaml"
else
  echo "Warning: init/wren/config.yaml not found. Please create config.yaml manually."
fi

# data ディレクトリの作成
echo "Creating data directory..."
mkdir -p data

# .env.example.dev を .env にコピー
echo "Copying .env.example.dev to .env..."
cp .env.example.dev .env

echo "Setup complete. Files created:"
echo "- docker-compose.yaml (from GitHub)"
echo "- .env.example (from GitHub)"
echo "- .env.example.dev (customized for AWS Bedrock)"
echo "- .env (copied from .env.example.dev)"
echo "- data/ (directory for data files)"
if [ -f "config.yaml" ]; then
  echo "- config.yaml (copied from init/wren/config.yaml)"
fi
echo ""
echo "To start the services, run:"
echo "cd /home/coder/aws-samples/databases/wren && docker-compose up -d"
