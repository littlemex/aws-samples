#!/bin/bash

# 色付きログ出力用の設定
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# デフォルト値の設定
USE_CODE_SERVER=${USE_CODE_SERVER:-"false"}
CODE_SERVER_HOST=${CODE_SERVER_HOST:-"code-server"}
CODE_SERVER_PORT=${CODE_SERVER_PORT:-"8080"}

# パスプレフィックスの設定
if [ "$USE_CODE_SERVER" = "true" ]; then
    # Code Serverを使用する場合はプロキシパスを設定
    export LANGFUSE_PATH_PREFIX="/proxy/3000"
    export ROOT_LOCATION="proxy_pass http://$CODE_SERVER_HOST:$CODE_SERVER_PORT;"
else
    # Code Serverを使用しない場合は直接アクセス
    export LANGFUSE_PATH_PREFIX=""
    export ROOT_LOCATION="proxy_pass http://langfuse-langfuse-web-1:3000/;"
fi

# LiteLLMのパスは常に/api
export LITELLM_PATH_PREFIX="/api"

# デバッグ用のログ出力
log_info "設定内容:"
log_info "LANGFUSE_PATH_PREFIX: $LANGFUSE_PATH_PREFIX"
log_info "LITELLM_PATH_PREFIX: $LITELLM_PATH_PREFIX"
log_info "ROOT_LOCATION: $ROOT_LOCATION"

# テンプレートからNginx設定を生成
envsubst '${LANGFUSE_PATH_PREFIX} ${LITELLM_PATH_PREFIX} ${ROOT_LOCATION}' \
    < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

# Nginxを起動
exec nginx -g 'daemon off;'
