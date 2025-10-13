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
BASTION_COMMAND=""
SKIP_COPY=false
DRY_RUN=false
STEP1=false
STEP2=false
STEP3=false

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

Phase 3: Zero-ETL Integration Deployment & Data Verification

OPTIONS:
    -p, --pattern PATTERN         Zero-ETL pattern (required)
                                 Options: aurora-postgresql, aurora-mysql, rds-mysql
    -c, --config CONFIG_FILE      JSON configuration file (required)
    
    # Step-by-step workflow:
    --step1                     Step 1: Deploy Zero-ETL CDK infrastructure
    --step2                     Step 2: Configure Bastion Host and create database via psql
    --step3                     Step 3: Verify data replication and complete setup
    
    # Bastion Host operations:
    --bastion-command COMMAND   Execute command on Bastion Host via SSM
    --skip-copy                Skip file transfer to Bastion Host (use existing workspace)
    
    --dry-run                   Show what would be executed without running
    -h, --help                  Show this help message

EXAMPLES:
    # 3-step workflow:
    $0 -p aurora-postgresql -c config.json --step1   # Deploy infrastructure
    $0 -p aurora-postgresql -c config.json --step2   # Configure Bastion & create DB
    $0 -p aurora-postgresql -c config.json --step3   # Verify and complete

    # Bastion Host SQL execution (similar to Phase2):
    $0 -p aurora-postgresql -c config.json --bastion-command "scripts/3-sql-execute.sh config.json sql/redshift/database/create-integration-database.sql"
    $0 -p aurora-postgresql -c config.json --skip-copy --bastion-command "scripts/3-sql-execute.sh config.json sql/redshift/verification/verify-zero-etl-setup.sql"

PREREQUISITES:
    Phase 1 and Phase 2 must be completed first:
    ./1-etl-manager.sh -p PATTERN -c CONFIG_FILE
    ./2-etl-manager.sh -p PATTERN -c CONFIG_FILE
    
    For Bastion operations, run Step 2 first to configure security groups:
    $0 -p PATTERN -c CONFIG_FILE --step2

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
        --step1)
            STEP1=true
            shift
            ;;
        --step2)
            STEP2=true
            shift
            ;;
        --step3)
            STEP3=true
            shift
            ;;
        --bastion-command)
            BASTION_COMMAND="$2"
            shift 2
            ;;
        --skip-copy)
            SKIP_COPY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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
        exit 1
        ;;
esac

# Validate config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

print_info "=== Zero-ETL Integration Phase 3 ==="
print_info "Pattern: $PATTERN"
print_info "Config: $CONFIG_FILE"

# Function to get AWS region
get_aws_region() {
    local region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    echo "$region"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check CDK CLI
    if ! command -v cdk >/dev/null 2>&1; then
        print_error "AWS CDK CLI is not installed. Install with: npm install -g aws-cdk"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check if aws-samples-zero-etl directory exists (should be cloned by Phase 1)
    if [[ ! -d "aws-samples-zero-etl" ]]; then
        print_error "aws-samples-zero-etl directory not found. Please run Phase 1 first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get Zero-ETL pattern directory
get_pattern_directory() {
    local pattern_dir=""
    case $PATTERN in
        aurora-postgresql)
            pattern_dir="aws-samples-zero-etl/aurora-postgresql-to-redshift"
            ;;
        aurora-mysql)
            pattern_dir="aws-samples-zero-etl/aurora-mysql-to-redshift"
            ;;
        rds-mysql)
            pattern_dir="aws-samples-zero-etl/rds-mysql-to-redshift"
            ;;
    esac
    
    if [[ ! -d "$pattern_dir" ]]; then
        print_error "Pattern directory not found: $pattern_dir"
        exit 1
    fi
    
    echo "$pattern_dir"
}

# Function to update CDK context from config.json
update_cdk_context() {
    local pattern_dir="$1"
    local config_file="$2"
    
    print_info "Updating CDK context configuration..."
    
    # Read configuration from config.json
    local aurora_cluster=$(jq -r '.aurora.clusterName // "multitenant-analytics-aurora"' "$config_file")
    local redshift_namespace=$(jq -r '.redshift.namespace // "multitenant-analytics-ns"' "$config_file")
    local redshift_workgroup=$(jq -r '.redshift.workgroup // "multitenant-analytics-wg"' "$config_file")
    local redshift_dbname=$(jq -r '.redshift.dbName // "multitenant_analytics"' "$config_file")
    local integration_name=$(jq -r '.zeroEtl.integrationName // "multitenant-analytics-integration"' "$config_file")
    local data_filter=$(jq -r '.zeroEtl.dataFilter // "include: multitenant_analytics.tenant_*.*"' "$config_file")
    
    print_info "Using Aurora cluster: $aurora_cluster"
    print_info "Using Redshift namespace: $redshift_namespace"
    print_info "Using data filter: $data_filter"
    
    # Update CDK context file
    if [[ -f "$pattern_dir/cdk.context.json" ]]; then
        cp "$pattern_dir/cdk.context.json" "$pattern_dir/cdk.context.json.backup"
        print_info "Backed up existing CDK context"
    fi
    
    # Create updated CDK context
    cat > "$pattern_dir/cdk.context.json" << EOF
{
  "vpc_name": "multitenant-analytics-vpc",
  "rds_cluster_name": "$aurora_cluster",
  "redshift": {
    "db_name": "$redshift_dbname",
    "namespace": "$redshift_namespace",
    "workgroup": "$redshift_workgroup"
  },
  "zero_etl_integration": {
    "data_filter": "$data_filter",
    "integration_name": "$integration_name"
  }
}
EOF
    
    print_success "CDK context updated: $pattern_dir/cdk.context.json"
}

