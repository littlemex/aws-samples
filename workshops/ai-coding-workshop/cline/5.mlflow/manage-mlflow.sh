#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# 環境変数ファイルの読み込み
if [ -f .env ]; then
    echo -e "${GREEN}環境変数を .env ファイルから読み込みます${NC}"
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
    done < .env
else
    echo -e "${YELLOW}警告: .env ファイルが見つかりません。デフォルト設定を使用します${NC}"
    # デフォルト値の設定
    export MLFLOW_TRACKING_URI="http://localhost:5000"
    export DEPLOYMENT_ENV="local"
fi

# デプロイメント環境の検出
if [ "$DEPLOYMENT_ENV" = "aws" ]; then
    echo -e "${GREEN}AWS 環境で実行中です${NC}"
    echo -e "${GREEN}MLflow Tracking URI: $MLFLOW_TRACKING_URI${NC}"
else
    echo -e "${GREEN}ローカル環境で実行中です${NC}"
    echo -e "${GREEN}MLflow Tracking URI: $MLFLOW_TRACKING_URI${NC}"
fi

# LiteLLM の環境変数を更新
update_litellm_env() {
    local env_file="../2.litellm/.env"
    log_info "LiteLLM の環境変数を更新しています..."
    
    # .envファイルが存在しない場合は作成
    if [ ! -f "$env_file" ]; then
        touch "$env_file"
    fi
    
    # 既存のMLflow設定を削除
    sed -i '/^# MLflow Configuration/d' "$env_file" 2>/dev/null
    sed -i '/^MLFLOW_TRACKING_URI=/d' "$env_file" 2>/dev/null
    sed -i '/^MLFLOW_EXPERIMENT_NAME=/d' "$env_file" 2>/dev/null
    
    # 新しいMLflow設定を追加
    log_info "MLflow の設定を更新しています..."
    {
        echo "# MLflow Configuration"
        echo "MLFLOW_TRACKING_URI=$MLFLOW_TRACKING_URI"
        echo "MLFLOW_EXPERIMENT_NAME=$MLFLOW_EXPERIMENT_NAME"
    } >> "$env_file"
}

# LiteLLM の設定を更新
update_litellm_config() {
    log_info "LiteLLM の設定を更新しています..."
    
    if [ ! -d "../2.litellm" ]; then
        log_error "LiteLLM ディレクトリが見つかりません: ../2.litellm"
        exit 1
    fi
    
    # 環境変数を更新
    update_litellm_env
    
    cd "../2.litellm"
    ./manage-litellm.sh stop
    log_info "LiteLLM を MLflow 設定で起動しています..."
    ./manage-litellm.sh -c "../5.mlflow/litellm_config.yml" start
    
    # MLflow ネットワークの存在確認
    MLFLOW_NETWORK="mlflow-network"
    if ! docker network ls | grep -q "$MLFLOW_NETWORK"; then
        log_warn "MLflow ネットワーク ($MLFLOW_NETWORK) が見つかりません。MLflow が起動しているか確認してください。"
        log_info "MLflow を起動します..."
        cd - > /dev/null
        ./manage-mlflow.sh start
        cd "../2.litellm"
        
        # ネットワーク名を再確認
        if ! docker network ls | grep -q "$MLFLOW_NETWORK"; then
            log_error "MLflow ネットワークが見つかりません。MLflow の起動を確認してください。"
            cd - > /dev/null
            return 1
        fi
    fi
    
    # LiteLLMコンテナをMLflowのネットワークに追加
    log_info "LiteLLM を MLflow のネットワーク ($MLFLOW_NETWORK) に追加しています..."
    docker network connect $MLFLOW_NETWORK 2litellm-litellm-1 || true
    docker network connect $MLFLOW_NETWORK 2litellm-postgres-1 || true
    cd - > /dev/null
    
    log_info "LiteLLM の設定を更新しました"
}

# AWS SageMaker MLflow トラッキングサーバーの presigned URL を取得
get_presigned_url() {
    log_info "MLflow トラッキングサーバーの presigned URL を取得します..."
    
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

    # CDK コマンドの設定
    local cdk_command="npx cdk"
    
    log_info "CDK コマンド: $cdk_command"
    
    # トラッキングサーバー名を設定
    local tracking_server_name="mlflow-tracking-server"

    # presigned URL を取得（有効期限: 30分）
    log_info "presigned URL を生成しています（有効期限: 30分）..."
    aws sagemaker create-presigned-mlflow-tracking-server-url \
        --tracking-server-name "$tracking_server_name" \
        --expires-in-seconds 300 \
        --session-expiration-duration-in-seconds 20000 \
        --region "${AWS_REGION_NAME:-us-east-1}" \
        --query 'AuthorizedUrl' \
        --output text

    if [ $? -eq 0 ]; then
        log_info "presigned URL の生成に成功しました"
    else
        log_error "presigned URL の生成に失敗しました"
        return 1
    fi
}

