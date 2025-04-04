#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_FILE="default_config.yml"
ROLE_NAME=""
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

# EC2インスタンスロールを取得
get_ec2_instance_role() {
    log_info "インスタンスメタデータサービスからロール情報を取得します..."
    
    # IMDSv2 トークンを取得
    local token
    token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    
    if [ -n "$token" ]; then
        # IMDSv2 を使用してロール名を取得
        ROLE_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
        
        if [ -n "$ROLE_NAME" ]; then
            log_info "インスタンスメタデータサービスからロール名を取得しました: $ROLE_NAME"
            echo "$ROLE_NAME"
            return 0
        fi
    else
        # IMDSv1 にフォールバック
        ROLE_NAME=$(curl -s --connect-timeout 1 http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)
        
        if [ -n "$ROLE_NAME" ]; then
            log_info "インスタンスメタデータサービスからロール名を取得しました: $ROLE_NAME"
            return 0
        fi
    fi
    
    log_warn "EC2インスタンスロールを取得できませんでした"
    return 1
}

# EC2インスタンスロールにBedrockアクセスポリシーを設定
set_policy() {
    get_ec2_instance_role
    log_info "BedrockAccessPolicy を設定しています..."
    local policy_name="BedrockAccessPolicy"
    cat << EOF > /tmp/bedrock_policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "bedrock:InvokeModel",
                "bedrock:InvokeModelWithResponseStream"
            ],
            "Resource": [
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-*",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-*",
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-7-sonnet-*",
                "arn:aws:bedrock:*:*:inference-profile/*"
            ]
        }
    ]
}
EOF
    aws iam put-role-policy --role-name $ROLE_NAME --policy-name "$policy_name" --policy-document file:///tmp/bedrock_policy.json
}

show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  start         - サービスを起動"
    echo "  stop          - サービスを停止"
    echo "  restart       - サービスを再起動"
    echo "  set-policy    - EC2インスタンスロールにBedrockアクセスポリシーを設定"
    echo
    echo "Options:"
    echo "  -e, --env-file FILE - 環境変数ファイルを指定 (デフォルト: .env)"
    echo "  -h, --help          - このヘルプメッセージを表示"
    echo
    echo "Examples:"
    echo "  $0 start -e custom.env"
    echo "  $0 set-policy"
}

# メイン処理
COMMAND=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        start|stop|restart)
            COMMAND="$1"
            ;;
        set-policy)
            COMMAND="$1"
            ;;
        -e|--env-file)
            ENV_FILE="$2"
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
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        start_services
        ;;
    set-policy)
        set_policy
        ;;
    *)
        log_error "不明なコマンド: $COMMAND"
        show_help
        exit 1
        ;;
esac