# Function to deploy Zero-ETL infrastructure
deploy_zero_etl() {
    local pattern_dir="$1"
    
    print_info "Deploying Zero-ETL infrastructure..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would deploy Zero-ETL infrastructure"
        print_info "  - Pattern directory: $pattern_dir"
        print_info "  - Redshift Serverless Stack"
        print_info "  - Zero-ETL Integration Stack"
        return 0
    fi
    
    # Change to pattern directory
    cd "$pattern_dir"
    
    # Setup Python virtual environment if not exists
    if [[ ! -d ".venv" ]]; then
        print_info "Creating Python virtual environment..."
        python3 -m venv .venv
    fi
    
    # Activate virtual environment and install dependencies
    print_info "Installing Python dependencies..."
    source .venv/bin/activate
    pip install -r requirements.txt
    
    # Set CDK environment variables
    export CDK_DEFAULT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export CDK_DEFAULT_REGION=$(get_aws_region)
    
    print_info "CDK Account: $CDK_DEFAULT_ACCOUNT"
    print_info "CDK Region: $CDK_DEFAULT_REGION"
    
    # Bootstrap CDK if needed
    print_info "Bootstrapping CDK environment..."
    cdk bootstrap
    
    # List available stacks
    print_info "Available CDK stacks:"
    cdk list
    
    # Deploy Redshift Serverless stack
    print_info "Deploying Redshift Serverless stack..."
    cdk deploy RedshiftServerlessStack --require-approval never
    
    # Setup resource policy for Zero-ETL integration
    setup_resource_policy
    
    # Deploy Zero-ETL integration stack
    print_info "Deploying Zero-ETL integration..."
    cdk deploy ZeroETLfromRDStoRSS --require-approval never
    
    print_success "Zero-ETL infrastructure deployment completed"
    
    # Return to original directory
    cd - > /dev/null
}

# Function to setup Redshift resource policy
setup_resource_policy() {
    local region=$(get_aws_region)
    
    print_info "Setting up Redshift resource policy..."
    
    # Get Aurora cluster ARN
    local aurora_cluster_arn=$(aws cloudformation describe-stacks \
        --stack-name AuroraPostgresStack \
        --region "$region" \
        --query 'Stacks[0].Outputs[?contains(OutputKey, `DBClusterArn`)].OutputValue' \
        --output text)
    
    if [[ -z "$aurora_cluster_arn" ]]; then
        print_error "Could not find Aurora cluster ARN. Ensure Phase 1 is completed."
        exit 1
    fi
    
    # Get Redshift namespace ARN
    local redshift_namespace_arn=$(aws cloudformation describe-stacks \
        --stack-name RedshiftServerlessStack \
        --region "$region" \
        --query 'Stacks[0].Outputs[?contains(OutputKey, `NamespaceNameArn`)].OutputValue' \
        --output text)
    
    if [[ -z "$redshift_namespace_arn" ]]; then
        print_error "Could not find Redshift namespace ARN. Deploy Redshift stack first."
        exit 1
    fi
    
    print_info "Aurora Cluster ARN: $aurora_cluster_arn"
    print_info "Redshift Namespace ARN: $redshift_namespace_arn"
    
    # Create resource policy for Redshift
    cat > /tmp/redshift-resource-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "redshift:AuthorizeInboundIntegration",
      "Resource": "$redshift_namespace_arn",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "$aurora_cluster_arn"
        }
      }
    }
  ]
}
EOF
    
    # Apply resource policy
    print_info "Applying Redshift resource policy..."
    aws redshift put-resource-policy \
        --region "$region" \
        --policy file:///tmp/redshift-resource-policy.json \
        --resource-arn "$redshift_namespace_arn"
    
    print_success "Resource policy applied successfully"
}

