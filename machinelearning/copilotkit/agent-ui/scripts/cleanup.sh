#!/bin/bash
set -e

# Cleanup Script
# This script removes all resources created for the CopilotKit AgentCore project

# Configuration
REGION=${AWS_REGION:-us-east-1}
COGNITO_STACK_NAME="copilotkit-agentcore-cognito"
RUNTIME_STACK_NAME="copilotkit-agentcore-runtime"
PROJECT_NAME="copilotkit-agentcore"
REPO_NAME="copilotkit-agentcore-agent"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  CopilotKit AgentCore Cleanup${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will delete ALL resources!${NC}"
echo "This includes:"
echo "  - Cognito User Pool and all users"
echo "  - AgentCore Runtime"
echo "  - ECR Repository and all images"
echo "  - CloudFormation stacks"
echo ""

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Starting cleanup...${NC}"
echo ""

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name $1 \
        --region $REGION \
        &> /dev/null
    return $?
}

# 1. Delete AgentCore Runtime Stack
if stack_exists $RUNTIME_STACK_NAME; then
    echo -e "${BLUE}Deleting AgentCore Runtime stack...${NC}"
    aws cloudformation delete-stack \
        --stack-name $RUNTIME_STACK_NAME \
        --region $REGION
    
    echo "Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete \
        --stack-name $RUNTIME_STACK_NAME \
        --region $REGION 2>/dev/null || true
    
    echo -e "${GREEN}✅ AgentCore Runtime stack deleted${NC}"
else
    echo -e "${YELLOW}ℹ️  AgentCore Runtime stack not found, skipping...${NC}"
fi

echo ""

# 2. Delete ECR Repository
echo -e "${BLUE}Checking for ECR repository...${NC}"
if aws ecr describe-repositories \
    --repository-names $REPO_NAME \
    --region $REGION \
    &> /dev/null; then
    
    echo "Deleting ECR repository and all images..."
    aws ecr delete-repository \
        --repository-name $REPO_NAME \
        --region $REGION \
        --force
    
    echo -e "${GREEN}✅ ECR repository deleted${NC}"
else
    echo -e "${YELLOW}ℹ️  ECR repository not found, skipping...${NC}"
fi

echo ""

# 3. Delete Cognito Stack
if stack_exists $COGNITO_STACK_NAME; then
    echo -e "${BLUE}Deleting Cognito stack...${NC}"
    aws cloudformation delete-stack \
        --stack-name $COGNITO_STACK_NAME \
        --region $REGION
    
    echo "Waiting for stack deletion..."
    aws cloudformation wait stack-delete-complete \
        --stack-name $COGNITO_STACK_NAME \
        --region $REGION 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cognito stack deleted${NC}"
else
    echo -e "${YELLOW}ℹ️  Cognito stack not found, skipping...${NC}"
fi

echo ""

# 4. Clean up local files
echo -e "${BLUE}Cleaning up local configuration files...${NC}"

# List of files to remove
LOCAL_FILES=(
    "agent/.env"
    "frontend/.env.local"
    "cognito-setup-summary.txt"
    "test-user-info.txt"
)

for file in "${LOCAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "  Deleted: $file"
    fi
done

echo -e "${GREEN}✅ Local files cleaned up${NC}"
echo ""

# 5. Summary
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "The following resources have been removed:"
echo "  ✅ Cognito User Pool (${COGNITO_STACK_NAME})"
echo "  ✅ AgentCore Runtime (${RUNTIME_STACK_NAME})"
echo "  ✅ ECR Repository (${REPO_NAME})"
echo "  ✅ Local configuration files"
echo ""
echo "Your AWS account has been cleaned up."
echo ""
echo -e "${BLUE}To rebuild the project, run:${NC}"
echo "  ./scripts/setup-cognito.sh"
echo ""
