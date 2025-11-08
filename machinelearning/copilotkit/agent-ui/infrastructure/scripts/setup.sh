#!/bin/bash

# CopilotKit Agent UI - 初回セットアップスクリプト
# 
# このスクリプトは以下を行います：
# 1. NEXTAUTH_SECRETの自動生成
# 2. COGNITO_CLIENT_SECRETの入力
# 3. .envファイルの作成
# 4. AWS認証情報の確認
# 5. CDKブートストラップの実行

set -e  # エラー時に停止

# 色付きログ用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "======================================"
echo "CopilotKit Agent UI - 初回セットアップ"
echo "======================================"

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

log_info "プロジェクトディレクトリ: $PROJECT_DIR"

# .envファイルが既に存在するかチェック
if [ -f ".env" ]; then
    log_warn ".envファイルが既に存在します。"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "セットアップをキャンセルしました。"
        exit 0
    fi
fi

log_info "必要なコマンドをチェックしています..."

# 必要なコマンドの存在確認
for cmd in openssl aws node npm; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd コマンドが見つかりません。インストールしてください。"
        exit 1
    fi
done

log_success "必要なコマンドが揃っています。"

# AWS認証情報の確認
log_info "AWS認証情報を確認しています..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証情報が設定されていません。"
    log_info "以下のいずれかの方法でAWS認証を設定してください："
    echo "  1. aws configure"
    echo "  2. AWS_PROFILE環境変数の設定"
    echo "  3. IAMロール/インスタンスプロファイル"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_REGION=$(aws configure get region || echo "us-east-1")
log_success "AWS認証成功 - Account: $ACCOUNT_ID, Region: $CURRENT_REGION"

# NEXTAUTH_SECRETの生成
log_info "NEXTAUTH_SECRETを生成しています..."
NEXTAUTH_SECRET=$(openssl rand -base64 32)
log_success "NEXTAUTH_SECRETを生成しました。"

# Public Client設定のため、COGNITO_CLIENT_SECRETは不要
log_info "Cognito設定の確認..."
log_success "Public Client設定のため、Client Secretは不要です。"

# .envファイルの作成
log_info ".envファイルを作成しています..."
cat > .env << EOF
# CopilotKit Agent UI - 環境変数設定
# $(date)に自動生成

# NextAuth.js Secret (自動生成)
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}

# AWS Settings
AWS_REGION=${CURRENT_REGION}
CDK_DEFAULT_REGION=${CURRENT_REGION}
CDK_DEFAULT_ACCOUNT=${ACCOUNT_ID}

# Optional: AWS Profile
# AWS_PROFILE=default

# Note: COGNITO_CLIENT_SECRET は不要（Public Client設定のため）
EOF

log_success ".envファイルを作成しました。"

# 依存関係のインストール
log_info "npm依存関係をインストールしています..."
npm install

# CDKブートストラップの確認とセットアップ
log_info "CDKブートストラップを確認しています..."
if ! aws cloudformation describe-stacks --stack-name CDKToolkit --region "$CURRENT_REGION" &> /dev/null; then
    log_warn "CDKブートストラップが必要です。"
    read -p "CDKブートストラップを実行しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "CDKブートストラップを実行しています..."
        npx cdk bootstrap "aws://${ACCOUNT_ID}/${CURRENT_REGION}"
        log_success "CDKブートストラップが完了しました。"
    else
        log_warn "CDKブートストラップをスキップしました。後でデプロイ時に実行する必要があります。"
    fi
else
    log_success "CDKブートストラップは既に実行済みです。"
fi

# フロントエンド依存関係のチェック
FRONTEND_DIR="../frontend"
if [ -d "$FRONTEND_DIR" ]; then
    log_info "フロントエンド（$FRONTEND_DIR）の依存関係をチェックしています..."
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        log_info "フロントエンドの依存関係をインストールしています..."
        (cd "$FRONTEND_DIR" && npm install)
        log_success "フロントエンドの依存関係をインストールしました。"
    else
        log_success "フロントエンドの依存関係は既にインストール済みです。"
    fi
fi

echo
log_success "============================================"
log_success "セットアップが完了しました！"
log_success "============================================"
echo
log_info "次のステップ："
echo "  1. デプロイを実行: ./scripts/deploy.sh"
echo "  2. または手動デプロイ: npm run deploy"
echo
log_info "重要な情報："
echo "  - .envファイルが作成されました（Gitにはコミットされません）"
echo "  - NEXTAUTH_SECRET: 自動生成済み"
echo "  - COGNITO_CLIENT_SECRET: 入力済み"
echo "  - Account ID: $ACCOUNT_ID"
echo "  - Region: $CURRENT_REGION"
echo
log_warn "注意: デプロイ後にCognito User Pool ClientのCallback URLsの更新が必要です。"