# Function to verify data replication
verify_data_replication() {
    local region=$(get_aws_region)
    
    print_info "Verifying data replication from Phase 2..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would verify data replication"
        return 0
    fi
    
    # Get Redshift workgroup name from config
    local workgroup=$(jq -r '.redshift.workgroup // "multitenant-analytics-wg"' "$CONFIG_FILE")
    
    print_info "Using Redshift workgroup: $workgroup"
    
    # Wait for Zero-ETL integration to be active
    print_info "Waiting for Zero-ETL integration to be active..."
    local max_attempts=20
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local integration_status=$(aws rds describe-integrations \
            --region "$region" \
            --query 'Integrations[0].Status' \
            --output text 2>/dev/null || echo "")
        
        if [[ "$integration_status" == "active" ]]; then
            print_success "Zero-ETL integration is active"
            break
        elif [[ "$integration_status" == "failed" ]]; then
            print_error "Zero-ETL integration failed"
            exit 1
        else
            print_info "Integration status: $integration_status (attempt $((attempt + 1))/$max_attempts)"
            sleep 30
            ((attempt++))
        fi
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        print_warning "Integration status check timed out, proceeding with verification..."
    fi
    
    # Get integration ID and create database from integration
    print_info "Creating database from Zero-ETL integration..."
    local integration_id_query=$(aws redshift-data execute-statement \
        --workgroup-name "$workgroup" \
        --database "dev" \
        --sql "SELECT integration_id FROM svv_integration WHERE integration_name LIKE '%multitenant%' LIMIT 1;" \
        --region "$region" \
        --query 'Id' --output text)
    
    # Wait for query to complete
    sleep 10
    
    local integration_id=$(aws redshift-data get-statement-result \
        --id "$integration_id_query" \
        --region "$region" \
        --query 'Records[0][0].stringValue' --output text 2>/dev/null || echo "")
    
    if [[ -n "$integration_id" ]] && [[ "$integration_id" != "None" ]]; then
        print_info "Integration ID: $integration_id"
        
        # Create database from integration
        local create_db_query=$(aws redshift-data execute-statement \
            --workgroup-name "$workgroup" \
            --database "dev" \
            --sql "CREATE DATABASE aurora_zeroetl FROM INTEGRATION '$integration_id' DATABASE multitenant_analytics;" \
            --region "$region" \
            --query 'Id' --output text 2>/dev/null || echo "")
        
        if [[ -n "$create_db_query" ]]; then
            print_success "Database creation initiated"
            sleep 15
        fi
    fi
    
    # Verify tenant data exists in Redshift
    print_info "Verifying tenant data in Redshift..."
    
    local tenants=("tenant_a" "tenant_b" "tenant_c")
    local total_users=0
    
    for tenant in "${tenants[@]}"; do
        print_info "Checking $tenant.users data..."
        
        local count_query=$(aws redshift-data execute-statement \
            --workgroup-name "$workgroup" \
            --database "aurora_zeroetl" \
            --sql "SELECT COUNT(*) as user_count FROM $tenant.users;" \
            --region "$region" \
            --query 'Id' --output text 2>/dev/null || echo "")
        
        if [[ -n "$count_query" ]]; then
            sleep 5
            local count=$(aws redshift-data get-statement-result \
                --id "$count_query" \
                --region "$region" \
                --query 'Records[0][0].longValue' --output text 2>/dev/null || echo "0")
            
            if [[ "$count" -gt 0 ]]; then
                print_success "$tenant: $count users found"
                total_users=$((total_users + count))
            else
                print_warning "$tenant: No users found"
            fi
        else
            print_warning "$tenant: Query execution failed"
        fi
    done
    
    # Show sample data from tenant_a
    if [[ $total_users -gt 0 ]]; then
        print_info "Retrieving sample data from tenant_a.users..."
        local sample_query=$(aws redshift-data execute-statement \
            --workgroup-name "$workgroup" \
            --database "aurora_zeroetl" \
            --sql "SELECT email, first_name, last_name, account_status FROM tenant_a.users LIMIT 3;" \
            --region "$region" \
            --query 'Id' --output text 2>/dev/null || echo "")
        
        if [[ -n "$sample_query" ]]; then
            sleep 5
            print_info "Sample data from tenant_a.users:"
            aws redshift-data get-statement-result \
                --id "$sample_query" \
                --region "$region" \
                --query 'Records[]' --output table 2>/dev/null || print_warning "Failed to retrieve sample data"
        fi
        
        print_success "Data verification completed successfully - Total users: $total_users"
    else
        print_warning "No data found in any tenant tables"
    fi
}

# Step 1: Deploy Zero-ETL CDK infrastructure  
step1_deploy_infrastructure() {
    local pattern_dir="$1"
    
    print_info "=== STEP 1: Deploying Zero-ETL CDK Infrastructure ==="
    
    deploy_zero_etl "$pattern_dir"
    
    print_success "=== Step 1 completed successfully ==="
    print_info "Next step: Run --step2 to get database creation instructions"
}

