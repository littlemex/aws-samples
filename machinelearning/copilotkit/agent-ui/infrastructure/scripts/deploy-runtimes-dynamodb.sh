#!/bin/bash
set -e

# デフォルト環境: dev
ENV=${NODE_ENV:-dev}

echo "=========================================="
echo "🚀 Deploying Runtimes DynamoDB Stack"
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
echo "🚀 Deploying CopilotKitRuntimesDynamoDBStack..."
NODE_ENV=$ENV npx cdk deploy CopilotKitRuntimesDynamoDBStack \
  --require-approval never \
  --outputs-file outputs-runtimes-dynamodb-${ENV}.json

echo ""
echo "=========================================="
echo "✅ Runtimes DynamoDB Stack deployed successfully!"
echo "=========================================="

# SSMパラメータを確認
echo ""
echo "📋 Checking SSM Parameters..."
TABLE_NAME=$(aws ssm get-parameter \
  --name "/copilotkit-agentcore/${ENV}/dynamodb/runtimes-table-name" \
  --query "Parameter.Value" \
  --output text 2>/dev/null || echo "Not found")

echo "Table Name: $TABLE_NAME"

echo ""
echo "📝 Next Steps:"
echo "1. Register runtimes using register-runtime.sh"
echo "   Example: ./scripts/register-runtime.sh --runtime-id runtime-local --name 'Local Dev' --url http://localhost:8081 --auth-type none"
echo "2. Update frontend environment variables:"
echo "   RUNTIMES_TABLE_NAME=$TABLE_NAME"
echo "3. Proceed with Phase 3B (API modifications)"
echo ""
