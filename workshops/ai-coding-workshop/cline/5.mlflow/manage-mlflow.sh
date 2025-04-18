#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# 環境変数のデフォルト値を設定
setup_environment() {
    # env.sh から読み込まれた値を使用し、設定されていない場合のみデフォルト値を設定
    if [ -z "$AWS_REGION_NAME" ]; then
        export AWS_REGION_NAME="us-east-1"
        log_warn "AWS_REGION_NAME が設定されていません。デフォルト値 $AWS_REGION_NAME を使用します"
    fi
    log_info "使用するリージョン: $AWS_REGION_NAME"

    if [ -z "$MLFLOW_TRACKING_SERVER_NAME" ]; then
        export MLFLOW_TRACKING_SERVER_NAME="mlflow-tracking-server"
        log_info "MLFLOW_TRACKING_SERVER_NAME が設定されていません。デフォルト値 $MLFLOW_TRACKING_SERVER_NAME を使用します"
    fi
    log_info "使用するトラッキングサーバー名: $MLFLOW_TRACKING_SERVER_NAME"
}

# AWS 前提条件のチェック
check_aws_prerequisites() {
    local region="${1:-us-east-1}"
    
    # AWS CLI が利用可能か確認
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI がインストールされていません"
        return 1
    fi
    
    # AWS 認証情報の確認
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 認証情報が正しく設定されていません"
        return 1
    fi
    
    log_info "AWS 前提条件のチェックが完了しました"
    log_info "リージョン: $region"
    return 0
}

load_env_file() {
    local env_file="${1:-.env}"
    local set_defaults="${2:-true}"
    
    log_info "環境変数ファイルを読み込みます"
    
    # 現在のスクリプトのディレクトリを取得
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local env_sh_file="$current_dir/env.sh"
    
    if [ -f "$env_sh_file" ]; then
        source "$env_sh_file"
        log_info "環境変数を読み込みました: $env_sh_file"
        return 0
    else
        log_error "env.sh ファイルが見つかりません。以下のコマンドを実行してください："
        log_info "../scripts/setup_env.sh ."
        
        # デフォルト値の設定
        if [ "$set_defaults" = "true" ]; then
            log_warn "デフォルト設定を使用します"
            export MLFLOW_TRACKING_URI=""
            return 0
        fi
        
        return 1
    fi
}

# ロゴ表示
echo -e "${GREEN}"
echo "  __  __ _     __ _                   __  __                                   "
echo " |  \/  | |   / _| |                 |  \/  |                                  "
echo " | \  / | |  | |_| | _____      __   | \  / | __ _ _ __   __ _  __ _  ___ _ __ "
echo " | |\/| | |  |  _| |/ _ \ \ /\ / /   | |\/| |/ _\` | '_ \ / _\` |/ _\` |/ _ \ '__|"
echo " | |  | | |__| | | | (_) \ V  V /    | |  | | (_| | | | | (_| | (_| |  __/ |   "
echo " |_|  |_|____|_| |_|\___/ \_/\_/     |_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|   "
echo "                                                                __/ |          "
echo "                                                               |___/           "
echo -e "${NC}"

# 環境変数の読み込み
if ! load_env_file ".env"; then
    log_error "環境変数の読み込みに失敗しました"
    exit 1
fi

# 環境変数のデフォルト値を設定
setup_environment

# AWS 前提条件をチェック
if ! check_aws_prerequisites "$AWS_REGION_NAME"; then
    log_error "AWS 前提条件のチェックに失敗しました"
    exit 1
fi
log_info "MLflow Tracking URI: $MLFLOW_TRACKING_URI"
log_info "AWS リージョン: $AWS_REGION_NAME"

# MLflow トラッキングサーバーの情報を取得
get_tracking_server_info() {
    # 環境変数のデフォルト値を設定
    setup_environment
    
    # 引数で指定された値があれば上書き
    local tracking_server_name="${1:-$MLFLOW_TRACKING_SERVER_NAME}"
    local region="${2:-$AWS_REGION_NAME}"
    
    log_info "MLflow トラッキングサーバーの情報を取得します..."
    
    # AWS 前提条件をチェック
    if ! check_aws_prerequisites "$region"; then
        return 1
    fi
    
    log_info "トラッキングサーバー名: $tracking_server_name"
    
    # トラッキングサーバーのリストを取得
    log_info "トラッキングサーバーのリストを取得しています..."
    local tracking_servers
    tracking_servers=$(aws sagemaker list-mlflow-tracking-servers --region "$region" --query 'TrackingServerSummaries[*].TrackingServerName' --output text)
    
    if [ -z "$tracking_servers" ]; then
        log_error "トラッキングサーバーが見つかりません"
        return 1
    fi
    
    # トラッキングサーバーの詳細情報を取得
    log_info "トラッキングサーバーの詳細情報を取得しています..."
    local tracking_server_url
    local tracking_server_arn
    
    # URL を取得
    tracking_server_url=$(aws sagemaker describe-mlflow-tracking-server \
        --tracking-server-name "$tracking_server_name" \
        --region "$region" \
        --query 'TrackingServerUrl' \
        --output text)
    
    if [ $? -ne 0 ] || [ -z "$tracking_server_url" ]; then
        log_error "トラッキングサーバーの URL 取得に失敗しました"
        return 1
    fi
    
    # ARN を取得
    tracking_server_arn=$(aws sagemaker describe-mlflow-tracking-server \
        --tracking-server-name "$tracking_server_name" \
        --region "$region" \
        --query 'TrackingServerArn' \
        --output text)
    
    if [ $? -ne 0 ] || [ -z "$tracking_server_arn" ]; then
        log_error "トラッキングサーバーの ARN 取得に失敗しました"
        return 1
    fi
    
    # 環境変数に直接設定
    export MLFLOW_TRACKING_URI="$tracking_server_url"
    export MLFLOW_TRACKING_ARN="$tracking_server_arn"
    log_info "MLflow Tracking URI: $MLFLOW_TRACKING_URI"
    return 0
}

