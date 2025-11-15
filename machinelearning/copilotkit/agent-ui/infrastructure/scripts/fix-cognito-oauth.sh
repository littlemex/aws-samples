#!/bin/bash
set -e

echo "Fixing Cognito OAuth Configuration..."

# Configuration
PROJECT_NAME="copilotkit-agentcore"
CLIENT_SUFFIX="${CLIENT_SUFFIX:-copilotkit}"
REGION="${AWS_REGION:-us-east-1}"
SSM_PREFIX="/${PROJECT_NAME}/${CLIENT_SUFFIX}"

# SSM Parameter Storeから値を取得
echo "Retrieving values from SSM Parameter Store..."
USER_POOL_ID=$(aws ssm get-parameter --name "${SSM_PREFIX}/cognito/user-pool-id" --query 'Parameter.Value' --output text --region $REGION)
CLIENT_ID=$(aws ssm get-parameter --name "${SSM_PREFIX}/cognito/client-id" --query 'Parameter.Value' --output text --region $REGION)

# NextJS URLはCloudFormation Stackから取得（デプロイ後に決定されるため）
NEXTJS_URL=$(aws cloudformation describe-stacks --stack-name CopilotKitNextjsStack --query "Stacks[0].Outputs[?OutputKey=='NextjsUrl'].OutputValue" --output text --region $REGION)

echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "NextJS URL: $NEXTJS_URL"

# 現在の設定を確認
echo "=== Current OAuth Configuration ==="
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --region us-east-1 \
  --query "{SupportedIdentityProviders:UserPoolClient.SupportedIdentityProviders,AllowedOAuthFlows:UserPoolClient.AllowedOAuthFlows,AllowedOAuthScopes:UserPoolClient.AllowedOAuthScopes,CallbackURLs:UserPoolClient.CallbackURLs}"

# OAuth設定を有効化
echo "=== Enabling OAuth Configuration ==="
aws cognito-idp update-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --supported-identity-providers "COGNITO" \
  --allowed-o-auth-flows "code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --callback-urls \
    "http://localhost:13001/api/auth/callback/cognito" \
    "http://localhost:3000/api/auth/callback/cognito" \
    "http://localhost:3001/api/auth/callback/cognito" \
    "$NEXTJS_URL/api/auth/callback/cognito" \
  --region us-east-1

echo "OAuth configuration updated successfully!"

# 更新後の設定を確認
echo "=== Updated OAuth Configuration ==="
aws cognito-idp describe-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --region us-east-1 \
  --query "{SupportedIdentityProviders:UserPoolClient.SupportedIdentityProviders,AllowedOAuthFlows:UserPoolClient.AllowedOAuthFlows,AllowedOAuthScopes:UserPoolClient.AllowedOAuthScopes,CallbackURLs:UserPoolClient.CallbackURLs}"
