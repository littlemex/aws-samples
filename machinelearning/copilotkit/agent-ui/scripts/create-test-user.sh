#!/bin/bash
set -e

# Create Test User Script
# This script creates a test user in the Cognito User Pool

# Configuration
STACK_NAME="CopilotKitCognitoStack"
REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}👤 Create Test User in Cognito${NC}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured or credentials are invalid${NC}"
    echo "Please run 'aws configure' first"
    exit 1
fi

# Get User Pool ID from CloudFormation stack
echo -e "${BLUE}Retrieving User Pool ID...${NC}"
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
  --output text 2>/dev/null)

if [ -z "$USER_POOL_ID" ]; then
    echo -e "${RED}❌ Error: Could not find Cognito stack${NC}"
    echo "Please run ./scripts/setup-cognito.sh first"
    exit 1
fi

echo "User Pool ID: $USER_POOL_ID"
echo ""

# Generate a secure random password that meets Cognito requirements
# Format: {lowercase}{uppercase}{digit}{special}{random_chars}
generate_password() {
    # Generate components to ensure requirements are met
    local lower=$(tr -dc 'a-z' < /dev/urandom | head -c 3)
    local upper=$(tr -dc 'A-Z' < /dev/urandom | head -c 3)
    local digit=$(tr -dc '0-9' < /dev/urandom | head -c 2)
    local special=$(tr -dc '!@#$%^&*' < /dev/urandom | head -c 2)
    local random=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 6)
    
    # Combine and shuffle
    echo "${lower}${upper}${digit}${special}${random}" | fold -w1 | shuf | tr -d '\n'
}

# Generate default password
DEFAULT_PASSWORD=$(generate_password)

# Prompt for user information
echo -e "${BLUE}Enter user information:${NC}"
read -p "Email address: " EMAIL

# Validate email format
if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "${RED}❌ Invalid email format${NC}"
    exit 1
fi

# Prompt for password with auto-generated default
echo ""
echo -e "${YELLOW}Password requirements:${NC}"
echo "- Minimum 8 characters"
echo "- At least one uppercase letter"
echo "- At least one lowercase letter"
echo "- At least one number"
echo "- At least one special character"
echo ""
echo -e "${GREEN}Auto-generated password: ${DEFAULT_PASSWORD}${NC}"
echo -e "${BLUE}(Press Enter to use auto-generated password, or type your own)${NC}"
echo ""

read -sp "Password [${DEFAULT_PASSWORD}]: " USER_INPUT_PASSWORD
echo ""

# Use default if no input provided
if [ -z "$USER_INPUT_PASSWORD" ]; then
    TEMP_PASSWORD="$DEFAULT_PASSWORD"
    echo -e "${GREEN}✓ Using auto-generated password${NC}"
else
    TEMP_PASSWORD="$USER_INPUT_PASSWORD"
    
    # Validate custom password
    if [ ${#TEMP_PASSWORD} -lt 8 ]; then
        echo -e "${RED}❌ Password must be at least 8 characters${NC}"
        exit 1
    fi
    
    # Check for uppercase
    if ! [[ "$TEMP_PASSWORD" =~ [A-Z] ]]; then
        echo -e "${RED}❌ Password must contain at least one uppercase letter${NC}"
        exit 1
    fi
    
    # Check for lowercase
    if ! [[ "$TEMP_PASSWORD" =~ [a-z] ]]; then
        echo -e "${RED}❌ Password must contain at least one lowercase letter${NC}"
        exit 1
    fi
    
    # Check for digit
    if ! [[ "$TEMP_PASSWORD" =~ [0-9] ]]; then
        echo -e "${RED}❌ Password must contain at least one number${NC}"
        exit 1
    fi
    
    # Check for special character
    if ! [[ "$TEMP_PASSWORD" =~ [!\@\#\$\%\^\&\*] ]]; then
        echo -e "${RED}❌ Password must contain at least one special character (!@#\$%^&*)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Using custom password${NC}"
fi

echo ""
echo -e "${BLUE}Creating user...${NC}"

# Create user with temporary password
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username $EMAIL \
  --user-attributes \
    Name=email,Value=$EMAIL \
    Name=email_verified,Value=true \
  --temporary-password "$TEMP_PASSWORD" \
  --message-action SUPPRESS \
  --region $REGION

# Set permanent password immediately
echo -e "${BLUE}Setting permanent password...${NC}"
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username $EMAIL \
  --password "$TEMP_PASSWORD" \
  --permanent \
  --region $REGION

echo ""
echo -e "${GREEN}✅ User created successfully!${NC}"
echo ""
echo "User Details:"
echo "  Email: $EMAIL"
echo "  Password: $TEMP_PASSWORD"
echo "  Status: CONFIRMED"
echo ""

# Get Hosted UI URL
HOSTED_UI_URL=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`HostedUIUrl`].OutputValue' \
  --output text 2>/dev/null)

echo -e "${BLUE}📝 Next Steps:${NC}"
echo "1. Test login via Cognito Hosted UI:"
echo "   ${HOSTED_UI_URL}"
echo ""
echo "2. Or use with your application:"
echo "   Email: $EMAIL"
echo "   Password: (the one you just set)"
echo ""
echo -e "${YELLOW}⚠️  Important: Save these credentials securely!${NC}"
echo ""

# Create a user info file
cat > test-user-info.txt << EOF
================================================
Test User Information
================================================

Created: $(date)
Email: ${EMAIL}
Password: ${TEMP_PASSWORD}
Status: CONFIRMED

Hosted UI URL:
${HOSTED_UI_URL}

User Pool ID: ${USER_POOL_ID}

================================================
EOF

echo -e "${GREEN}✅ User information saved to: test-user-info.txt${NC}"
echo -e "${YELLOW}⚠️  Remember to secure or delete this file after testing!${NC}"
