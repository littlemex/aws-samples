#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LANGFUSE_DIR="langfuse"
LITELLM_DIR="../2.litellm"
CONFIG_FILE="default_config.yml"
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

setup_langfuse() {
    if [ ! -d "$LANGFUSE_DIR" ]; then
        log_info "Langfuse リポジトリをクローンしています..."
        # 安定バージョンを指定してクローン
        LANGFUSE_VERSION="v3.49.1"
        log_info "Langfuse バージョン $LANGFUSE_VERSION を使用します"
        git -c advice.detachedHead=false clone -b $LANGFUSE_VERSION --single-branch --depth=1 https://github.com/langfuse/langfuse.git
        if [ $? -ne 0 ]; then
            log_error "Langfuse リポジトリのクローンに失敗しました"
            exit 1
        fi
    fi
}

update_litellm_env() {
    local env_file="$LITELLM_DIR/.env"
    log_info "LiteLLM の環境変数を更新しています..."
    
    # .envファイルが存在しない場合は作成
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
    fi
    
    # 既存のLangfuse設定を削除（通常のLangfuse設定とUPSTREAM設定の両方）
    sed -i '/^# Langfuse Configuration/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_HOST=/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_PUBLIC_KEY=/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_SECRET_KEY=/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_DEBUG=/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_FLUSH_INTERVAL=/d' "$env_file" 2>/dev/null
    sed -i '/^LANGFUSE_RELEASE=/d' "$env_file" 2>/dev/null
    
    # UPSTREAM設定も削除
    sed -i '/^UPSTREAM_LANGFUSE_HOST=/d' "$env_file" 2>/dev/null
    sed -i '/^UPSTREAM_LANGFUSE_PUBLIC_KEY=/d' "$env_file" 2>/dev/null
    sed -i '/^UPSTREAM_LANGFUSE_SECRET_KEY=/d' "$env_file" 2>/dev/null
    sed -i '/^UPSTREAM_LANGFUSE_DEBUG=/d' "$env_file" 2>/dev/null
    sed -i '/^UPSTREAM_LANGFUSE_RELEASE=/d' "$env_file" 2>/dev/null
    
    # 新しいLangfuse設定を追加
    log_info "Langfuse の設定を更新しています..."
    {
        echo "# Langfuse Configuration"
        # host.docker.internalを使用してLangfuseにアクセス
        echo "LANGFUSE_HOST=$LANGFUSE_HOST"
        echo "LANGFUSE_PUBLIC_KEY=$LANGFUSE_PUBLIC_KEY"
        echo "LANGFUSE_SECRET_KEY=$LANGFUSE_SECRET_KEY"
        
        # オプションの設定があれば追加
        if [ ! -z "$LANGFUSE_DEBUG" ]; then
            echo "LANGFUSE_DEBUG=$LANGFUSE_DEBUG"
        fi
        if [ ! -z "$LANGFUSE_FLUSH_INTERVAL" ]; then
            echo "LANGFUSE_FLUSH_INTERVAL=$LANGFUSE_FLUSH_INTERVAL"
        fi
        if [ ! -z "$LANGFUSE_RELEASE" ]; then
            echo "LANGFUSE_RELEASE=$LANGFUSE_RELEASE"
        fi
        
        # UPSTREAM設定があれば追加
        if [ ! -z "$UPSTREAM_LANGFUSE_HOST" ]; then
            echo "UPSTREAM_LANGFUSE_HOST=$UPSTREAM_LANGFUSE_HOST"
        fi
        if [ ! -z "$UPSTREAM_LANGFUSE_PUBLIC_KEY" ]; then
            echo "UPSTREAM_LANGFUSE_PUBLIC_KEY=$UPSTREAM_LANGFUSE_PUBLIC_KEY"
        fi
        if [ ! -z "$UPSTREAM_LANGFUSE_SECRET_KEY" ]; then
            echo "UPSTREAM_LANGFUSE_SECRET_KEY=$UPSTREAM_LANGFUSE_SECRET_KEY"
        fi
        if [ ! -z "$UPSTREAM_LANGFUSE_DEBUG" ]; then
            echo "UPSTREAM_LANGFUSE_DEBUG=$UPSTREAM_LANGFUSE_DEBUG"
        fi
        if [ ! -z "$UPSTREAM_LANGFUSE_RELEASE" ]; then
            echo "UPSTREAM_LANGFUSE_RELEASE=$UPSTREAM_LANGFUSE_RELEASE"
        fi
    } >> "$env_file"
}

update_litellm_config() {
    log_info "LiteLLM の設定を更新しています..."
    
    if [ ! -d "$LITELLM_DIR" ]; then
        log_error "LiteLLM ディレクトリが見つかりません: $LITELLM_DIR"
        exit 1
    fi
    
    # 環境変数を更新
    update_litellm_env
    
    cd "$LITELLM_DIR"
    ./manage-litellm.sh stop
    log_info "LiteLLM を Langfuse 設定で起動しています..."
    log_info "設定ファイル: ../4.langfuse/$CONFIG_FILE を使用します"
    ./manage-litellm.sh -c "../4.langfuse/$CONFIG_FILE" start
    
    # LiteLLMコンテナをLangfuseのネットワークに追加
    log_info "LiteLLM を Langfuse のネットワークに追加しています..."
    docker network connect langfuse_default 2litellm-litellm-1 || true
    docker network connect langfuse_default 2litellm-postgres-1 || true
    cd - > /dev/null
    
    log_info "LiteLLM の設定を更新しました"
}

start_langfuse() {
    log_info "Langfuse を起動しています..."
    
    cd "$LANGFUSE_DIR"
    log_info "Langfuse の環境設定をコピーしています..."
    if [ ! -f ".env" ]; then
        cp .env.dev.example .env
    fi
    
    log_info "Langfuse を起動しています..."
    if [ -f ".env" ] && [ -f "../.env" ]; then
        log_info "両方の .env ファイルを使用します"
        docker compose --env-file .env --env-file ../.env -f docker-compose.yml up -d --build
    elif [ -f ".env" ]; then
        log_info "Langfuse の .env ファイルを使用します"
        docker compose --env-file .env -f docker-compose.yml up -d --build
    elif [ -f "../.env" ]; then
        log_info "親ディレクトリの .env ファイルを使用します"
        docker compose --env-file ../.env -f docker-compose.yml up -d --build
    else
        log_info "環境変数ファイルなしで起動します"
        docker compose -f docker-compose.yml up -d --build
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
    log_info "Langfuse を停止しています..."
    
    if [ -d "$LANGFUSE_DIR" ]; then
        cd "$LANGFUSE_DIR"
        docker compose down
        cd ..
    fi
    
    log_info "Langfuse が停止しました"
}

show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start           - Langfuse を起動"
    echo "  stop            - Langfuse を停止"
    echo "  restart         - Langfuse を再起動"
    echo "  update-config   - LiteLLM の設定を更新"
    echo
    echo "Options:"
    echo "  -c, --config FILE - 設定ファイルを指定 (デフォルト: $CONFIG_FILE)"
    echo "  -h, --help     - このヘルプメッセージを表示"
}

# 環境変数を最初に読み込む
log_info "環境変数を読み込んでいます..."
load_env_vars "$ENV_FILE"

# メイン処理
COMMAND=""

# コマンドライン引数の処理
while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart|update-config)
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

case "$COMMAND" in
    start)
        setup_langfuse
        start_langfuse
        ;;
    stop)
        stop_langfuse
        ;;
    restart)
        stop_langfuse
        start_langfuse
        ;;
    update-config)
        update_litellm_config
        ;;
esac