# AWS SageMaker MLflow トラッキングサーバーの presigned URL を取得
get_presigned_url() {
    # 環境変数のデフォルト値を設定
    setup_environment
    
    log_info "MLflow トラッキングサーバーの presigned URL を取得します..."
    
    # AWS 前提条件をチェック
    if ! check_aws_prerequisites "$AWS_REGION_NAME"; then
        return 1
    fi
    
    log_info "トラッキングサーバー名: $MLFLOW_TRACKING_SERVER_NAME"
    
    # presigned URL を取得（有効期限: 30分）
    log_info "presigned URL を生成しています（有効期限: 30分）..."
    local presigned_url
    presigned_url=$(aws sagemaker create-presigned-mlflow-tracking-server-url \
        --tracking-server-name "$MLFLOW_TRACKING_SERVER_NAME" \
        --expires-in-seconds 300 \
        --session-expiration-duration-in-seconds 20000 \
        --region "$AWS_REGION_NAME" \
        --query 'AuthorizedUrl' \
        --output text)
    
    if [ $? -ne 0 ] || [ -z "$presigned_url" ]; then
        log_error "presigned URL の生成に失敗しました"
        return 1
    fi
    
    # 環境変数に直接設定
    export MLFLOW_TRACKING_URI="$presigned_url"
    export MLFLOW_TRACKING_ARN="$presigned_url"
    log_info "MLflow presigned URL: $MLFLOW_TRACKING_URI"
    return 0
}

# 環境変数ファイルを更新
update_env_file() {
    local env_file=".env"
    local key="$1"
    local value="$2"
    
    log_info "環境変数ファイル ($env_file) を更新しています: $key"
    
    # .envファイルが存在しない場合は作成
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
        log_info "環境変数ファイルを新規作成しました: $env_file"
    fi
    
    # 既存の設定を削除
    sed -i "/^$key=/d" "$env_file" 2>/dev/null
    
    # 新しい設定を追加
    echo "$key=\"$value\"" >> "$env_file"
    log_info "環境変数を更新しました: $key"
}

# 変数のデフォルト値
CONFIG_FILE="default_config.yml"
ENV_FILE=".env"

# LiteLLM サービスを開始
start_litellm_service() {
    log_info "LiteLLM サービスを開始します..."
    
    # 環境変数オプションを構築
    local cmd="docker compose"
    if [ -f "$ENV_FILE" ]; then
        log_info "環境変数ファイルを使用します: $ENV_FILE"
        cmd="$cmd --env-file $ENV_FILE"
    else
        log_warn "環境変数ファイルが見つかりません: $ENV_FILE"
    fi
    
    # 設定ファイルを確認
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "設定ファイル $CONFIG_FILE が見つかりません"
        return 1
    fi
    
    # 設定ファイルを環境変数として渡す
    export CONFIG_FILE
    log_info "設定ファイルを使用します: $CONFIG_FILE"
    
    cmd="$cmd -f docker-compose.yml up -d"
    log_info "実行コマンド: $cmd"
    eval "$cmd"
    
    if [ $? -ne 0 ]; then
        log_error "LiteLLM の起動に失敗しました"
        return 1
    fi
    
    log_info "LiteLLM が起動しました"
    return 0
}

# LiteLLM サービスを停止
stop_litellm_service() {
    log_info "LiteLLM サービスを停止しています..."
    docker compose -f docker-compose.yml down
    log_info "LiteLLM が停止しました"
    return 0
}

# LiteLLM サービスを再起動
restart_litellm_service() {
    log_info "LiteLLM サービスを再起動します..."
    stop_litellm_service
    start_litellm_service
    return $?
}

