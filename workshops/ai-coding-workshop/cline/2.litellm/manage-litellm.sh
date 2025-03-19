#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_FILE="default_config.yml"

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
                export "$key=$value"
            else
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

start_services() {
    log_info "LiteLLM サービスを起動しています..."
    
    if [ -f ".env" ]; then
        log_info ".env ファイルを使用します"
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

stop_services() {
    log_info "LiteLLM サービスを停止しています..."
    docker compose -f docker-compose.yml down
    log_info "LiteLLM が停止しました"
}

show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start   - サービスを起動"
    echo "  stop    - サービスを停止"
    echo "  restart - サービスを再起動"
    echo
    echo "Options:"
    echo "  -c, --config FILE  - 設定ファイルを指定 (デフォルト: default_config.yml)"
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
        start|stop|restart)
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

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "設定ファイル $CONFIG_FILE が見つかりません"
    exit 1
fi

export CONFIG_FILE

case "$COMMAND" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
esac
