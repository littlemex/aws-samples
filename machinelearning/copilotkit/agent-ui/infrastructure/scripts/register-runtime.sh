#!/bin/bash
set -e

# デフォルト値
ENV=${NODE_ENV:-dev}
AUTH_TYPE="none"
STATUS="active"
REGION="us-east-1"

# 使用方法
usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Register a new AgentCore Runtime in DynamoDB

Required Options:
  --runtime-id ID           Runtime identifier (e.g., runtime-local, runtime-prod-1)
  --name NAME              Display name for the runtime
  --url URL                Runtime URL (e.g., http://localhost:8081, https://xxx.runtime.bedrock-agentcore.amazonaws.com)

Optional Options:
  --auth-type TYPE         Authentication type: none, oauth, sigv4 (default: none)
  --region REGION          AWS region (default: us-east-1)
  --status STATUS          Runtime status: active, inactive, error (default: active)
  --description DESC       Description of the runtime
  --deployed-by EMAIL      Email of the administrator who deployed the runtime
  
OAuth Options (required if --auth-type=oauth):
  --cognito-issuer URL     Cognito Issuer URL (e.g., https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxx)
  --cognito-client-id ID   Cognito Client ID
  --cognito-audience AUD   Cognito Audience (usually same as client ID)
  --required-scopes SCOPES Comma-separated list of required scopes (default: openid,profile,email)
  --client-secret-arn ARN  AWS Secrets Manager ARN for client secret (optional, for future Token Exchange)

SigV4 Options (required if --auth-type=sigv4):
  --sigv4-service SERVICE  AWS service name (e.g., bedrock)
  --sigv4-region REGION    AWS region for SigV4 signing

Environment:
  NODE_ENV                 Environment suffix: dev, prod (default: dev)

Examples:
  # Register local development runtime
  $0 --runtime-id runtime-local \\
     --name "ローカル開発環境" \\
     --url http://localhost:8081 \\
     --auth-type none

  # Register production runtime with OAuth
  $0 --runtime-id runtime-prod-1 \\
     --name "本番AgentCore Runtime #1" \\
     --url https://xxx.runtime.bedrock-agentcore.us-east-1.amazonaws.com \\
     --auth-type oauth \\
     --cognito-issuer https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ZfOBZ4LXd \\
     --cognito-client-id 3t8emfum8htsiuka5ab5assi9 \\
     --deployed-by admin@example.com \\
     --description "本番環境のAgentCore Runtime"
EOF
  exit 1
}

# パラメータ解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --runtime-id) RUNTIME_ID="$2"; shift 2 ;;
    --name) RUNTIME_NAME="$2"; shift 2 ;;
    --url) RUNTIME_URL="$2"; shift 2 ;;
    --auth-type) AUTH_TYPE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --deployed-by) DEPLOYED_BY="$2"; shift 2 ;;
    --cognito-issuer) COGNITO_ISSUER="$2"; shift 2 ;;
    --cognito-client-id) COGNITO_CLIENT_ID="$2"; shift 2 ;;
    --cognito-audience) COGNITO_AUDIENCE="$2"; shift 2 ;;
    --required-scopes) REQUIRED_SCOPES="$2"; shift 2 ;;
    --client-secret-arn) CLIENT_SECRET_ARN="$2"; shift 2 ;;
    --sigv4-service) SIGV4_SERVICE="$2"; shift 2 ;;
    --sigv4-region) SIGV4_REGION="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# 必須パラメータチェック
if [ -z "$RUNTIME_ID" ] || [ -z "$RUNTIME_NAME" ] || [ -z "$RUNTIME_URL" ]; then
  echo "Error: Missing required parameters"
  echo ""
  usage
fi

# 認証タイプ検証
if [[ ! "$AUTH_TYPE" =~ ^(none|oauth|sigv4)$ ]]; then
  echo "Error: Invalid auth-type: $AUTH_TYPE (must be none, oauth, or sigv4)"
  exit 1
fi

# OAuth検証
if [ "$AUTH_TYPE" = "oauth" ]; then
  if [ -z "$COGNITO_ISSUER" ] || [ -z "$COGNITO_CLIENT_ID" ]; then
    echo "Error: OAuth requires --cognito-issuer and --cognito-client-id"
    exit 1
  fi
  # AudienceがなければClient IDを使用
  COGNITO_AUDIENCE=${COGNITO_AUDIENCE:-$COGNITO_CLIENT_ID}
  # デフォルトスコープ
  REQUIRED_SCOPES=${REQUIRED_SCOPES:-"openid,profile,email"}
  # Discovery URL生成
  DISCOVERY_URL="${COGNITO_ISSUER}/.well-known/openid-configuration"
fi

# SigV4検証
if [ "$AUTH_TYPE" = "sigv4" ]; then
  if [ -z "$SIGV4_SERVICE" ] || [ -z "$SIGV4_REGION" ]; then
    echo "Error: SigV4 requires --sigv4-service and --sigv4-region"
    exit 1
  fi
