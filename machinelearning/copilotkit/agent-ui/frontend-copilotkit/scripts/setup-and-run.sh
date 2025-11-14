#!/bin/bash

# CloudFormationスタックから環境変数を取得して.env.localファイルを作成し、
# Next.js開発サーバーを起動するスクリプト

set -e

# 環境変数から取得
PROJECT_NAME="copilotkit-agentcore"
CLIENT_SUFFIX="${CLIENT_SUFFIX:-copilotkit}"
SSM_PREFIX="/${PROJECT_NAME}/${CLIENT_SUFFIX}"
STACK_NAME="${COGNITO_STACK_NAME:-CopilotKitCognitoStack}"
FRONTEND_DIR="${FRONTEND_DIR:-/home/coder/aws-samples/machinelearning/copilotkit/agent-ui/frontend-copilotkit}"
ENV_FILE="${FRONTEND_DIR}/.env.local"

# デフォルト設定
DEFAULT_PORT="3000"
DEFAULT_HOST="localhost"

# 引数の解析
usage() {
    echo "使用方法: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -p, --port PORT      使用するポート番号 (デフォルト: $DEFAULT_PORT)"
    echo "  -h, --host HOST      使用するホスト名 (デフォルト: $DEFAULT_HOST)"
    echo "  -u, --url URL        完全なNEXTAUTH_URL (ポート・ホストより優先)"
    echo "  --help              このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                           # デフォルト設定 (localhost:3000)"
    echo "  $0 -p 3001                   # ポート3001を使用"
    echo "  $0 -u http://localhost:13001 # 完全なURLを指定"
}

# パラメータ解析
NEXTAUTH_PORT="$DEFAULT_PORT"
NEXTAUTH_HOST="$DEFAULT_HOST"
NEXTAUTH_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            NEXTAUTH_PORT="$2"
            shift 2
            ;;
        -h|--host)
            NEXTAUTH_HOST="$2"
            shift 2
            ;;
        -u|--url)
            NEXTAUTH_URL="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            usage
            exit 1
            ;;
    esac
done

# NEXTAUTH_URLの決定
if [ -z "$NEXTAUTH_URL" ]; then
    NEXTAUTH_URL="http://${NEXTAUTH_HOST}:${NEXTAUTH_PORT}"
fi

echo "=========================================="
echo "Cognito環境変数セットアップスクリプト"
echo "=========================================="
echo ""

# AWS Regionの取得
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

# SSM Parameter Storeから値を取得
echo "SSM Parameter Storeから設定を取得中..."
echo "  - SSM Prefix: ${SSM_PREFIX}"

USER_POOL_CLIENT_ID=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/client-id" \
    --query 'Parameter.Value' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null)

ISSUER_URL=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cognito/issuer-url" \
    --query 'Parameter.Value' \
    --output text \
    --region ${AWS_REGION} 2>/dev/null)

# 値の確認
if [ -z "$USER_POOL_CLIENT_ID" ] || [ "$USER_POOL_CLIENT_ID" == "null" ]; then
    echo "エラー: Client IDがSSMから取得できませんでした"
    echo "SSMパラメータが存在するか確認してください: ${SSM_PREFIX}/cognito/client-id"
    exit 1
fi

if [ -z "$ISSUER_URL" ] || [ "$ISSUER_URL" == "null" ]; then
    echo "エラー: Issuer URLがSSMから取得できませんでした"
    echo "SSMパラメータが存在するか確認してください: ${SSM_PREFIX}/cognito/issuer-url"
    exit 1
fi

echo "✓ SSM Parameter Storeから設定を取得しました"
echo "  - Client ID: ${USER_POOL_CLIENT_ID}"
echo "  - Issuer URL: ${ISSUER_URL}"
echo "  - Region: ${AWS_REGION}"
echo ""

# NEXTAUTH_SECRETを生成
echo "NEXTAUTH_SECRETを生成中..."
NEXTAUTH_SECRET=$(openssl rand -base64 32)
echo "✓ NEXTAUTH_SECRETを生成しました"
echo ""

# .env.localファイルを作成
echo ".env.localファイルを作成中: ${ENV_FILE}"
echo "  - NEXTAUTH_URL: ${NEXTAUTH_URL}"
cat > ${ENV_FILE} << EOF
# Cognito Configuration
COGNITO_CLIENT_ID=${USER_POOL_CLIENT_ID}
COGNITO_ISSUER=${ISSUER_URL}

# NextAuth.js Configuration
NEXTAUTH_URL=${NEXTAUTH_URL}
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}

# AWS Configuration
AWS_REGION=${AWS_REGION}
EOF

echo "✓ .env.localファイルを作成しました"
echo ""

# 作成したファイルの内容を表示（SECRETは隠す）
echo "作成された環境変数:"
cat ${ENV_FILE} | sed "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=********/"
echo ""

echo "=========================================="
echo "セットアップ完了"
echo "=========================================="
echo ""
echo "使用例:"
echo "  # デフォルト (localhost:3000)"
echo "  ./scripts/setup-and-run.sh"
echo ""
echo "  # ポート3001を使用"
echo "  ./scripts/setup-and-run.sh -p 3001"
echo ""
echo "  # SSMポートフォワード用"
echo "  ./scripts/setup-and-run.sh -u http://localhost:13001"
echo ""
echo "Next.js開発サーバーを起動するには:"
echo "  cd ${FRONTEND_DIR}"
echo "  npm run dev"
echo ""
