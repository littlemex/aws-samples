#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PATTERN=""
CONFIG_FILE=""
ENVIRONMENT="dev"
CLEANUP=false
DRY_RUN=false
SKIP_CLONE=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Phase 1: AWS Zero-ETL Infrastructure Deployment

OPTIONS:
    -p, --pattern PATTERN       Zero-ETL pattern to deploy (required)
                               Options: aurora-mysql, aurora-postgresql, rds-mysql
    -c, --config CONFIG_FILE    JSON configuration file (required)
    -e, --environment ENV       Environment name (default: dev)
    --cleanup                  Clean up resources (destroy stacks)
    --dry-run                  Show what would be deployed without actually deploying
    --skip-clone               Skip cloning AWS samples repository (use existing)
    -h, --help                 Show this help message

EXAMPLES:
    # Deploy Aurora PostgreSQL infrastructure
    $0 -p aurora-postgresql -c config/multitenant-analytics.json

    # Dry run to see what would be deployed
    $0 -p aurora-postgresql -c config/dev.json --dry-run

    # Clean up resources
    $0 -p aurora-postgresql -c config/dev.json --cleanup

SUPPORTED PATTERNS:
    - aurora-mysql: Aurora MySQL to Redshift Serverless
    - aurora-postgresql: Aurora PostgreSQL to Redshift Serverless  
    - rds-mysql: RDS MySQL to Redshift Serverless

NEXT STEPS:
    After Phase 1 completes successfully, run:
    ./2-etl-manager.sh -p PATTERN -c CONFIG_FILE --setup-database

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-clone)
            SKIP_CLONE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PATTERN" ]]; then
    print_error "Pattern is required. Use -p or --pattern option."
    show_usage
    exit 1
fi

if [[ -z "$CONFIG_FILE" ]]; then
    print_error "Configuration file is required. Use -c or --config option."
    show_usage
    exit 1
fi

# Validate pattern
case $PATTERN in
    aurora-mysql|aurora-postgresql|rds-mysql)
        ;;
    *)
        print_error "Invalid pattern: $PATTERN"
        print_error "Supported patterns: aurora-mysql, aurora-postgresql, rds-mysql"
        exit 1
        ;;
esac

# Validate config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Set directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
SAMPLES_DIR="$PROJECT_ROOT/aws-samples-zero-etl"
WORK_DIR=""

# Get absolute path of config file
CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"

# Map pattern to directory name
case $PATTERN in
    aurora-mysql)
        WORK_DIR="$SAMPLES_DIR/aurora-mysql-to-redshift"
        ;;
    aurora-postgresql)
        WORK_DIR="$SAMPLES_DIR/aurora-postgresql-to-redshift"
        ;;
    rds-mysql)
        WORK_DIR="$SAMPLES_DIR/rds-mysql-to-redshift"
        ;;
esac

print_info "=== AWS Zero-ETL Phase 1: Infrastructure Deployment ==="
print_info "Pattern: $PATTERN"
print_info "Config: $CONFIG_FILE"
print_info "Environment: $ENVIRONMENT"
print_info "Work Directory: $WORK_DIR"

# Function to check and install prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed and configured
    print_info "Checking AWS CLI..."
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    print_success "AWS CLI found"
    
    # Check AWS credentials
    print_info "Checking AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    print_success "AWS credentials configured"
    
    # Set default region if not configured
    local current_region=$(aws configure get region 2>/dev/null || echo "")
    if [[ -z "$current_region" ]]; then
        print_info "Setting default AWS region to us-east-1..."
        aws configure set region us-east-1
        export AWS_DEFAULT_REGION=us-east-1
    else
        export AWS_DEFAULT_REGION="$current_region"
    fi
    print_info "Using AWS region: $AWS_DEFAULT_REGION"
    
    # Check if CDK is installed, install if not
    if ! command -v cdk &> /dev/null; then
        print_info "Installing AWS CDK..."
        sudo npm install -g aws-cdk || {
            print_error "Failed to install AWS CDK. Please install Node.js and npm first."
            exit 1
        }
    fi
    
    # Check if Python 3 is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3."
        exit 1
    fi
    
    # Check if uv is installed
    if ! command -v uv &> /dev/null; then
        print_error "uv is not installed. Please install uv first: curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Install python3-venv if not available (for Ubuntu/Debian systems)
    if ! python3 -m venv --help &> /dev/null; then
        print_info "Installing python3-venv..."
        sudo apt update && sudo apt install -y python3.10-venv || {
            print_warning "Failed to install python3-venv automatically. This may be required for some environments."
        }
    fi
    
    print_success "All prerequisites met!"
}

