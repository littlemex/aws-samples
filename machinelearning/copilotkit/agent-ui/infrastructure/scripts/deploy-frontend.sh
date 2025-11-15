#!/bin/bash

# CopilotKit Agent UI - フロントエンドデプロイ
# 
# このスクリプトは以下を行います：
# 1. .envファイルの読み込み
# 2. 環境変数の確認
# 3. SSMからCognito情報取得
# 4. フロントエンドのビルド
# 5. Next.jsスタックのデプロイ

set -e  # エラー時に停止

# 色付きログ用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

echo "==========================================="
echo "CopilotKit Agent UI - フロントエンドデプロイ"
echo "==========================================="

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

log_info "プロジェクトディレクトリ: $PROJECT_DIR"

# NODE_ENVに応じた環境ファイルの読み込み
ENV_NAME="${NODE_ENV:-production}"
ENV_FILE=".env.${ENV_NAME}"

log_info "環境: $ENV_NAME"

# 環境ファイルの確認と読み込み
if [ -f "$ENV_FILE" ]; then
    log_info "環境ファイルを読み込んでいます: $ENV_FILE"
    source "$ENV_FILE"
elif [ -f ".env" ]; then
    log_warn ".env.${ENV_NAME} が見つかりません。フォールバックとして .env を使用します。"
    log_info ".envファイルを読み込んでいます..."
    source .env
else
    log_error "環境設定ファイルが見つかりません。"
    log_info "初回セットアップを実行してください: ./scripts/setup.sh --env=${ENV_NAME}"
    exit 1
fi

# 必須環境変数のチェック
log_info "環境変数を確認しています..."
# v5環境変数を優先、v4もサポート（後方互換性）
AUTH_SECRET="${AUTH_SECRET:-$NEXTAUTH_SECRET}"
if [ -z "$AUTH_SECRET" ]; then
    log_error "AUTH_SECRETが設定されていません。"
    log_info "setup.shを実行して環境設定ファイルを生成してください。"
    exit 1
fi

log_success "環境変数の確認が完了しました。"

# AWS認証情報の確認
log_info "AWS認証情報を確認しています..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証情報が設定されていません。"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_REGION=$(aws configure get region || echo "${AWS_REGION:-us-east-1}")
log_success "AWS認証成功 - Account: $ACCOUNT_ID, Region: $CURRENT_REGION"

# フロントエンドディレクトリの確認
FRONTEND_DIR="../${DEPLOY_FRONTEND_DIR:-frontend}"
if [ ! -d "$FRONTEND_DIR" ]; then
    log_error "フロントエンドディレクトリ（$FRONTEND_DIR）が見つかりません。"
    exit 1
fi

log_header "フロントエンドの準備をしています..."

# フロントエンドディレクトリに移動
cd "$FRONTEND_DIR"

# node_modulesがなければインストール
if [ ! -d "node_modules" ]; then
    log_info "フロントエンドの依存関係をインストールしています..."
    npm install
fi

# SSMからCognito情報を取得
log_info "SSM Parameter StoreからCognito情報を取得しています..."
SSM_PREFIX="/copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}"

COGNITO_CLIENT_ID=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/client-id" \
    --query 'Parameter.Value' \
    --output text \
    --region $CURRENT_REGION 2>/dev/null)

COGNITO_ISSUER=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/issuer-url" \
    --query 'Parameter.Value' \
    --output text \
    --region $CURRENT_REGION 2>/dev/null)

if [ -z "$COGNITO_CLIENT_ID" ] || [ -z "$COGNITO_ISSUER" ]; then
    log_error "SSMからCognito情報の取得に失敗しました"
    log_info "Cognitoスタックが先にデプロイされているか確認してください："
    log_info "  NODE_ENV=${ENV_NAME} ./scripts/deploy-cognito.sh"
    exit 1
fi

log_success "Cognito情報を取得しました"
echo "  Client ID: $COGNITO_CLIENT_ID"
echo "  Issuer: $COGNITO_ISSUER"

# デプロイ用の.env.productionを一時生成
log_info "CDKデプロイ用の.env.productionを生成しています..."
cat > .env.production << EOF
AUTH_COGNITO_ID=${COGNITO_CLIENT_ID}
AUTH_COGNITO_ISSUER=${COGNITO_ISSUER}
AUTH_SECRET=${AUTH_SECRET}
AWS_REGION=${CURRENT_REGION}
NODE_ENV=production
DEBUG_MODE=true
AUTH_TRUST_HOST=true
EOF

log_success ".env.productionを生成しました（CDKが内部ビルド時に使用）"

# デバッグ用：生成された.env.productionの内容を表示
log_info ".env.productionの内容:"
echo "----------------------------------------"
cat .env.production
echo "----------------------------------------"

# クリーンアップ関数（エラー時も確実に実行）
cleanup() {
    log_info ".env.productionをクリーンアップしています..."
    rm -f "$FRONTEND_DIR/.env.production"
    log_success "クリーンアップ完了"
}
trap cleanup EXIT

# infrastructureディレクトリに戻る
cd "$PROJECT_DIR"

# CDKプロジェクトのビルド
log_header "CDKプロジェクトをビルドしています..."
npm run build

# Next.jsスタックのデプロイ
log_header "Next.jsスタックをデプロイしています..."
log_info "これには数分かかる場合があります..."

DEPLOY_LOG="/tmp/cdk-deploy-$(date +%s).log"

if npx cdk deploy CopilotKitNextjsStack --require-approval never 2>&1 | tee "$DEPLOY_LOG"; then
    log_success "Next.jsスタックのデプロイが完了しました！"
else
    log_error "Next.jsスタックのデプロイに失敗しました。"
    log_info "詳細なログは $DEPLOY_LOG を確認してください。"
    exit 1
fi

# デプロイ結果の抽出と表示
echo
log_header "===== デプロイ結果 ====="

NEXTJS_URL=$(grep "NextjsUrl" "$DEPLOY_LOG" | tail -1 | sed 's/.*= //' || echo "")
if [ -n "$NEXTJS_URL" ]; then
    log_success "Next.js Application URL: $NEXTJS_URL"
    echo
    log_success "フロントエンドにアクセス可能です:"
    echo "   ${BOLD}$NEXTJS_URL${NC}"
else
    log_warn "Next.js URLの抽出に失敗しました。AWS コンソールで確認してください。"
fi

# ログファイルのクリーンアップ
rm -f "$DEPLOY_LOG"

echo
log_success "============================================"
log_success "フロントエンドデプロイが正常に完了しました！"
log_success "============================================"