fi

# テーブル名取得
TABLE_NAME=$(aws ssm get-parameter \
  --name "/copilotkit-agentcore/${ENV}/dynamodb/runtimes-table-name" \
  --query "Parameter.Value" \
  --output text 2>/dev/null)

if [ -z "$TABLE_NAME" ]; then
  echo "Error: Runtimes table not found. Please deploy the stack first:"
  echo "  cd infrastructure && ./scripts/deploy-runtimes-dynamodb.sh"
  exit 1
fi

echo "=========================================="
echo "🔧 Registering Runtime to DynamoDB"
echo "=========================================="
echo "Runtime ID: $RUNTIME_ID"
echo "Name: $RUNTIME_NAME"
echo "URL: $RUNTIME_URL"
echo "Auth Type: $AUTH_TYPE"
echo "Region: $REGION"
echo "Status: $STATUS"
echo "Table: $TABLE_NAME"
echo "Environment: $ENV"
echo ""

# タイムスタンプ生成
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# 基本項目
ITEM_JSON=$(cat <<EOF
{
  "runtimeId": {"S": "$RUNTIME_ID"},
  "runtimeName": {"S": "$RUNTIME_NAME"},
  "runtimeUrl": {"S": "$RUNTIME_URL"},
  "region": {"S": "$REGION"},
  "authType": {"S": "$AUTH_TYPE"},
  "status": {"S": "$STATUS"},
  "createdAt": {"S": "$TIMESTAMP"},
  "updatedAt": {"S": "$TIMESTAMP"}
EOF
)

# オプション項目追加
if [ -n "$DESCRIPTION" ]; then
  ITEM_JSON+=",\"description\": {\"S\": \"$DESCRIPTION\"}"
fi

if [ -n "$DEPLOYED_BY" ]; then
  ITEM_JSON+=",\"deployedBy\": {\"S\": \"$DEPLOYED_BY\"}"
fi

# OAuth設定追加
if [ "$AUTH_TYPE" = "oauth" ]; then
  OAUTH_CONFIG="{"
  OAUTH_CONFIG+="\"issuerUrl\": {\"S\": \"$COGNITO_ISSUER\"},"
  OAUTH_CONFIG+="\"discoveryUrl\": {\"S\": \"$DISCOVERY_URL\"},"
  OAUTH_CONFIG+="\"clientId\": {\"S\": \"$COGNITO_CLIENT_ID\"},"
  OAUTH_CONFIG+="\"audience\": {\"S\": \"$COGNITO_AUDIENCE\"},"
  
  # Required Scopes（配列）
  IFS=',' read -ra SCOPES_ARRAY <<< "$REQUIRED_SCOPES"
  SCOPES_JSON="["
  for i in "${!SCOPES_ARRAY[@]}"; do
    [ $i -gt 0 ] && SCOPES_JSON+=","
    SCOPES_JSON+="{\"S\": \"${SCOPES_ARRAY[$i]}\"}"
  done
  SCOPES_JSON+="]"
  OAUTH_CONFIG+="\"requiredScopes\": {\"L\": $SCOPES_JSON}"
  
  # Client Secret ARN（オプション）
  if [ -n "$CLIENT_SECRET_ARN" ]; then
    OAUTH_CONFIG+=",\"clientSecretArn\": {\"S\": \"$CLIENT_SECRET_ARN\"}"
  fi
  
  OAUTH_CONFIG+="}"
  ITEM_JSON+=",\"oauthConfig\": {\"M\": $OAUTH_CONFIG}"
fi

# SigV4設定追加
if [ "$AUTH_TYPE" = "sigv4" ]; then
  SIGV4_CONFIG="{"
  SIGV4_CONFIG+="\"service\": {\"S\": \"$SIGV4_SERVICE\"},"
  SIGV4_CONFIG+="\"region\": {\"S\": \"$SIGV4_REGION\"}"
  SIGV4_CONFIG+="}"
  ITEM_JSON+=",\"sigv4Config\": {\"M\": $SIGV4_CONFIG}"
fi

# JSON終了
ITEM_JSON+="}"

# DynamoDBに登録
echo "📝 Writing to DynamoDB..."
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item "$ITEM_JSON" \
  --return-consumed-capacity TOTAL

echo ""
echo "=========================================="
echo "✅ Runtime registered successfully!"
echo "=========================================="

# 登録内容確認
echo ""
echo "📋 Verifying registration..."
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key "{\"runtimeId\": {\"S\": \"$RUNTIME_ID\"}}" \
  --output json | jq '.Item' || echo "Verification failed"

echo ""
echo "📝 Next Steps:"
echo "1. Verify the runtime is accessible at: $RUNTIME_URL"
echo "2. Update frontend to fetch runtimes from DynamoDB"
echo "3. Test API integration with this runtime"
echo ""