# Function to clone AWS samples repository
clone_samples() {
    if [[ "$SKIP_CLONE" == true ]]; then
        print_info "Skipping clone as requested..."
        if [[ ! -d "$SAMPLES_DIR" ]]; then
            print_error "AWS samples directory not found: $SAMPLES_DIR"
            print_error "Run without --skip-clone to download the samples."
            exit 1
        fi
        return
    fi

    print_info "Cloning AWS Zero-ETL samples repository..."
    
    if [[ -d "$SAMPLES_DIR" ]]; then
        print_warning "Samples directory already exists. Updating..."
        cd "$SAMPLES_DIR"
        git pull origin main || {
            print_warning "Failed to update repository. Removing and re-cloning..."
            cd "$PROJECT_ROOT"
            rm -rf "$SAMPLES_DIR"
            git clone https://github.com/aws-samples/zero-etl-architecture-patterns.git aws-samples-zero-etl
        }
    else
        cd "$PROJECT_ROOT"
        git clone https://github.com/aws-samples/zero-etl-architecture-patterns.git aws-samples-zero-etl
    fi
    
    print_success "AWS samples repository ready!"
}

# Function to generate CDK context from JSON config
generate_cdk_context() {
    print_info "Generating CDK context from configuration..."
    
    local config_content=$(cat "$CONFIG_FILE")
    
    # Extract values from config and create cdk.context.json
    local vpc_name=$(echo "$config_content" | jq -r '.networking.vpcName // "default"')
    local rds_cluster_name=$(echo "$config_content" | jq -r '.aurora.clusterName // "multitenant-analytics-aurora"')
    local redshift_db_name=$(echo "$config_content" | jq -r '.redshift.dbName // "multitenant_analytics"')
    local redshift_namespace=$(echo "$config_content" | jq -r '.redshift.namespace // "multitenant-analytics-ns"')
    local redshift_workgroup=$(echo "$config_content" | jq -r '.redshift.workgroup // "multitenant-analytics-wg"')
    local integration_name=$(echo "$config_content" | jq -r '.zeroEtl.integrationName // "multitenant-analytics-integration"')
    local data_filter=$(echo "$config_content" | jq -r '.zeroEtl.dataFilter // ""')
    
    # Create cdk.context.json in the work directory
    # Handle empty data_filter by omitting it entirely
    if [[ -z "$data_filter" ]]; then
        cat > "$WORK_DIR/cdk.context.json" << EOF
{
  "vpc_name": "$vpc_name",
  "rds_cluster_name": "$rds_cluster_name",
  "redshift": {
    "db_name": "$redshift_db_name",
    "namespace": "$redshift_namespace",
    "workgroup": "$redshift_workgroup"
  },
  "zero_etl_integration": {
    "integration_name": "$integration_name"
  }
}
EOF
    else
        cat > "$WORK_DIR/cdk.context.json" << EOF
{
  "vpc_name": "$vpc_name",
  "rds_cluster_name": "$rds_cluster_name",
  "redshift": {
    "db_name": "$redshift_db_name",
    "namespace": "$redshift_namespace",
    "workgroup": "$redshift_workgroup"
  },
  "zero_etl_integration": {
    "data_filter": "$data_filter",
    "integration_name": "$integration_name"
  }
}
EOF
    fi

    print_success "CDK context generated: $WORK_DIR/cdk.context.json"
}

# Function to setup Python environment using uv
setup_python_env() {
    print_info "Setting up Python virtual environment with uv..."
    
    cd "$WORK_DIR"
    
    # Remove existing virtual environment to ensure clean setup
    if [[ -d ".venv" ]]; then
        print_info "Removing existing virtual environment..."
        rm -rf .venv
    fi
    
    # Create virtual environment with uv
    print_info "Creating virtual environment with uv..."
    uv venv .venv
    
    # Activate virtual environment
    source .venv/bin/activate
    
    # Install dependencies using uv
    print_info "Installing dependencies with uv..."
    uv pip install -r requirements.txt
    
    print_success "Python environment ready with uv!"
}

# Function to bootstrap CDK
bootstrap_cdk() {
    print_info "Bootstrapping AWS CDK..."
    
    cd "$WORK_DIR"
    source .venv/bin/activate
    
    # Set CDK environment variables
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$(aws configure get region)
    
    print_info "CDK Account: $CDK_DEFAULT_ACCOUNT"
    print_info "CDK Region: $CDK_DEFAULT_REGION"
    
    # Bootstrap CDK
    cdk bootstrap
    
    print_success "CDK bootstrapped successfully!"
}