# LiteLLM の設定を更新
update_litellm_config() {
    # 環境変数のデフォルト値を設定
    setup_environment
    
    log_info "LiteLLM の設定を更新しています..."
    
    # Tracking URIを取得（直接環境変数に設定）
    if ! get_tracking_server_info; then
        log_warn "通常のTracking URIの取得に失敗しました。presigned URLを試みます..."
        
        # presigned URLを取得（直接環境変数に設定）
        if ! get_presigned_url; then
            log_error "MLflow Tracking URIの取得に失敗しました"
            return 1
        fi
    fi
    
    # 環境変数ファイルを更新
    update_env_file "MLFLOW_TRACKING_URI" "$MLFLOW_TRACKING_URI"
    update_env_file "MLFLOW_TRACKING_ARN" "$MLFLOW_TRACKING_ARN"
    
    log_info "設定ファイルを使用します: $CONFIG_FILE"
    
    # LiteLLM の再起動
    restart_litellm_service
    
    log_info "LiteLLM の設定を更新しました"
}

# MLflow サービスを開始
start_mlflow_service() {
    # 環境変数のデフォルト値を設定
    setup_environment
    
    log_info "MLflow サービスを開始します..."
    
    # トラッキングサーバーを起動
    log_info "トラッキングサーバーを起動しています..."
    response=$(aws sagemaker start-mlflow-tracking-server \
        --tracking-server-name "$MLFLOW_TRACKING_SERVER_NAME" \
        --region "$AWS_REGION_NAME" \
        --query 'TrackingServerArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_info "MLflow トラッキングサーバーが起動されました"
        log_info "ARN: $response"
    else
        log_error "MLflow トラッキングサーバーの起動に失敗しました"
        return 1
    fi
}

# MLflow サービスを停止
stop_mlflow_service() {
    # 環境変数のデフォルト値を設定
    setup_environment
    
    log_info "MLflow サービスを停止します..."
    
    # トラッキングサーバーを停止
    log_info "トラッキングサーバーを停止しています..."
    response=$(aws sagemaker stop-mlflow-tracking-server \
        --tracking-server-name "$MLFLOW_TRACKING_SERVER_NAME" \
        --region "$AWS_REGION_NAME" \
        --query 'TrackingServerArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        log_info "MLflow トラッキングサーバーが停止されました"
        log_info "ARN: $response"
    else
        log_error "MLflow トラッキングサーバーの停止に失敗しました"
        return 1
    fi
}


# コマンドラインオプションの解析
parse_options() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift
                ;;
            -e|--env-file)
                ENV_FILE="$2"
                shift
                ;;
            *)
                # 不明なオプションは無視
                ;;
        esac
        shift
    done
}

# コマンドライン引数の解析
COMMAND="$1"
shift
parse_options "$@"

case "$COMMAND" in
    start)
        start_mlflow_service || exit 1
        ;;
    stop)
        stop_mlflow_service || exit 1
        ;;
    restart)
        log_info "MLflow サービスを再起動します..."
        stop_mlflow_service
        sleep 5
        start_mlflow_service || exit 1
        ;;
    get-tracking-info)
        server_name="${1:-mlflow-tracking-server}"
        region="${2:-us-east-1}"
        get_tracking_server_info "$server_name" "$region"
        ;;
    test)
        log_info "MLflow テストを実行します..."
        python3 test_litellm_mlflow.py
        ;;
    update-config)
        update_litellm_config
        ;;
    get-url)
        get_presigned_url
        ;;
    litellm-start)
        start_litellm_service || exit 1
        ;;
    litellm-stop)
        stop_litellm_service || exit 1
        ;;
    litellm-restart)
        restart_litellm_service || exit 1
        ;;
    *)
        echo -e "${GREEN}使用方法:${NC}"
        echo -e "  ${YELLOW}./manage-mlflow.sh start${NC}     - MLflow サービスを開始"
        echo -e "  ${YELLOW}./manage-mlflow.sh stop${NC}      - MLflow サービスを停止"
        echo -e "  ${YELLOW}./manage-mlflow.sh restart${NC}   - MLflow サービスを再起動"
        echo -e "  ${YELLOW}./manage-mlflow.sh get-tracking-info [server_name] [region]${NC}"
        echo -e "    server_name: トラッキングサーバー名 (デフォルト: mlflow-tracking-server)"
        echo -e "    region: AWS リージョン (デフォルト: us-east-1)"
        echo -e "  ${YELLOW}./manage-mlflow.sh test${NC}      - MLflow テストを実行"
        echo -e "  ${YELLOW}./manage-mlflow.sh update-config [-c CONFIG_FILE]${NC} - LiteLLM の設定を更新"
        echo -e "  ${YELLOW}./manage-mlflow.sh get-url${NC}      - MLflow トラッキングサーバーの presigned URL を取得"
        echo -e "  ${YELLOW}./manage-mlflow.sh litellm-start [-c CONFIG_FILE] [-e ENV_FILE]${NC}  - LiteLLM サービスを開始"
        echo -e "    -c, --config: 設定ファイルを指定 (デフォルト: default_config.yml)"
        echo -e "    -e, --env-file: 環境変数ファイルを指定 (デフォルト: .env)"
        echo -e "  ${YELLOW}./manage-mlflow.sh litellm-stop${NC}   - LiteLLM サービスを停止"
        echo -e "  ${YELLOW}./manage-mlflow.sh litellm-restart [-c CONFIG_FILE] [-e ENV_FILE]${NC} - LiteLLM サービスを再起動"
        ;;
esac
