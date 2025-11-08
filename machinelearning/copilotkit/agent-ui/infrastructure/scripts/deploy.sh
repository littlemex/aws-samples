#!/bin/bash

# CopilotKit Agent UI - デプロイスクリプト
# 
# このスクリプトは以下を行います：
# 1. .envファイルの読み込み
# 2. 環境変数の確認
# 3. フロントエンドのビルド
# 4. CDKデプロイ
# 5. デプロイ結果の表示

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

echo "================================"
echo "CopilotKit Agent UI - デプロイ"
echo "================================"

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

log_info "プロジェクトディレクトリ: $PROJECT_DIR"

# .envファイルの確認と読み込み
if [ ! -f ".env" ]; then
    log_error ".envファイルが見つかりません。"
    log_info "初回セットアップを実行してください: ./scripts/setup.sh"
    exit 1
fi

log_info ".envファイルを読み込んでいます..."
source .env

# 必須環境変数のチェック
log_info "環境変数を確認しています..."
if [ -z "$NEXTAUTH_SECRET" ]; then
    log_error "NEXTAUTH_SECRETが設定されていません。"
    exit 1
fi

# COGNITO_CLIENT_SECRETは不要（Public Client設定）
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

# フロントエンドのビルド
FRONTEND_DIR="../frontend"
if [ -d "$FRONTEND_DIR" ]; then
    log_header "フロントエンドをビルドしています..."
    
    cd "$FRONTEND_DIR"
    
    # node_modulesがなければインストール
    if [ ! -d "node_modules" ]; then
        log_info "フロントエンドの依存関係をインストールしています..."
        npm install
    fi
    
    # 既存のビルドをクリーンアップ
    if [ -d ".next" ]; then
        log_info "既存のビルドをクリーンアップしています..."
        rm -rf .next
    fi
    
    # Next.jsアプリをビルド
    log_info "Next.jsアプリをビルドしています..."
    npm run build
    
    # standaloneビルドの確認
    if [ ! -d ".next/standalone" ]; then
        log_error "Next.js standaloneビルドに失敗しました。"
        log_info "next.config.tsに 'output: \"standalone\"' が設定されているか確認してください。"
        exit 1
    fi
    
    log_success "フロントエンドのビルドが完了しました。"
    cd "$PROJECT_DIR"
else
    log_warn "フロントエンドディレクトリ（$FRONTEND_DIR）が見つかりません。"
fi

# CDKプロジェクトのビルド
log_header "CDKプロジェクトをビルドしています..."
npm run build

# CDKデプロイ
log_header "CDKスタックをデプロイしています..."
log_info "これには数分かかる場合があります..."

# デプロイログを一時ファイルに保存
DEPLOY_LOG="/tmp/cdk-deploy-$(date +%s).log"

if npm run deploy 2>&1 | tee "$DEPLOY_LOG"; then
    log_success "CDKデプロイが完了しました！"
else
    log_error "CDKデプロイに失敗しました。"
    log_info "詳細なログは $DEPLOY_LOG を確認してください。"
    exit 1
fi

# デプロイ結果の抽出と表示
echo
log_header "===== デプロイ結果 ====="

# Next.js Application URLの抽出（cdk-nextjsによる新しいアーキテクチャ）
NEXTJS_URL=$(grep "NextjsUrl" "$DEPLOY_LOG" | tail -1 | sed 's/.*= //' || echo "")
if [ -n "$NEXTJS_URL" ]; then
    log_success "Next.js Application URL: $NEXTJS_URL"
else
    log_warn "Next.js URLの抽出に失敗しました。AWS コンソールで確認してください。"
fi

# NextAuth Callback URLの抽出
CALLBACK_URL=$(grep "NextAuthCallbackUrl" "$DEPLOY_LOG" | tail -1 | sed 's/.*= //' || echo "")
if [ -n "$CALLBACK_URL" ]; then
    log_info "NextAuth Callback URL: $CALLBACK_URL"
fi

# Cognito関連情報の抽出
USER_POOL_ID=$(grep "UserPoolId" "$DEPLOY_LOG" | tail -1 | sed 's/.*= //' || echo "")
if [ -n "$USER_POOL_ID" ]; then
    log_info "Cognito User Pool ID: $USER_POOL_ID"
fi

USER_POOL_CLIENT_ID=$(grep "UserPoolClientId" "$DEPLOY_LOG" | tail -1 | sed 's/.*= //' || echo "")
if [ -n "$USER_POOL_CLIENT_ID" ]; then
    log_info "Cognito User Pool Client ID: $USER_POOL_CLIENT_ID"
fi

echo
log_header "===== 次のステップ ====="

if [ -n "$NEXTJS_URL" ]; then
    echo
    log_warn "重要: Cognito User Pool Client の設定を更新してください"
    echo
    echo "1. AWS Cognitoコンソールを開く（User Pool IDとClient IDは上記の出力値を使用）"
    echo
    echo "2. 以下のURLを追加してください:"
    echo "   ${GREEN}Callback URLs:${NC}"
    if [ -n "$CALLBACK_URL" ]; then
        echo "     $CALLBACK_URL"
    else
        echo "     ${NEXTJS_URL}/api/auth/callback/cognito"
    fi
    echo
    echo "   ${GREEN}Sign-out URLs:${NC}"
    echo "     $NEXTJS_URL"
    echo
    echo "3. 変更を保存"
    echo
    log_success "設定完了後、フロントエンドにアクセスできます:"
    echo "   ${BOLD}$NEXTJS_URL${NC}"
fi

# Lambda Function URLとCloudFrontでのログ確認方法
echo
log_info "トラブルシューティング:"
echo "  CloudWatch ログ確認: AWS コンソールのCloudWatchで Lambda関数のログを確認"
echo "  cdk-nextjs アーキテクチャ: Lambda Function URL + CloudFront + IAM Auth"

# ログファイルのクリーンアップ
rm -f "$DEPLOY_LOG"

echo
log_success "==============================="
log_success "デプロイが正常に完了しました！"
log_success "==============================="
