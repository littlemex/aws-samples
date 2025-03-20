#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_langfuse_containers() {
    log_info "Langfuseコンテナの状態を確認中..."
    echo "=== Langfuse コンテナ一覧 ==="
    docker ps -a | grep langfuse
    echo
}

check_litellm_container() {
    log_info "LiteLLMコンテナの状態を確認中..."
    echo "=== LiteLLM コンテナ一覧 ==="
    docker ps -a | grep litellm
    echo
}

show_langfuse_logs() {
    log_info "Langfuseコンテナのログを表示中..."
    echo "=== Langfuse ログ ==="
    docker logs langfuse-langfuse-web-1 --tail 30
    echo
}

show_litellm_logs() {
    log_info "LiteLLMコンテナのログを表示中..."
    echo "=== LiteLLM ログ ==="
    docker logs 2litellm-litellm-1 --tail 40
    echo
}

check_env_vars() {
    log_info "環境変数を確認中..."
    echo "=== 環境変数 ==="
    echo "LANGFUSE_HOST: $LANGFUSE_HOST"
    echo "LANGFUSE_PUBLIC_KEY: ${LANGFUSE_PUBLIC_KEY:0:10}... (一部のみ表示)"
    echo "LANGFUSE_SECRET_KEY: ${LANGFUSE_SECRET_KEY:0:10}... (一部のみ表示)"
    echo "LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:0:10}... (一部のみ表示)"
    echo
}

# メイン処理
log_info "デバッグを開始します..."
echo

check_langfuse_containers
check_litellm_container
check_env_vars
show_langfuse_logs
show_litellm_logs

log_info "デバッグ完了"