# コマンドライン引数の解析
case "$1" in
    start)
        echo -e "${GREEN}MLflow サービスを開始します...${NC}"
        if [ "$DEPLOYMENT_ENV" = "aws" ]; then
            echo -e "${YELLOW}AWS 環境では MLflow サービスは SageMaker で管理されています${NC}"
        else
            docker-compose up -d
            echo -e "${GREEN}MLflow サービスが開始されました${NC}"
            echo -e "${GREEN}MLflow UI: http://localhost:5000${NC}"
        fi
        ;;
    stop)
        echo -e "${GREEN}MLflow サービスを停止します...${NC}"
        if [ "$DEPLOYMENT_ENV" = "aws" ]; then
            echo -e "${YELLOW}AWS 環境では MLflow サービスは SageMaker で管理されています${NC}"
        else
            docker-compose stop
            echo -e "${GREEN}MLflow サービスが停止されました${NC}"
        fi
        ;;
    restart)
        echo -e "${GREEN}MLflow サービスを再起動します...${NC}"
        if [ "$DEPLOYMENT_ENV" = "aws" ]; then
            echo -e "${YELLOW}AWS 環境では MLflow サービスは SageMaker で管理されています${NC}"
        else
            docker-compose restart
            echo -e "${GREEN}MLflow サービスが再起動されました${NC}"
        fi
        ;;
    logs)
        echo -e "${GREEN}MLflow のログを表示します...${NC}"
        if [ "$DEPLOYMENT_ENV" = "aws" ]; then
            echo -e "${YELLOW}AWS 環境では MLflow のログは SageMaker コンソールで確認してください${NC}"
        else
            docker-compose logs -f
        fi
        ;;
    status)
        echo -e "${GREEN}MLflow サービスのステータスを確認します...${NC}"
        if [ "$DEPLOYMENT_ENV" = "aws" ]; then
            echo -e "${GREEN}AWS SageMaker MLflow エンドポイント: $MLFLOW_TRACKING_URI${NC}"
            # エンドポイントの接続テスト
            curl -s -o /dev/null -w "%{http_code}" $MLFLOW_TRACKING_URI > /dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}MLflow エンドポイントに接続できます${NC}"
            else
                echo -e "${RED}MLflow エンドポイントに接続できません${NC}"
            fi
        else
            if docker-compose ps | grep -q "mlflow-server.*Up"; then
                echo -e "${GREEN}MLflow サービスは実行中です${NC}"
                echo -e "${GREEN}MLflow UI: http://localhost:5000${NC}"
            else
                echo -e "${RED}MLflow サービスは停止しています${NC}"
            fi
        fi
        ;;
    detect-aws)
        echo -e "${GREEN}AWS SageMaker MLflow エンドポイントを検出します...${NC}"
        python3 detect_sagemaker_mlflow.py
        ;;
    test)
        echo -e "${GREEN}MLflow テストを実行します...${NC}"
        python3 test_litellm_mlflow.py
        ;;
    update-config)
        update_litellm_config
        ;;
    get-url)
        get_presigned_url
        ;;
    *)
        echo -e "${GREEN}使用方法:${NC}"
        echo -e "  ${YELLOW}./manage-mlflow.sh start${NC}     - MLflow サービスを開始"
        echo -e "  ${YELLOW}./manage-mlflow.sh stop${NC}      - MLflow サービスを停止"
        echo -e "  ${YELLOW}./manage-mlflow.sh restart${NC}   - MLflow サービスを再起動"
        echo -e "  ${YELLOW}./manage-mlflow.sh logs${NC}      - MLflow のログを表示"
        echo -e "  ${YELLOW}./manage-mlflow.sh status${NC}    - MLflow サービスのステータスを確認"
        echo -e "  ${YELLOW}./manage-mlflow.sh detect-aws${NC} - AWS SageMaker MLflow エンドポイントを検出"
        echo -e "  ${YELLOW}./manage-mlflow.sh test${NC}      - MLflow テストを実行"
        echo -e "  ${YELLOW}./manage-mlflow.sh update-config${NC} - LiteLLM の設定を更新"
        echo -e "  ${YELLOW}./manage-mlflow.sh get-url${NC}      - MLflow トラッキングサーバーの presigned URL を取得"
        ;;
esac
