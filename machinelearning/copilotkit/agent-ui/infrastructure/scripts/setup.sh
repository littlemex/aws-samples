#!/bin/bash

# CopilotKit Agent UI - 初回セットアップスクリプト
# 
# このスクリプトは以下を行います：
# 1. .env.exampleをベースに.env.{環境名}ファイルを作成
# 2. NEXTAUTH_SECRETの自動生成
# 3. AWSアカウント/リージョンの自動検出
# 4. 必要な設定の入力受付
# 5. CDKブートストラップの実行

set -e  # エラー時に停止

# 色付きログ用の定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}$1${NC}"
}

# 使用方法表示
usage() {
    echo "使用方法: NODE_ENV=<環境名> $0"
    echo ""
    echo "環境変数:"
    echo "  NODE_ENV    環境名を指定（オプション、デフォルト: production）"
    echo "              a-zのみ、最大10文字"
    echo ""
    echo "例:"
    echo "  NODE_ENV=local $0       # .env.local を生成"
    echo "  NODE_ENV=production $0  # .env.production を生成"
    echo "  NODE_ENV=dev $0         # .env.dev を生成"
    echo "  $0                      # .env.production を生成（デフォルト）"
    echo ""
    exit 1
}

# 引数チェック（--helpのみ対応）
for arg in "$@"; do
    case $arg in
        --help)
            usage
            ;;
        *)
            if [ -n "$1" ]; then
                echo "不明な引数: $arg"
                echo "環境名は NODE_ENV 環境変数で指定してください。"
                usage
            fi
            ;;
    esac
done

# NODE_ENVから環境名を取得（デフォルト: production）
ENV_NAME="${NODE_ENV:-production}"

# 環境名のバリデーション（a-zのみ、最大10文字）
if ! [[ "$ENV_NAME" =~ ^[a-z]{1,10}$ ]]; then
    log_error "環境名は小文字アルファベット(a-z)のみで、最大10文字である必要があります。"
    log_error "指定された環境名: $ENV_NAME"
    exit 1
fi

echo "======================================"
echo "CopilotKit Agent UI - 初回セットアップ"
echo "======================================"

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

log_info "プロジェクトディレクトリ: $PROJECT_DIR"
log_info "環境名: $ENV_NAME"

ENV_FILE=".env.${ENV_NAME}"
log_info "作成するファイル: $ENV_FILE"

# .env.exampleの存在確認
if [ ! -f ".env.example" ]; then
    log_error ".env.exampleファイルが見つかりません。"
    exit 1
fi

# .envファイルが既に存在するかチェック
if [ -f "$ENV_FILE" ]; then
    log_warn "$ENV_FILE ファイルが既に存在します。"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "セットアップをキャンセルしました。"
        exit 0
    fi
fi

log_info "必要なコマンドをチェックしています..."

# 必要なコマンドの存在確認
for cmd in openssl node npm; do
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

echo ""
log_header "===== 環境設定 ====="

# AUTH_SECRETの生成（NextAuth v5）
log_info "AUTH_SECRETを生成しています..."
AUTH_SECRET=$(openssl rand -base64 32)
log_success "AUTH_SECRETを生成しました。"

# ユーザー入力：COGNITO_CLIENT_SUFFIX
echo ""
log_info "Cognito Client Suffix を指定してください。"
echo "  - これはSSMパラメータのパスと環境識別に使用されます"
echo "  - 例: 'copilotkit', 'frontend', 'production' など"
read -p "COGNITO_CLIENT_SUFFIX [${ENV_NAME}]: " INPUT_CLIENT_SUFFIX
COGNITO_CLIENT_SUFFIX="${INPUT_CLIENT_SUFFIX:-${ENV_NAME}}"

# ユーザー入力：DEPLOY_FRONTEND_DIR
echo ""
log_info "デプロイするフロントエンドディレクトリを指定してください。"
echo "  - frontend: 基本フロントエンド"
echo "  - frontend-copilotkit: CopilotKit統合版"
read -p "DEPLOY_FRONTEND_DIR [frontend-copilotkit]: " INPUT_FRONTEND_DIR
DEPLOY_FRONTEND_DIR="${INPUT_FRONTEND_DIR:-frontend-copilotkit}"

# ユーザー入力：DEBUG_MODE
echo ""
log_info "デバッグモードを有効にしますか？"
read -p "DEBUG_MODE [false]: " INPUT_DEBUG
DEBUG_MODE="${INPUT_DEBUG:-false}"

