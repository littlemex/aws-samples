#!/bin/bash
set -e

echo "🧪 Testing SSM Parameter Store Access"
echo ""

# 変数設定
REGION="us-east-1"
PROJECT_NAME="copilotkit-agentcore"
CLIENT_SUFFIX="${1:-copilotkit}"
SSM_PREFIX="/${PROJECT_NAME}/${CLIENT_SUFFIX}"

echo "📋 Configuration:"
echo "   Region: $REGION"
echo "   Project: $PROJECT_NAME"
echo "   Client Suffix: $CLIENT_SUFFIX"
echo "   SSM Prefix: $SSM_PREFIX"
echo ""

# SSM Parameterリストを取得
echo "📁 Listing all parameters under ${SSM_PREFIX}..."
aws ssm get-parameters-by-path \
  --path "${SSM_PREFIX}" \
  --recursive \
  --region $REGION \
  --query "Parameters[*].[Name,Value]" \
  --output table

echo ""
echo "🔍 Detailed Parameter Values:"
echo ""

# 各パラメータを個別に取得
echo "1️⃣  User Pool ID:"
aws ssm get-parameter \
  --name "${SSM_PREFIX}/cognito/user-pool-id" \
  --region $REGION \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "   ❌ Not found"

echo ""
echo "2️⃣  Client ID:"
aws ssm get-parameter \
  --name "${SSM_PREFIX}/cognito/client-id" \
  --region $REGION \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "   ❌ Not found"

echo ""
echo "3️⃣  Issuer URL:"
aws ssm get-parameter \
  --name "${SSM_PREFIX}/cognito/issuer-url" \
  --region $REGION \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "   ❌ Not found"

echo ""
echo "4️⃣  Domain:"
aws ssm get-parameter \
  --name "${SSM_PREFIX}/cognito/domain" \
  --region $REGION \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "   ❌ Not found"

echo ""
echo "✅ SSM Parameter Store test complete!"
