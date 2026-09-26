#!/bin/bash

# CopilotKit Agent UI - スタック削除スクリプト
# 
# このスクリプトは以下を行います：
# 1. .envファイルの読み込み
# 2. AWS認証情報の確認
# 3. CDKスタックの削除
# 4. 削除確認

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

echo "===================================="
echo "CopilotKit Agent UI - スタック削除"
echo "===================================="

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

log_info "プロジェクトディレクトリ: $PROJECT_DIR"

# .envファイルの確認と読み込み
if [ -f ".env" ]; then
    log_info ".envファイルを読み込んでいます..."
    source .env
fi

# AWS認証情報の確認
log_info "AWS認証情報を確認しています..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証情報が設定されていません。"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_REGION=$(aws configure get region || echo "${AWS_REGION:-us-east-1}")
log_success "AWS認証成功 - Account: $ACCOUNT_ID, Region: $CURRENT_REGION"

# 削除対象のスタック一覧
STACKS=("CopilotKitFrontendStack" "CopilotKitCognitoStack")

echo
log_header "削除対象のスタック:"
for stack in "${STACKS[@]}"; do
    echo "  - $stack"
done

echo
log_warn "警告: この操作により以下のリソースが削除されます:"
echo "  - Lambda関数"
echo "  - API Gateway"
echo "  - CloudFront Distribution"
echo "  - S3バケット（静的アセット）"
echo "  - 関連するIAMロール・ポリシー"
echo
log_info "注意: Cognito User PoolとUser Pool Clientは削除されません（既存リソースのため）"

echo
read -p "本当にスタックを削除しますか？ (yes/NO): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "スタック削除をキャンセルしました。"
    exit 0
fi

echo
log_warn "最終確認: 削除を実行すると元に戻せません。"
read -p "削除を続行しますか？ (yes/NO): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "スタック削除をキャンセルしました。"
    exit 0
fi

# CDKスタックの削除
log_header "CDKスタックを削除しています..."
log_info "これには数分かかる場合があります..."

# 削除ログを一時ファイルに保存
DESTROY_LOG="/tmp/cdk-destroy-$(date +%s).log"

if npm run destroy 2>&1 | tee "$DESTROY_LOG"; then
    log_success "CDKスタックの削除が完了しました！"
else
    log_error "CDKスタックの削除に失敗しました。"
    log_info "詳細なログは $DESTROY_LOG を確認してください。"
    echo
    log_info "手動削除が必要な場合："
    echo "1. AWS CloudFormationコンソールでスタックを確認"
    echo "2. 削除に失敗したリソースを手動で削除"
    echo "3. スタックの削除を再実行"
    exit 1
fi

echo
log_header "===== 削除結果 ====="

# 削除されたスタックの確認
log_info "削除されたスタック:"
for stack in "${STACKS[@]}"; do
    if ! aws cloudformation describe-stacks --stack-name "$stack" --region "$CURRENT_REGION" &> /dev/null; then
        log_success "  ✓ $stack"
    else
        log_warn "  ⚠ $stack (削除に失敗した可能性があります)"
    fi
done

echo
log_header "===== 次のステップ ====="

log_info "削除後の確認事項:"
echo "1. AWS CloudFormationコンソールでスタックが削除されているか確認"
echo "2. S3バケットが空になっているか確認（必要に応じて手動削除）"
echo "3. CloudWatchロググループが削除されているか確認"

echo
log_info "再デプロイする場合:"
echo "  ./scripts/deploy.sh"

# ログファイルのクリーンアップ
rm -f "$DESTROY_LOG"

echo
log_success "================================="
log_success "スタック削除が正常に完了しました！"
log_success "================================="