echo ""
log_header "===== 設定内容の確認 ====="
echo "  環境ファイル: $ENV_FILE"
echo "  AWS Account: $ACCOUNT_ID"
echo "  AWS Region: $CURRENT_REGION"
echo "  ENVIRONMENT: $ENV_NAME"
echo "  COGNITO_CLIENT_SUFFIX: $COGNITO_CLIENT_SUFFIX"
echo "  DEPLOY_FRONTEND_DIR: $DEPLOY_FRONTEND_DIR"
echo "  DEBUG_MODE: $DEBUG_MODE"
echo ""

# .env.exampleをベースに環境ファイルを作成
log_info ".env.exampleから${ENV_FILE}ファイルを作成しています..."
cp .env.example "$ENV_FILE"

# 値を置換（sedの区切り文字を|に変更して特殊文字に対応）
sed -i "s|^AUTH_SECRET=.*|AUTH_SECRET=${AUTH_SECRET}|" "$ENV_FILE"
sed -i "s|^AWS_REGION=.*|AWS_REGION=${CURRENT_REGION}|" "$ENV_FILE"
sed -i "s|^CDK_DEFAULT_REGION=.*|CDK_DEFAULT_REGION=${CURRENT_REGION}|" "$ENV_FILE"
sed -i "s|^COGNITO_CLIENT_SUFFIX=.*|COGNITO_CLIENT_SUFFIX=${COGNITO_CLIENT_SUFFIX}|" "$ENV_FILE"
sed -i "s|^DEPLOY_FRONTEND_DIR=.*|DEPLOY_FRONTEND_DIR=${DEPLOY_FRONTEND_DIR}|" "$ENV_FILE"
sed -i "s|^ENVIRONMENT=.*|ENVIRONMENT=${ENV_NAME}|" "$ENV_FILE"
sed -i "s|^NODE_ENV=.*|NODE_ENV=${ENV_NAME}|" "$ENV_FILE"
sed -i "s|^DEBUG_MODE=.*|DEBUG_MODE=${DEBUG_MODE}|" "$ENV_FILE"

# CDK_DEFAULT_ACCOUNTを追加（.env.exampleにはないため）
echo "" >> "$ENV_FILE"
echo "# AWS Account (auto-detected)" >> "$ENV_FILE"
echo "CDK_DEFAULT_ACCOUNT=${ACCOUNT_ID}" >> "$ENV_FILE"

log_success "${ENV_FILE}ファイルを作成しました。"

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
FRONTEND_PATH="../${DEPLOY_FRONTEND_DIR}"
if [ -d "$FRONTEND_PATH" ]; then
    log_info "フロントエンド（$FRONTEND_PATH）の依存関係をチェックしています..."
    if [ ! -d "$FRONTEND_PATH/node_modules" ]; then
        log_info "フロントエンドの依存関係をインストールしています..."
        (cd "$FRONTEND_PATH" && npm install)
        log_success "フロントエンドの依存関係をインストールしました。"
    else
        log_success "フロントエンドの依存関係は既にインストール済みです。"
    fi
else
    log_warn "フロントエンドディレクトリが見つかりません: $FRONTEND_PATH"
fi

echo ""
log_success "============================================"
log_success "セットアップが完了しました！"
log_success "============================================"
echo ""
log_header "次のステップ："
echo "  1. デプロイを実行:"
echo "     NODE_ENV=${ENV_NAME} ./scripts/deploy-frontend.sh"
echo "  2. または手動デプロイ:"
echo "     NODE_ENV=${ENV_NAME} npm run deploy"
echo ""
log_header "作成されたファイル："
echo "  - ${ENV_FILE} (Gitにコミットしないでください)"
echo ""
log_header "設定値："
echo "  - ENVIRONMENT: $ENV_NAME"
echo "  - COGNITO_CLIENT_SUFFIX: $COGNITO_CLIENT_SUFFIX"
echo "  - DEPLOY_FRONTEND_DIR: $DEPLOY_FRONTEND_DIR"
echo "  - SSM Parameter Prefix: /copilotkit-agentcore/${COGNITO_CLIENT_SUFFIX}"
echo ""
log_info "ヒント："
echo "  - config.tsは環境に応じて.env.${ENV_NAME}を自動で読み込みます"
echo "  - 別の環境を作成する場合:"
echo "    NODE_ENV=staging ./scripts/setup.sh"
echo ""
