#!/bin/bash
set -e

# デフォルト環境: dev
ENV=${NODE_ENV:-dev}

echo "=========================================="
echo "🚀 Deploying Agents DynamoDB Stack"
echo "Environment: $ENV"
echo "=========================================="

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

# infrastructureディレクトリに移動
cd "$INFRA_DIR"

echo ""
echo "📦 Installing dependencies..."
npm install

echo ""
echo "🔨 Building CDK app..."
npm run build

echo ""
echo "🚀 Deploying CopilotKitAgentsDynamoDBStack..."
NODE_ENV=$ENV npx cdk deploy CopilotKitAgentsDynamoDBStack \
  --require-approval never \
  --outputs-file outputs-agents-dynamodb-${ENV}.json

echo ""
echo "=========================================="
echo "✅ Agents DynamoDB Stack deployed successfully!"
echo "=========================================="

# SSMパラメータを確認
echo ""
echo "📋 Checking SSM Parameters..."
TABLE_NAME=$(aws ssm get-parameter \
  --name "/copilotkit-agentcore/${ENV}/dynamodb/agents-table-name" \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "Not found")

TABLE_ARN=$(aws ssm get-parameter \
  --name "/copilotkit-agentcore/${ENV}/dynamodb/agents-table-arn" \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "Not found")

echo "Table Name: $TABLE_NAME"
echo "Table ARN: $TABLE_ARN"

echo ""
echo "📝 Next Steps:"
echo "1. Update frontend environment variables:"
echo "   AGENTS_TABLE_NAME=$TABLE_NAME"
echo "2. Grant Lambda IAM permissions to access the DynamoDB table"
echo "3. Deploy API endpoints in Phase 2"
echo ""