# Function to deploy infrastructure only (Phase 1)
deploy_infrastructure() {
    print_info "Deploying infrastructure (Aurora + Redshift + Bastion Host)..."
    
    cd "$WORK_DIR"
    source .venv/bin/activate
    
    # Set CDK environment variables
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$(aws configure get region)
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would deploy infrastructure stacks..."
        cdk ls | grep -v -i zero
        return
    fi
    
    # Get list of stacks
    local stacks=$(cdk ls)
    print_info "Available infrastructure stacks:"
    echo "$stacks" | grep -v -i zero
    
    # Deploy infrastructure stacks in order (excluding Zero-ETL)
    print_info "Deploying VPC stack..."
    cdk deploy --require-approval never $(echo "$stacks" | grep -i vpc | head -1)
    
    print_info "Deploying Aurora stack..."
    cdk deploy --require-approval never $(echo "$stacks" | grep -i aurora | grep -v vpc | head -1)
    
    print_info "Deploying Client/Bastion host stack..."
    cdk deploy --require-approval never $(echo "$stacks" | grep -i client | head -1) || \
    cdk deploy --require-approval never $(echo "$stacks" | grep -i bastion | head -1) || true
    
    print_info "Deploying Redshift Serverless stack..."
    cdk deploy --require-approval never $(echo "$stacks" | grep -i redshift | head -1)
    
    print_success "Infrastructure deployed successfully!"
}

# Function to cleanup resources
cleanup_resources() {
    print_warning "Cleaning up resources..."
    
    cd "$WORK_DIR"
    source .venv/bin/activate
    
    # Set CDK environment variables
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$(aws configure get region)
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would destroy all stacks"
        cdk ls
        return
    fi
    
    print_warning "This will destroy all resources. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        cdk destroy --force --all
        print_success "Resources cleaned up!"
    else
        print_info "Cleanup cancelled."
    fi
}

# Function to show deployment info
show_deployment_info() {
    print_info "=== Phase 1 Deployment Information ==="
    
    cd "$WORK_DIR"
    source .venv/bin/activate
    
    # Set CDK environment variables
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$(aws configure get region)
    
    print_info "Stack Outputs:"
    
    # Get Aurora cluster information
    local aurora_stack=$(cdk ls | grep -i aurora | grep -v vpc | head -1)
    if [[ -n "$aurora_stack" ]]; then
        print_info "Aurora Cluster Information:"
        aws cloudformation describe-stacks --stack-name "$aurora_stack" --region "$CDK_DEFAULT_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`DBClusterEndpoint`].OutputValue' --output text || true
    fi
    
    # Get Redshift information
    local redshift_stack=$(cdk ls | grep -i redshift | head -1)
    if [[ -n "$redshift_stack" ]]; then
        print_info "Redshift Serverless Information:"
        aws cloudformation describe-stacks --stack-name "$redshift_stack" --region "$CDK_DEFAULT_REGION" \
            --query 'Stacks[0].Outputs' --output table || true
    fi
    
    # Get Bastion Host information
    local bastion_stack=$(aws cloudformation list-stacks --region "$CDK_DEFAULT_REGION" \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[?contains(StackName, `ClientHost`) || contains(StackName, `Bastion`)].StackName' \
        --output text | head -1)
    
    if [[ -n "$bastion_stack" ]]; then
        local bastion_instance_id=$(aws cloudformation describe-stacks \
            --stack-name "$bastion_stack" --region "$CDK_DEFAULT_REGION" \
            --query 'Stacks[0].Outputs[?contains(OutputKey, `InstanceId`)].OutputValue' \
            --output text)
        
        if [[ -n "$bastion_instance_id" ]]; then
            print_info "Bastion Host Instance ID: $bastion_instance_id"
        fi
    fi
    
    print_info "=== Next Steps ==="
    echo "Phase 1 completed successfully!"
    echo ""
    echo "Next step: Run Phase 2 for database setup"
    echo "  ./2-etl-manager.sh -p $PATTERN -c $CONFIG_FILE --setup-database"
    echo ""
    echo "Or test Bastion Host connection:"
    echo "  ./2-etl-manager.sh -p $PATTERN -c $CONFIG_FILE --bastion-command 'ls -la'"
}

# Main execution
main() {
    print_info "Starting Phase 1: Infrastructure Deployment..."
    
    check_prerequisites
    
    if [[ "$CLEANUP" == true ]]; then
        cleanup_resources
        exit 0
    fi
    
    clone_samples
    generate_cdk_context
    setup_python_env
    bootstrap_cdk
    deploy_infrastructure
    
    if [[ "$DRY_RUN" != true ]]; then
        show_deployment_info
    fi
    
    print_success "=== PHASE 1 COMPLETED ==="
    print_info "Infrastructure deployed successfully!"
}

# Run main function
main "$@"
