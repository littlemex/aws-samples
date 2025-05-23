#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_FILE="iam_role_config.yml"
ENV_FILE=".env"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

start_services() {
    log_info "LiteLLM サービスを起動しています..."
    
    # 環境変数オプションを構築
    local cmd="docker compose"
    if [ -f "$ENV_FILE" ]; then
        log_info "環境変数ファイルを使用します: $ENV_FILE"
        cmd="$cmd --env-file $ENV_FILE"
    else
        log_warn "環境変数ファイルが見つかりません: $ENV_FILE"
    fi
    
    cmd="$cmd -f docker-compose.yml up -d"
    log_info "実行コマンド: $cmd"
    eval "$cmd"
    
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
    echo "  start         - サービスを起動"
    echo "  stop          - サービスを停止"
    echo "  restart       - サービスを再起動"
    echo
    echo "Options:"
    echo "  -c, --config FILE   - 設定ファイルを指定 (デフォルト: iam_role_config.yml)"
    echo "                        利用可能な設定ファイル:"
    echo "                        - iam_role_config.yml: IAMロール認証用（EC2推奨）"
    echo "                        - access_key_config.yml: アクセスキー認証用"
    echo "                        - prompt_caching.yml: プロンプトキャッシング有効化用"
    echo "  -e, --env-file FILE - 環境変数ファイルを指定 (デフォルト: .env)"
    echo "                        必要な環境変数:"
    echo "                        - LITELLM_MASTER_KEY: LiteLLM Proxyアクセス用キー"
    echo "                        - LITELLM_UI_USERNAME: 管理画面アクセス用ユーザー名"
    echo "                        - LITELLM_UI_PASSWORD: 管理画面アクセス用パスワード"
    echo "  -h, --help          - このヘルプメッセージを表示"
    echo
    echo "Examples:"
    echo "  $0 start                           # デフォルト設定で起動"
    echo "  $0 start -c prompt_caching.yml     # プロンプトキャッシング有効で起動"
    echo "  $0 start -e custom.env            # カスタム環境変数で起動"
    echo "  $0 restart -c access_key_config.yml # アクセスキー認証で再起動"
}

# メイン処理
COMMAND=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart)
            COMMAND="$1"
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift
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
    *)
        log_error "不明なコマンド: $COMMAND"
        show_help
        exit 1
        ;;
esac
