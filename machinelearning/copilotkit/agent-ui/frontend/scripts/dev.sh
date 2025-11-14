#!/bin/bash

# Frontend - ローカル開発サーバー起動スクリプト
# SSM Parameter StoreからCognito情報を動的に取得して開発サーバーを起動

set -e

# 色付きログ
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "================================"
echo "Frontend - ローカル開発サーバー"
echo "================================"

# 設定
PROJECT_NAME="copilotkit-agentcore"

# NODE_ENVに応じてCLIENT_SUFFIXを設定（環境変数で明示的に指定されていない場合）
if [ -z "$CLIENT_SUFFIX" ]; then
    if [ "$NODE_ENV" = "production" ] || [ "$NODE_ENV" = "prod" ]; then
        CLIENT_SUFFIX="prod"
    else
        CLIENT_SUFFIX="dev"
    fi
fi

SSM_PREFIX="/${PROJECT_NAME}/${CLIENT_SUFFIX}"
REGION="${AWS_REGION:-us-east-1}"
PORT="${PORT:-3000}"

log_info "SSM Parameter Prefix: $SSM_PREFIX"
log_info "Region: $REGION"
log_info "Port: $PORT"

# AWS認証確認
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証情報が設定されていません。"
    exit 1
fi

# SSMからCognito情報を取得
log_info "SSM Parameter StoreからCognito情報を取得しています..."

export COGNITO_CLIENT_ID=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/client-id" \
    --query 'Parameter.Value' \
    --output text \
    --region $REGION 2>/dev/null)

export COGNITO_ISSUER=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/issuer-url" \
    --query 'Parameter.Value' \
    --output text \
    --region $REGION 2>/dev/null)

# 値の確認
if [ -z "$COGNITO_CLIENT_ID" ]; then
    log_error "Cognito Client IDの取得に失敗しました"
    exit 1
fi

if [ -z "$COGNITO_ISSUER" ]; then
    log_error "Cognito Issuer URLの取得に失敗しました"
    exit 1
fi

# NEXTAUTH設定
export NEXTAUTH_URL="http://localhost:${PORT}"
export NEXTAUTH_SECRET=$(openssl rand -base64 32)
export AWS_REGION=$REGION

log_success "環境変数を設定しました"
echo "  COGNITO_CLIENT_ID: $COGNITO_CLIENT_ID"
echo "  COGNITO_ISSUER: $COGNITO_ISSUER"
echo "  NEXTAUTH_URL: $NEXTAUTH_URL"
echo "  AWS_REGION: $AWS_REGION"
echo ""

# 開発サーバー起動
log_info "開発サーバーを起動しています..."
npm run dev -- -p $PORT
