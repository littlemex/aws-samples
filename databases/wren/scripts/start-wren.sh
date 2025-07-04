#!/bin/bash
set -e

# 作業ディレクトリに移動
cd /home/coder/aws-samples/databases/wren

# 環境変数が設定されているか確認し、未設定の場合はデフォルト値を設定
if [ ! -f .env ] || ! grep -q "PLATFORM=" .env; then
  echo "環境変数ファイルを修正しています..."
  
  # .env ファイルのバックアップを作成（存在する場合）
  if [ -f .env ]; then
    cp .env .env.bak
  fi
  
  # 必須環境変数を設定
  cat > .env << EOL
COMPOSE_PROJECT_NAME=wrenai
PLATFORM=linux/amd64
PROJECT_DIR=.

# サービスポート
WREN_ENGINE_PORT=8080
WREN_ENGINE_SQL_PORT=7432
WREN_AI_SERVICE_PORT=5555
WREN_UI_PORT=3000
IBIS_SERVER_PORT=8000
WREN_UI_ENDPOINT=http://wren-ui:3000

# AI サービス設定
QDRANT_HOST=qdrant
SHOULD_FORCE_DEPLOY=1

# AWS Bedrock 設定
AWS_REGION_NAME=us-east-1

# バージョン
WREN_PRODUCT_VERSION=0.25.0
WREN_ENGINE_VERSION=0.17.1
WREN_AI_SERVICE_VERSION=0.24.3
IBIS_SERVER_VERSION=0.17.1
WREN_UI_VERSION=0.30.0
WREN_BOOTSTRAP_VERSION=0.1.5

# ユーザーID
USER_UUID=user-$(date +%s)

# その他のサービス
POSTHOG_API_KEY=phc_nhF32aj4xHXOZb0oqr2cn4Oy9uiWzz6CCP4KZmRq9aE
POSTHOG_HOST=https://app.posthog.com
TELEMETRY_ENABLED=false

# 生成モデル
GENERATION_MODEL=bedrock/converse/us.anthropic.claude-3-7-sonnet-20250219-v1:0

# ホストポート
HOST_PORT=3000
AI_SERVICE_FORWARD_PORT=5555

# Wren UI
EXPERIMENTAL_ENGINE_RUST_VERSION=false
EOL
  echo ".env ファイルを作成しました"
else
  echo "既存の .env ファイルを使用します"
fi

# Docker Compose を実行
echo "Docker コンテナを起動しています..."
docker-compose --env-file .env up -d

echo "起動完了。Wren AI UI は http://localhost:3000 でアクセスできます"
