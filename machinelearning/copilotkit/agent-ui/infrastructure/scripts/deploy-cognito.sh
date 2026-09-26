#!/bin/bash

# CopilotKit Agent UI - Cognitoスタックデプロイ
# 
# このスクリプトは以下を行います：
# 1. .envファイルの読み込み
# 2. 環境変数の確認
# 3. CognitoStackのデプロイ
# 4. SSM Parameter Storeへの保存

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

echo "========================================="
echo "CopilotKit Agent UI - Cognitoデプロイ"
echo "========================================="

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
    log_info "以下のいずれかを実行してください："
    log_info "  1. 初回セットアップ: ./scripts/setup.sh --env=${ENV_NAME}"
    log_info "  2. または .env ファイルを作成"
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

# CDKプロジェクトのビルド
log_header "CDKプロジェクトをビルドしています..."
npm run build

# Cognitoスタックのデプロイ
log_header "Cognitoスタックをデプロイしています..."
log_info "これには数分かかる場合があります..."

# DEPLOY_FRONTEND=falseでNextjsStackの作成を無効化
if DEPLOY_FRONTEND=false npx cdk deploy CopilotKitCognitoStack --require-approval never; then
    log_success "Cognitoスタックのデプロイが完了しました！"
else
    log_error "Cognitoスタックのデプロイに失敗しました。"
    exit 1
fi

echo
log_header "===== デプロイ完了 ====="
log_success "CognitoスタックがデプロイされSSM Parameter Storeに保存されました"
echo
log_info "SSM Parameter Store:"
echo "  /copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}/cognito/user-pool-id"
echo "  /copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}/cognito/client-id"
echo "  /copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}/cognito/issuer-url"
echo "  /copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}/cognito/domain"
echo
log_header "次のステップ:"
echo "  フロントエンドをデプロイ: NODE_ENV=${ENV_NAME} ./scripts/deploy-frontend.sh"
echo