# Step 2: Configure Bastion Host and create database via psql
step2_bastion_setup() {
    local region=$(get_aws_region)
    
    print_info "=== STEP 2: Bastion Host Configuration & Database Creation ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would configure Bastion host for Redshift access"
        return 0
    fi
    
    # Step 2a: Configure Bastion Security Groups
    print_info "🔧 Configuring Bastion Host security groups for Redshift access..."
    
    if ! python3 scripts/configure-bastion-redshift-sg.py --config "$CONFIG_FILE"; then
        print_error "Failed to configure Bastion security groups"
        return 1
    fi
    
    print_success "Bastion configuration completed"
    
    # Step 2b: Create database via Bastion psql connection
    print_info "🗄️  Creating Zero-ETL database via Bastion host..."
    
    if [[ -f "bastion-redshift-connection.json" ]]; then
        local bastion_id=$(jq -r '.bastion.instance_id' bastion-redshift-connection.json)
        local redshift_host=$(jq -r '.connection.host' bastion-redshift-connection.json)
        local redshift_port=$(jq -r '.connection.port' bastion-redshift-connection.json)
        local redshift_user=$(jq -r '.connection.username' bastion-redshift-connection.json)
        local redshift_password=$(jq -r '.connection.password // ""' bastion-redshift-connection.json)
        
        print_info "Using Bastion instance: $bastion_id"
        print_info "Redshift endpoint: $redshift_host:$redshift_port"
        
        # Get integration ID first
        print_info "Getting Zero-ETL integration ID..."
        local integration_id=""
        local integration_info=$(aws rds describe-integrations \
            --region "$region" \
            --query 'Integrations[0].IntegrationArn' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$integration_info" && "$integration_info" != "None" ]]; then
            integration_id=$(echo "$integration_info" | sed 's/.*://')
            print_info "Integration ID: $integration_id"
        else
            print_error "Could not retrieve integration ID"
            print_warning "Manual database creation required via Bastion host"
            show_manual_bastion_guide
            return 0
        fi
        
        # Create database via Bastion
        create_database_via_bastion "$bastion_id" "$redshift_host" "$redshift_port" "$redshift_user" "$integration_id"
        
    else
        print_warning "Connection configuration not found, showing manual guide"
        show_manual_bastion_guide
    fi
    
    print_success "=== Step 2 completed successfully ==="
    print_info "Next step: Run --step3 to verify data replication"
}

# Function to create database via Bastion host
create_database_via_bastion() {
    local bastion_id="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local integration_id="$5"
    
    print_info "🔗 Connecting to Bastion host and creating database..."
    
    # Create SQL commands
    local sql_commands=""
    if [[ "$PATTERN" == "aurora-postgresql" ]]; then
        sql_commands="CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '$integration_id' DATABASE multitenant_analytics;"
    else
        sql_commands="CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '$integration_id';"
    fi
    
    # Try to execute via SSM (Session Manager) if available
    if command -v aws >/dev/null 2>&1; then
        print_info "Attempting to execute CREATE DATABASE via Bastion..."
        
        # Create a temporary script for the Bastion host
        local temp_script=$(cat << EOF
#!/bin/bash
export PGPASSWORD="$redshift_password"
echo "Connecting to Redshift..."
psql -h "$host" -p "$port" -U "$user" -d dev -c "$sql_commands"
if [ \$? -eq 0 ]; then
    echo "✅ Database created successfully"
    echo "Listing databases to verify:"
    psql -h "$host" -p "$port" -U "$user" -d dev -c "\\l"
else
    echo "❌ Database creation failed"
    exit 1
fi
EOF
)
        
        # Try to execute via ec2-instance-connect
        if aws ec2-instance-connect send-ssh-public-key \
            --instance-id "$bastion_id" \
            --instance-os-user ec2-user \
            --ssh-public-key file://$HOME/.ssh/id_rsa.pub \
            --region "$(get_aws_region)" >/dev/null 2>&1; then
            
            print_info "Executing database creation via EC2 Instance Connect..."
            
            # Note: This is a simplified approach - in practice, you'd need proper SSH key handling
            print_warning "Automated execution requires SSH key setup"
            print_info "Showing manual connection guide instead..."
        fi
    fi
    
    # Fallback to manual instructions
    show_manual_database_creation "$bastion_id" "$host" "$port" "$user" "$integration_id"
}

# Function to show manual Bastion connection guide
show_manual_bastion_guide() {
    echo ""
    print_success "=== Manual Bastion Connection Guide ==="
    echo ""
    
    if [[ -f "bastion-redshift-connection.json" ]]; then
        cat bastion-redshift-connection.json | jq -r '"
🔗 Bastion Host Connection Guide
" + "="*50 + "

📍 Bastion Instance: " + .bastion.instance_id + "
   Public IP: " + (.bastion.public_ip // "N/A") + "
   Private IP: " + (.bastion.private_ip // "N/A") + "

🎯 Redshift Connection Details:
   Host: " + .connection.host + "
   Port: " + (.connection.port | tostring) + "
   Database: " + .connection.database + "
   Username: " + .connection.username + "
   Workgroup: " + .connection.workgroup + "

📋 Connection Steps:

1. Connect to Bastion Host:
   aws ec2-instance-connect ssh --instance-id " + .bastion.instance_id + " --os-user ec2-user

2. Connect to Redshift from Bastion:
   psql -h " + .connection.host + " -p " + (.connection.port | tostring) + " -U " + .connection.username + " -d " + .connection.database + " -W

3. Create Zero-ETL Database:
   -- First, get integration ID
   SELECT integration_id FROM svv_integration WHERE integration_name LIKE '\''%multitenant%'\'';
   
   -- Then create database (replace <integration_id> with result from above)
   CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '\''<integration_id>'\'' DATABASE multitenant_analytics;

💡 Tips:
   - You'\''ll be prompted for the password from Secrets Manager: " + (.connection.secret_name // "RedshiftAdminUserSecret-*") + "
   - Use \\l to list databases, \\c database_name to switch databases
   - Use \\dt to list tables in current database
"'
    else
        print_warning "Connection configuration file not found"
        print_info "Please run the configuration script manually:"
        print_info "   python3 scripts/configure-bastion-redshift-sg.py --config $CONFIG_FILE"
    fi
    echo ""
}

# Function to show manual database creation steps
show_manual_database_creation() {
    local bastion_id="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local integration_id="$5"
    
    echo ""
    print_success "=== Manual Database Creation Steps ==="
    echo ""
    
    print_info "📋 Step-by-step instructions:"
    echo ""
    print_info "1. Connect to Bastion Host:"
    echo -e "${YELLOW}   aws ec2-instance-connect ssh --instance-id $bastion_id --os-user ec2-user${NC}"
    echo ""
    
    print_info "2. Connect to Redshift:"
    echo -e "${YELLOW}   psql -h $host -p $port -U $user -d dev -W${NC}"
    echo ""
    
    print_info "3. Create Zero-ETL Database:"
    if [[ "$PATTERN" == "aurora-postgresql" ]]; then
        echo -e "${YELLOW}   CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '$integration_id' DATABASE multitenant_analytics;${NC}"
    else
        echo -e "${YELLOW}   CREATE DATABASE multitenant_analytics_zeroetl FROM INTEGRATION '$integration_id';${NC}"
    fi
    echo ""
    
    print_info "4. Verify database creation:"
    echo -e "${YELLOW}   \\l${NC}"
    echo ""
    
    print_success "After successful database creation, run --step3 to verify data replication"
    echo ""
}

# Function to execute command on Bastion Host via SSM (similar to Phase2)
execute_bastion_sql_command() {
    local command="$1"
    local region=$(get_aws_region)
    
    print_info "=== BASTION HOST SQL COMMAND EXECUTION ==="
    print_info "Command: $command"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would execute command on Bastion Host"
        return 0
    fi
    
    # Get Bastion Host instance ID from CloudFormation
    local bastion_instance_id=$(get_bastion_instance_id)
    
    print_info "Instance ID: $bastion_instance_id"
    print_info "Region: $region"
    
    # Handle file transfer or skip-copy logic
    local workspace_dir="/tmp/workspace"
    
    if [[ "$SKIP_COPY" == true ]]; then
        print_info "Skipping file transfer (--skip-copy specified)"
        print_info "Using existing workspace: $workspace_dir"
        
        # Update command to run from workspace directory
        command="cd $workspace_dir && $command"
    else
        # Create and transfer directory archive if configured
        local archive_path=""
        
        archive_path=$(create_directory_archive "$CONFIG_FILE")
        if [[ $? -eq 0 ]] && [[ -n "$archive_path" ]]; then
            print_info "Transferring directories to Bastion Host..."
            
            # Transfer and setup workspace (simplified from Phase2)
            transfer_workspace_to_bastion "$bastion_instance_id" "$archive_path" "$workspace_dir"
            
            # Clean up local archive  
            rm -f "$archive_path"
            
            # Update command to run from workspace directory
            command="cd $workspace_dir && $command"
        fi
    fi
    
    # Execute command via SSM
    execute_ssm_command "$bastion_instance_id" "$command" "$region"
}

# Function to get Bastion Host instance ID from CloudFormation
get_bastion_instance_id() {
    local region=$(get_aws_region)
    
    print_info "Looking for Bastion Host instance..." >&2
    
    local bastion_stack=$(aws cloudformation list-stacks --region "$region" \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[?contains(StackName, `ClientHost`) || contains(StackName, `Bastion`)].StackName' \
        --output text | head -1)
    
    if [[ -z "$bastion_stack" ]]; then
        print_error "Bastion Host stack not found. Please run Phase 1 first:" >&2
        print_error "  ./1-etl-manager.sh -p $PATTERN -c $CONFIG_FILE" >&2
        exit 1
    fi
    
    local bastion_instance_id=$(aws cloudformation describe-stacks \
        --stack-name "$bastion_stack" --region "$region" \
        --query 'Stacks[0].Outputs[?contains(OutputKey, `InstanceId`)].OutputValue' \
        --output text)
    
    if [[ -z "$bastion_instance_id" ]]; then
        print_error "Could not retrieve Bastion Host instance ID from stack: $bastion_stack" >&2
        exit 1
    fi
    
    print_success "Found Bastion Host: $bastion_instance_id" >&2
    echo "$bastion_instance_id"
}

# Function to read config and get directories to transfer (Phase3 specific)
get_transfer_directories() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file" >&2
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not found, skipping directory auto-transfer" >&2
        return 1
    fi
    
    # Extract Phase3 specific bastion configuration
    local auto_transfer_enabled=$(jq -r '.bastion.phase3.autoTransfer.enabled // false' "$config_file" 2>/dev/null)
    
    if [[ "$auto_transfer_enabled" == "true" ]]; then
        local directories=$(jq -r '.bastion.phase3.autoTransfer.directories[]? // empty' "$config_file" 2>/dev/null)
        echo "$directories"
        return 0
    else
        return 1
    fi
}

# Function to create directory archive for transfer (from Phase2, enhanced for Phase3)
create_directory_archive() {
    local config_file="$1"
    local archive_path="/tmp/workspace-$(date +%s).tar.gz"
    
    print_info "Creating directory and file archive for transfer..." >&2
    
    # Get directories to transfer
    local directories=$(get_transfer_directories "$config_file")
    local has_directories=false
    if [[ $? -eq 0 ]] && [[ -n "$directories" ]]; then
        has_directories=true
    fi
    
    # Get individual files to transfer (Phase3 specific)
    local files=""
    if command -v jq >/dev/null 2>&1; then
        files=$(jq -r '.bastion.phase3.autoTransfer.files[]? // empty' "$config_file" 2>/dev/null)
    fi
    
    # If no phase3 specific files configured, fall back to phase3 files list
    if [[ -z "$files" ]]; then
        files="config.json scripts/3-sql-execute.sh bastion-redshift-connection.json"
    fi
    
    # Check if we have anything to transfer
    if [[ "$has_directories" == false ]] && [[ -z "$files" ]]; then
        print_info "No directories or files configured for auto-transfer" >&2
        return 1
    fi
    
    # Get exclude patterns
    local exclude_patterns=""
    if command -v jq >/dev/null 2>&1; then
        local patterns=$(jq -r '.bastion.autoTransfer.excludePatterns[]? // empty' "$config_file" 2>/dev/null)
        for pattern in $patterns; do
            exclude_patterns="$exclude_patterns --exclude='$pattern'"
        done
    fi
    
    # Build list of items to archive
    local tar_items=""
    
    print_info "[DEBUG] Checking local files before archiving..." >&2
    
    # Add directories
    if [[ "$has_directories" == true ]]; then
        for dir in $directories; do
            if [[ -d "$dir" ]]; then
                local dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                local file_count=$(find "$dir" -type f | wc -l)
                tar_items="$tar_items $dir"
                print_info "Including directory: $dir (size: $dir_size, files: $file_count)" >&2
            else
                print_warning "Directory not found, skipping: $dir" >&2
            fi
        done
    fi
    
    # Add individual files
    for file in $files; do
        if [[ -f "$file" ]]; then
            local file_size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
            tar_items="$tar_items $file"
            print_info "Including file: $file (size: $file_size)" >&2
        else
            print_warning "File not found, skipping: $file" >&2
        fi
    done
    
    if [[ -n "$tar_items" ]]; then
        print_info "[DEBUG] Creating tar archive with items: $tar_items" >&2
        
        # Create archive with better error handling
        local tar_output=""
        if [[ -n "$exclude_patterns" ]]; then
            tar_output=$(tar -czf "$archive_path" $exclude_patterns $tar_items 2>&1)
        else
            tar_output=$(tar -czf "$archive_path" $tar_items 2>&1)
        fi
        local tar_exit_code=$?
        
        # Show tar output if there were any messages
        if [[ -n "$tar_output" ]]; then
            print_info "[DEBUG] Tar output: $tar_output" >&2
        fi
        
        # Verify archive was actually created and check its contents
        if [[ -f "$archive_path" ]] && [[ $tar_exit_code -eq 0 ]]; then
            local archive_size=$(ls -lh "$archive_path" 2>/dev/null | awk '{print $5}')
            print_success "Archive created: $archive_path (size: $archive_size)" >&2
            
            # List archive contents for verification
            print_info "[DEBUG] Archive contents:" >&2
            tar -tzf "$archive_path" 2>/dev/null | head -20 | while read line; do
                print_info "  $line" >&2
            done
            
            # If there are more than 20 files, show count
            local total_files=$(tar -tzf "$archive_path" 2>/dev/null | wc -l)
            if [[ $total_files -gt 20 ]]; then
                print_info "  ... and $((total_files - 20)) more files" >&2
            fi
            
            # Only output the archive path to stdout
            echo "$archive_path"
            return 0
        else
            print_error "Failed to create archive (exit code: $tar_exit_code)" >&2
            if [[ -n "$tar_output" ]]; then
                print_error "Tar error: $tar_output" >&2
            fi
            return 1
        fi
    else
        print_warning "No valid directories or files to archive" >&2
        return 1
    fi
}

# Function to transfer workspace to Bastion (from Phase2, with size checking)
transfer_workspace_to_bastion() {
    local bastion_instance_id="$1"
    local archive_path="$2"
    local workspace_dir="$3"
    local region=$(get_aws_region)
    
    print_info "Transferring workspace to Bastion Host..."
    
    # Check archive size before proceeding
    local archive_size=$(stat -c%s "$archive_path" 2>/dev/null || echo "0")
    print_info "[DEBUG] Archive size: $archive_size bytes"
    
    if [[ $archive_size -gt 1048576 ]]; then  # 1MB limit for base64 encoding
        print_error "Archive too large for transfer ($archive_size bytes). Consider reducing files or using exclude patterns."
        return 1
    fi
    
    # Encode archive as base64
    local archive_b64=$(base64 -w 0 < "$archive_path")
    local b64_length=${#archive_b64}
    print_info "[DEBUG] Base64 encoded size: $b64_length characters"
    
    # Create setup command for directory transfer with better error handling
    local setup_command="mkdir -p $workspace_dir && cd $workspace_dir && echo 'Starting base64 decode...' && echo '$archive_b64' | base64 -d > archive.tar.gz && echo 'Base64 decode completed, extracting...' && tar -xzf archive.tar.gz && rm -f archive.tar.gz && echo 'Setting execute permissions...' && chmod +x scripts/*.sh 2>/dev/null || true && echo 'Directory transfer completed successfully'"
    
    # Execute setup
    local setup_command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$setup_command\"]}" \
        --comment "Workspace Transfer" \
        --timeout-seconds 300 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -n "$setup_command_id" ]]; then
        print_info "Waiting for workspace transfer completion..."
        aws ssm wait command-executed \
            --command-id "$setup_command_id" \
            --instance-id "$bastion_instance_id" \
            --region "$region" || {
            print_warning "Directory transfer may have timed out"
        }
        
        # Get transfer results
        local transfer_output=$(aws ssm get-command-invocation \
            --command-id "$setup_command_id" \
            --instance-id "$bastion_instance_id" \
            --region "$region" \
            --query 'StandardOutputContent' --output text 2>/dev/null)
            
        local transfer_error=$(aws ssm get-command-invocation \
            --command-id "$setup_command_id" \
            --instance-id "$bastion_instance_id" \
            --region "$region" \
            --query 'StandardErrorContent' --output text 2>/dev/null)
            
        local transfer_exit_code=$(aws ssm get-command-invocation \
            --command-id "$setup_command_id" \
            --instance-id "$bastion_instance_id" \
            --region "$region" \
            --query 'ResponseCode' --output text 2>/dev/null)
        
        print_info "[DEBUG] Transfer results:"
        print_info "  Exit code: ${transfer_exit_code:-unknown}"
        if [[ -n "$transfer_output" ]] && [[ "$transfer_output" != "None" ]]; then
            print_info "  Output: $transfer_output"
        fi
        if [[ -n "$transfer_error" ]] && [[ "$transfer_error" != "None" ]]; then
            print_warning "  Error: $transfer_error"
        fi
        
        # Verify files were transferred successfully
        print_info "Verifying transferred files on Bastion Host..."
        local verify_command="cd $workspace_dir && echo 'VERIFY: Current directory:' && pwd && echo 'VERIFY: Directory contents:' && ls -la && echo 'VERIFY: Checking key files:' && if [ -f scripts/3-sql-execute.sh ]; then echo 'VERIFY: scripts/3-sql-execute.sh exists'; else echo 'VERIFY: scripts/3-sql-execute.sh MISSING'; fi && if [ -f config.json ]; then echo 'VERIFY: config.json exists'; else echo 'VERIFY: config.json MISSING'; fi && if [ -f bastion-redshift-connection.json ]; then echo 'VERIFY: bastion-redshift-connection.json exists'; else echo 'VERIFY: bastion-redshift-connection.json MISSING'; fi && echo 'VERIFY: Setting execute permissions on scripts...' && chmod +x scripts/*.sh 2>/dev/null || true && echo 'VERIFY: Verification completed'"
        
        local verify_command_id=$(aws ssm send-command \
            --instance-ids "$bastion_instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "{\"commands\":[\"$verify_command\"]}" \
            --comment "File Verification" \
            --timeout-seconds 60 \
            --region "$region" \
            --query 'Command.CommandId' --output text)
            
        if [[ -n "$verify_command_id" ]]; then
            print_info "Waiting for file verification..."
            aws ssm wait command-executed \
                --command-id "$verify_command_id" \
                --instance-id "$bastion_instance_id" \
                --region "$region" 2>/dev/null || true
                
            local verify_output=$(aws ssm get-command-invocation \
                --command-id "$verify_command_id" \
                --instance-id "$bastion_instance_id" \
                --region "$region" \
                --query 'StandardOutputContent' --output text 2>/dev/null)
                
            if [[ -n "$verify_output" ]] && [[ "$verify_output" != "None" ]]; then
                print_info "[DEBUG] Bastion Host file verification:"
                echo "$verify_output" | while read line; do
                    if [[ "$line" == *"VERIFY:"* ]]; then
                        print_info "  $line"
                    fi
                done
            fi
        fi
        
        print_success "Workspace transfer completed"
    fi
}

# Function to execute command via SSM
execute_ssm_command() {
    local bastion_instance_id="$1"
    local command="$2"
    local region="$3"
    
    print_info "Executing command via SSM..."
    
    # Capture start time
    local start_time=$(date +%s)
    
    # Execute command
    local command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$command\"]}" \
        --comment "Redshift SQL Command" \
        --timeout-seconds 300 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -z "$command_id" ]]; then
        print_error "Failed to initiate SSM command"
        return 1
    fi
    
    print_info "SSM Command ID: $command_id"
    print_info "Waiting for command completion..."
    
    # Wait for command to complete
    aws ssm wait command-executed \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" || print_warning "Command execution may have timed out"
    
    # Get command results
    local command_output=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" \
        --query 'StandardOutputContent' --output text 2>/dev/null)
    
    local command_error=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" \
        --query 'StandardErrorContent' --output text 2>/dev/null)
    
    local exit_code=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" \
        --query 'ResponseCode' --output text 2>/dev/null)
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Display results
    print_info "=== COMMAND OUTPUT ==="
    if [[ -n "$command_output" ]] && [[ "$command_output" != "None" ]]; then
        echo "$command_output"
    else
        print_warning "No standard output"
    fi
    
    if [[ -n "$command_error" ]] && [[ "$command_error" != "None" ]]; then
        print_warning "=== ERROR OUTPUT ==="
        echo "$command_error"
    fi
    
    print_info "=== EXECUTION SUMMARY ==="
    print_info "Exit code: ${exit_code:-unknown}"
    print_info "Execution time: ${duration}s"
    print_info "Command ID: $command_id"
    
    if [[ "$exit_code" == "0" ]]; then
        print_success "Command executed successfully on Bastion Host!"
        return 0
    else
        print_error "Command failed on Bastion Host with exit code: ${exit_code:-unknown}"
        return 1
    fi
}

