#!/bin/bash

# 色付きログ出力用の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# デフォルト設定
CONFIG_FILE="default_config.yaml"
LANGFUSE_DIR="langfuse"
USE_NGINX=false
USE_CODE_SERVER=false

# ログ出力関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 環境変数の読み込み
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
            
            # 変数展開を処理
            eval "value=$value"
            
            # 環境変数としてエクスポート
            export "$key=$value"
        done < "$env_file"
    else
        log_warn "$env_file ファイルが見つかりません"
    fi
}

# Langfuse のセットアップ
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

# Nginxサービスの起動
start_nginx() {
    if [ "$USE_NGINX" = true ]; then
        log_info "Nginxを起動しています..."
        
        # 環境変数の設定
        export USE_CODE_SERVER="$USE_CODE_SERVER"
        
        if [ -f ".env" ]; then
            log_info "Nginx の .env ファイルを使用します"
            docker compose -f nginx-compose.yml --env-file .env up -d
        else
            log_info "環境変数ファイルなしで起動します"
            docker compose -f nginx-compose.yml up -d
        fi
        
        if [ $? -ne 0 ]; then
            log_error "Nginx の起動に失敗しました"
            exit 1
        fi
    fi
}

# Nginxサービスの停止
stop_nginx() {
    if [ "$USE_NGINX" = true ]; then
        log_info "Nginxを停止しています..."
        docker stop nginx-proxy >/dev/null 2>&1 || true
        docker rm nginx-proxy >/dev/null 2>&1 || true
    fi
}

# サービスの起動
start_services() {
    log_info "サービスを起動しています..."
    
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
        docker compose --env-file .env --env-file ../.env up -d
    elif [ -f ".env" ]; then
        log_info "Langfuse の .env ファイルを使用します"
        docker compose --env-file .env up -d
    elif [ -f "../.env" ]; then
        log_info "親ディレクトリの .env ファイルを使用します"
        docker compose --env-file ../.env up -d
    else
        log_info "環境変数ファイルなしで起動します"
        docker compose up -d
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Langfuse の起動に失敗しました"
        cd ..
        exit 1
    fi
    cd ..
    
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
    
    log_info "全てのサービスが起動しました"
    
    # Nginxの起動（オプション）
    start_nginx
}

# サービスの停止
stop_services() {
    log_info "サービスを停止しています..."
    
    # LiteLLMサービスを停止
    log_info "LiteLLMサービスを停止しています..."
    docker compose -f docker-compose.yml down
    
    # Langfuseサービスを停止
    if [ -d "$LANGFUSE_DIR" ]; then
        log_info "Langfuseサービスを停止しています..."
        cd "$LANGFUSE_DIR"
        docker compose down
        cd ..
    fi
    
    # Nginxの停止（オプション）
    stop_nginx
    
    log_info "全てのサービスが停止しました"
}

# ヘルプメッセージの表示
show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start    - サービスを起動"
    echo "  stop     - サービスを停止"
    echo "  restart  - サービスを再起動"
    echo
    echo "Options:"
    echo "  -c, --config FILE  - LiteLLM の設定ファイルを指定 (デフォルト: default_config.yaml)"
    echo "  -n, --nginx       - Nginxリバースプロキシを使用"
    echo "  --code-server    - Code Server用のプロキシ設定を有効化（--nginxと共に使用）"
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
        start|stop|restart|start-nginx|stop-nginx)
            COMMAND="$1"
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift
            ;;
        -n|--nginx)
            USE_NGINX=true
            ;;
        --code-server)
            USE_CODE_SERVER=true
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

# コマンドが指定されていない場合
if [ -z "$COMMAND" ]; then
    log_error "コマンドが指定されていません"
    show_help
    exit 1
fi

# 設定ファイルの存在確認
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "設定ファイル $CONFIG_FILE が見つかりません"
    exit 1
fi

# コマンドの実行
case "$COMMAND" in
    start)
        setup_langfuse
        start_services
        ;;
    start-nginx)
        start_nginx
        ;;
    stop)
        stop_services
        ;;
    stop-nginx)
        stop_nginx
        ;;
    restart)
        stop_services
        setup_langfuse
        start_services
        ;;
esac
