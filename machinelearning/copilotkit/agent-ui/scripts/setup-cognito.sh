#!/bin/bash
set -e

# Cognito Stack Setup Script
# This script deploys the Cognito User Pool for CopilotKit AgentCore authentication

# Configuration
REGION=${AWS_REGION:-us-east-1}
STACK_NAME="copilotkit-agentcore-cognito"
TEMPLATE_FILE="cloudformation/cognito.yml"
PROJECT_NAME="copilotkit-agentcore"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying Cognito stack...${NC}"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS CLI is not configured or credentials are invalid${NC}"
    echo "Please run 'aws configure' first"
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Deploy CloudFormation stack
echo -e "${BLUE}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --parameter-overrides \
    ProjectName=$PROJECT_NAME \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION \
  --no-fail-on-empty-changeset

echo ""
echo -e "${GREEN}✅ Cognito stack deployed successfully!${NC}"
echo ""

# Get stack outputs
echo -e "${BLUE}📋 Stack Outputs:${NC}"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs' \
  --output table

# Extract important values
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text)

CLIENT_ID=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
  --output text)

ISSUER_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`IssuerUrl`].OutputValue' \
  --output text)

HOSTED_UI_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`HostedUIUrl`].OutputValue' \
  --output text)

echo ""
echo -e "${BLUE}💾 Creating environment configuration files...${NC}"

# Create agent/.env (for future backend use)
mkdir -p agent
cat > agent/.env << EOF
# Cognito Configuration for Agent
COGNITO_USER_POOL_ID=${USER_POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_ISSUER=${ISSUER_URL}
AWS_REGION=${REGION}
EOF

echo -e "${GREEN}✅ Created: agent/.env${NC}"

# Create frontend/.env.local
mkdir -p frontend
cat > frontend/.env.local << EOF
# Cognito Configuration for Frontend
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_ISSUER=${ISSUER_URL}

# NextAuth Configuration
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# AWS Configuration
AWS_REGION=${REGION}

# AgentCore Runtime ARN (to be added after runtime deployment)
# AGENTCORE_RUNTIME_ARN=
EOF

echo -e "${GREEN}✅ Created: frontend/.env.local${NC}"

# Create a summary file
cat > cognito-setup-summary.txt << EOF
================================================
Cognito Setup Summary
================================================

Deployment Date: $(date)
AWS Region: ${REGION}
AWS Account ID: ${ACCOUNT_ID}

Stack Information:
- Stack Name: ${STACK_NAME}
- User Pool ID: ${USER_POOL_ID}
- Client ID: ${CLIENT_ID}

Important URLs:
- Issuer URL: ${ISSUER_URL}
- Hosted UI: ${HOSTED_UI_URL}

Next Steps:
1. Create a test user:
   ./scripts/create-test-user.sh

2. Test Cognito Hosted UI:
   Open: ${HOSTED_UI_URL}

3. Deploy AgentCore Runtime:
   ./scripts/build-agent.sh
   ./scripts/deploy.sh

Configuration files created:
- agent/.env
- frontend/.env.local

================================================
EOF

echo -e "${GREEN}✅ Created: cognito-setup-summary.txt${NC}"
echo ""

echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Create a test user:"
echo "   ./scripts/create-test-user.sh"
echo ""
echo "2. Test Cognito Hosted UI:"
echo "   ${HOSTED_UI_URL}"
echo ""
echo "3. Deploy AgentCore Runtime:"
echo "   ./scripts/build-agent.sh"
echo "   ./scripts/deploy.sh"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