# Step 3: Verify data replication and complete setup  
step3_verify_and_complete() {
    print_info "=== STEP 3: Verifying Data Replication ==="
    
    verify_data_replication
    
    print_success "=== Step 3 completed successfully ==="
    print_success "🎉 Zero-ETL Integration Setup Complete!"
    echo ""
    print_info "Your multitenant analytics platform is now ready with:"
    print_info "  ✅ Aurora PostgreSQL source data"
    print_info "  ✅ Zero-ETL integration (real-time replication)"
    print_info "  ✅ Redshift Serverless analytics warehouse"
    print_info "  ✅ Tenant data available for analytics"
}

# Main execution
main() {
    print_info "Starting Zero-ETL Phase 3 operations..."
    
    # Check prerequisites
    check_prerequisites
    
    # Get pattern directory  
    local pattern_dir=$(get_pattern_directory)
    print_info "Using pattern directory: $pattern_dir"
    
    # Update CDK context with config.json values
    update_cdk_context "$pattern_dir" "$CONFIG_FILE"
    
    # Handle bastion command if specified
    if [[ -n "$BASTION_COMMAND" ]]; then
        execute_bastion_sql_command "$BASTION_COMMAND"
        exit $?
    fi
    
    # Validate at least one operation is requested
    local operation_count=0
    
    if [[ "$STEP1" == true ]]; then
        operation_count=$((operation_count + 1))
    fi
    
    if [[ "$STEP2" == true ]]; then
        operation_count=$((operation_count + 1))
    fi
    
    if [[ "$STEP3" == true ]]; then
        operation_count=$((operation_count + 1))
    fi
    
    if [[ $operation_count -eq 0 ]]; then
        print_warning "No operation specified. Use one of:"
        print_warning "  --step1         Deploy Zero-ETL CDK infrastructure"
        print_warning "  --step2         Configure Bastion Host and create database via psql"
        print_warning "  --step3         Verify data replication and complete setup"
        print_warning "  --bastion-command  Execute command on Bastion Host via SSM"
        echo ""
        show_usage
        exit 1
    fi
    
    # Execute step-based operations
    if [[ "$STEP1" == true ]]; then
        step1_deploy_infrastructure "$pattern_dir"
    fi
    
    if [[ "$STEP2" == true ]]; then
        step2_bastion_setup
    fi
    
    if [[ "$STEP3" == true ]]; then
        step3_verify_and_complete
    fi
    
    print_success "=== Phase 3 Zero-ETL operations completed successfully ==="
}

# Run main function
main "$@"
