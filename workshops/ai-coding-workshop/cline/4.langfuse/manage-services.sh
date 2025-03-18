#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_FILE="default_config.yaml"
LANGFUSE_DIR="langfuse"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

load_env_vars() {
    local env_file="${1:-.env}"
    
    if [ -f "$env_file" ]; then
        log_info "環境変数を $env_file から読み込んでいます..."
        # .env ファイルから環境変数を読み込み、エクスポート
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # コメントと空行をスキップ
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            
            # 値から引用符を削除
            value=$(echo "$value" | sed -e 's/^["\x27]//' -e 's/["\x27]$//')
            
            # 特殊文字や URL を含む場合は直接使用、それ以外は変数展開を処理
            if [[ "$value" == *"{"* ]] || [[ "$value" == *"}"* ]] || [[ "$value" == "http://"* ]] || [[ "$value" == "https://"* ]]; then
                # 特殊文字や URL を含む場合は直接使用
                export "$key=$value"
            else
                # 変数展開を含む場合のみ eval を使用
                if [[ "$value" == *'$'* ]] || [[ "$value" == *'`'* ]]; then
                    eval "value=$value"
                fi
                export "$key=$value"
            fi
        done < "$env_file"
    else
        log_warn "$env_file ファイルが見つかりません"
    fi
}

setup_langfuse() {
    if [ ! -d "$LANGFUSE_DIR" ]; then
        log_info "Langfuse リポジトリをクローンしています..."
        git clone https://github.com/langfuse/langfuse.git
        if [ $? -ne 0 ]; then
            log_error "Langfuse リポジトリのクローンに失敗しました"
            exit 1
        fi
    fi
}

start_langfuse() {
    log_info "Langfuse のみを起動しています..."
    
    # Langfuse の起動
    cd "$LANGFUSE_DIR"
    log_info "Langfuse の環境設定をコピーしています..."
    if [ ! -f ".env" ]; then
        cp .env.dev.example .env
    fi
    
    log_info "Langfuse を起動しています..."
    # 環境変数ファイルを指定して起動
    if [ -f ".env" ] && [ -f "../.env" ]; then
        log_info "両方の .env ファイルを使用します"
        docker compose --env-file .env --env-file ../.env -f docker-compose.yml -f ../docker-compose.override.yml up -d --build
    elif [ -f ".env" ]; then
        log_info "Langfuse の .env ファイルを使用します"
        docker compose --env-file .env -f docker-compose.yml -f ../docker-compose.override.yml up -d --build
    elif [ -f "../.env" ]; then
        log_info "親ディレクトリの .env ファイルを使用します"
        docker compose --env-file ../.env -f docker-compose.yml -f ../docker-compose.override.yml up -d --build
    else
        log_info "環境変数ファイルなしで起動します"
        docker compose -f docker-compose.yml -f ../docker-compose.override.yml up -d --build
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Langfuse の起動に失敗しました"
        cd ..
        exit 1
    fi
    cd ..
    
    log_info "Langfuse が起動しました"
}

stop_langfuse() {
    log_info "Langfuse のみを停止しています..."
    
    # Langfuseサービスを停止
    if [ -d "$LANGFUSE_DIR" ]; then
        log_info "Langfuseサービスを停止しています..."
        cd "$LANGFUSE_DIR"
        docker compose down
        cd ..
    fi
    
    log_info "Langfuse が停止しました"
}

start_litellm() {
    log_info "LiteLLM のみを起動しています..."
    
    # LiteLLM の設定を適用
    log_info "LiteLLM の設定を適用しています..."
    export CONFIG_FILE
    
    if [ -f ".env" ]; then
        log_info "LiteLLM の .env ファイルを使用します"
        docker compose --env-file .env -f docker-compose.yml up -d
    else
        log_info "環境変数ファイルなしで起動します"
        docker compose -f docker-compose.yml up -d
    fi
    
    if [ $? -ne 0 ]; then
        log_error "LiteLLM の起動に失敗しました"
        exit 1
    fi
    
    log_info "LiteLLM が起動しました"
}

stop_litellm() {
    log_info "LiteLLMサービスを停止しています..."
    docker compose -f docker-compose.yml down
    
    log_info "LiteLLM が停止しました"
}

start_services() {
    log_info "全てのサービスを起動しています..."
    start_langfuse
    start_litellm
    log_info "全てのサービスが起動しました"
}

stop_services() {
    log_info "全てのサービスを停止しています..."
    stop_litellm
    stop_langfuse
    log_info "全てのサービスが停止しました"
}

show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start           - 全てのサービスを起動"
    echo "  stop            - 全てのサービスを停止"
    echo "  restart         - 全てのサービスを再起動"
    echo "  start-langfuse  - Langfuse のみを起動"
    echo "  stop-langfuse   - Langfuse のみを停止"
    echo "  restart-langfuse - Langfuse のみを再起動"
    echo "  start-litellm   - LiteLLM のみを起動"
    echo "  stop-litellm    - LiteLLM のみを停止"
    echo "  restart-litellm - LiteLLM のみを再起動"
    echo
    echo "Options:"
    echo "  -c, --config FILE  - LiteLLM の設定ファイルを指定 (デフォルト: default_config.yaml)"
    echo "  -h, --help        - このヘルプメッセージを表示"
}

# 環境変数を最初に読み込む
log_info "環境変数を読み込んでいます..."
load_env_vars

# メイン処理
COMMAND=""

# コマンドライン引数の処理
while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart|start-langfuse|stop-langfuse|restart-langfuse|start-litellm|stop-litellm|restart-litellm)
            COMMAND="$1"
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "不明なパラメータ: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

if [ -z "$COMMAND" ]; then
    log_error "コマンドが指定されていません"
    show_help
    exit 1
fi

if [[ "$COMMAND" == *"litellm"* || "$COMMAND" == "start" || "$COMMAND" == "stop" || "$COMMAND" == "restart" ]] && [ ! -f "$CONFIG_FILE" ]; then
    log_error "設定ファイル $CONFIG_FILE が見つかりません"
    exit 1
fi

case "$COMMAND" in
    start)
        setup_langfuse
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        setup_langfuse
        start_services
        ;;
    start-langfuse)
        setup_langfuse
        start_langfuse
        ;;
    stop-langfuse)
        stop_langfuse
        ;;
    restart-langfuse)
        stop_langfuse
        setup_langfuse
        start_langfuse
        ;;
    start-litellm)
        start_litellm
        ;;
    stop-litellm)
        stop_litellm
        ;;
    restart-litellm)
        stop_litellm
        start_litellm
        ;;
esac
