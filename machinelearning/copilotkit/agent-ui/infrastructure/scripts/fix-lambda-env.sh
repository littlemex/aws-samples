#!/bin/bash
set -e

echo "Fixing NextJS Lambda Environment Variables..."

# Configuration
PROJECT_NAME="copilotkit-agentcore"
CLIENT_SUFFIX="${CLIENT_SUFFIX:-copilotkit}"
REGION="${AWS_REGION:-us-east-1}"
SSM_PREFIX="/${PROJECT_NAME}/${CLIENT_SUFFIX}"

# SSM Parameter Storeから値を取得
echo "Retrieving values from SSM Parameter Store..."
USER_POOL_ID=$(aws ssm get-parameter --name "${SSM_PREFIX}/cognito/user-pool-id" --query 'Parameter.Value' --output text --region $REGION)
CLIENT_ID=$(aws ssm get-parameter --name "${SSM_PREFIX}/cognito/client-id" --query 'Parameter.Value' --output text --region $REGION)
ISSUER_URL=$(aws ssm get-parameter --name "${SSM_PREFIX}/cognito/issuer-url" --query 'Parameter.Value' --output text --region $REGION)

# NextJS URLはCloudFormation Stackから取得（デプロイ後に決定されるため）
NEXTJS_URL=$(aws cloudformation describe-stacks --stack-name CopilotKitNextjsStack --query "Stacks[0].Outputs[?OutputKey=='NextjsUrl'].OutputValue" --output text --region $REGION)

NEXTJS_FUNCTION=$(aws lambda list-functions --query "Functions[?contains(FunctionName, 'NextjsFunctions')].FunctionName" --output text --region us-east-1)

echo "Updating function: $NEXTJS_FUNCTION"
echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "Issuer URL: $ISSUER_URL"
echo "NextJS URL: $NEXTJS_URL"

aws lambda update-function-configuration \
  --function-name "$NEXTJS_FUNCTION" \
  --environment "Variables={
    AWS_LWA_READINESS_CHECK_PORT=3000,
    AWS_LWA_READINESS_CHECK_PATH=/api/health,
    NEXTAUTH_SECRET=PLEASE_CHANGE_THIS_SECRET,
    AWS_LWA_ENABLE_COMPRESSION=true,
    NODE_ENV=production,
    CDK_NEXTJS_SERVER_DIST_DIR=/mnt/cdk-nextjs/qO-QQHZSrusIn2aqjwXBf/.next/server,
    NEXTAUTH_URL=$NEXTJS_URL,
    COGNITO_ISSUER=$ISSUER_URL,
    COGNITO_CLIENT_ID=$CLIENT_ID,
    AWS_LWA_INVOKE_MODE=response_stream,
    READINESS_CHECK_PATH=http://127.0.0.1:3000/api/health
  }" \
  --region us-east-1

echo "Environment variables updated successfully!"
