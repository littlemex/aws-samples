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
LOCAL_MODE=false
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

Phase 4: dbt-style Analytics Views Creation on Redshift via Zero-ETL

OPTIONS:
    -p, --pattern PATTERN         Zero-ETL pattern (required)
                                 Options: aurora-postgresql, aurora-mysql, rds-mysql
    -c, --config CONFIG_FILE      JSON configuration file (required)
    
    # Step-by-step workflow:
    --step1                     Step 1: Setup dbt environment on Bastion Host
    --step2                     Step 2: Create dbt-style analytics Views in Redshift
    --step3                     Step 3: Verify created Views and show analytics results
    
    # Bastion Host operations:
    --bastion-command COMMAND   Execute command on Bastion Host via SSM
    --skip-copy                Skip file transfer to Bastion Host (use existing workspace)
    
    # Local mode operations:
    --local                     Execute commands in local Docker environment instead of Bastion Host
    
    --dry-run                   Show what would be executed without running
    -h, --help                  Show this help message

EXAMPLES:
    # AWS environment (Bastion Host) workflow:
    $0 -p aurora-postgresql -c config.json --step1   # Setup dbt on Bastion
    $0 -p aurora-postgresql -c config.json --step2   # Create dbt models
    $0 -p aurora-postgresql -c config.json --step3   # Test dbt models

    # Local Docker environment workflow:
    $0 -p aurora-postgresql -c config.json --local --step1   # Verify local dbt
    $0 -p aurora-postgresql -c config.json --local --step2   # Create models locally
    $0 -p aurora-postgresql -c config.json --local --step3   # Test models locally

    # Custom dbt command (local):
    $0 -p aurora-postgresql -c config.json --local --bastion-command "dbt run --select all_users"

    # Manual dbt command execution (remote):
    $0 -p aurora-postgresql -c config.json --bastion-command "scripts/4-dbt-execute.sh config.json 'dbt run'"
    
    # Phase 4 SQL execution (unified authentication):
    $0 -p aurora-postgresql -c config.json --bastion-command "scripts/4-sql-execute.sh config.json sql/redshift/verification/verify-zero-etl-all-users.sql"
    $0 -p aurora-postgresql -c config.json --skip-copy --bastion-command "scripts/4-sql-execute.sh config.json sql/redshift/verification/verify-zero-etl-all-users.sql"
    
    # Any Redshift query with unified authentication:
    $0 -p aurora-postgresql -c config.json --bastion-command "psql -h \$REDSHIFT_HOST -p \$REDSHIFT_PORT -U \$REDSHIFT_USER -d dev -c 'SELECT COUNT(*) FROM analytics_analytics.zero_etl_all_users;'"

PREREQUISITES:
    Phase 1, 2, and 3 must be completed first:
    ./1-etl-manager.sh -p PATTERN -c CONFIG_FILE   # Aurora infrastructure
    ./2-etl-manager.sh -p PATTERN -c CONFIG_FILE   # Data population
    ./3-etl-manager.sh -p PATTERN -c CONFIG_FILE --step1 --step2 --step3   # Zero-ETL integration
    
    Zero-ETL database 'multitenant_analytics_zeroetl' must exist with tenant data.

DESCRIPTION:
    Phase 4 creates simple dbt-style analytics Views on Redshift Serverless using the 
    Zero-ETL integrated database. This demonstrates basic analytics capabilities without 
    full dbt framework complexity.

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
        --local)
            LOCAL_MODE=true
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

print_info "=== dbt Analytics Phase 4 ==="
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
    
    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is not installed"
        exit 1
    fi
    
    # Check if Phase 3 bastion configuration exists
    if [[ ! -f "bastion-redshift-connection.json" ]]; then
        print_warning "bastion-redshift-connection.json not found"
        print_info "Please run Phase 3 Step 2 first:"
        print_info "  ./3-etl-manager.sh -p $PATTERN -c $CONFIG_FILE --step2"
    fi
    
    print_success "Prerequisites check passed"
}

# Function to get Bastion Host instance ID from CloudFormation (from Phase 3)
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

# Function to read config and get directories to transfer (Phase4 specific)
get_transfer_directories() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file" >&2
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not found, using default directories" >&2
        echo "sql/redshift/dbt"
        return 1
    fi
    
    # Extract Phase4 specific bastion configuration
    local auto_transfer_enabled=$(jq -r '.bastion.phase4.autoTransfer.enabled // false' "$config_file" 2>/dev/null)
    
    if [[ "$auto_transfer_enabled" == "true" ]]; then
        local directories=$(jq -r '.bastion.phase4.autoTransfer.directories[]? // empty' "$config_file" 2>/dev/null)
        echo "$directories"
        return 0
    else
        return 1
    fi
}

# Function to create directory archive for transfer (Phase4 specific)
create_directory_archive() {
    local config_file="$1"
    local archive_path="/tmp/dbt-workspace-$(date +%s).tar.gz"
    
    print_info "Creating dbt directory and file archive for transfer..." >&2
    
    # Get directories to transfer for Phase 4
    local directories=$(get_transfer_directories "$config_file")
    local has_directories=false
    if [[ $? -eq 0 ]] && [[ -n "$directories" ]]; then
        has_directories=true
    fi
    
    # Get individual files to transfer (Phase4 specific)
    local files=""
    if command -v jq >/dev/null 2>&1; then
        files=$(jq -r '.bastion.phase4.autoTransfer.files[]? // empty' "$config_file" 2>/dev/null)
    fi
    
    # If no phase4 specific files configured, fall back to phase4 files list
    if [[ -z "$files" ]]; then
        files="config.json scripts/4-dbt-execute.sh bastion-redshift-connection.json"
    fi
    
    # Check if we have anything to transfer
    if [[ "$has_directories" == false ]] && [[ -z "$files" ]]; then
        print_info "No directories or files configured for auto-transfer" >&2
        return 1
    fi
    
    # Get exclude patterns
    local exclude_patterns=""
    if command -v jq >/dev/null 2>&1; then
        local patterns=$(jq -r '.bastion.phase4.autoTransfer.excludePatterns[]? // empty' "$config_file" 2>/dev/null)
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

# Function to transfer workspace to Bastion (from Phase3, adapted for Phase4)
transfer_workspace_to_bastion() {
    local bastion_instance_id="$1"
    local archive_path="$2"
    local workspace_dir="$3"
    local region=$(get_aws_region)
    
    print_info "Transferring dbt workspace to Bastion Host..."
    
    # Check archive size before proceeding
    local archive_size=$(stat -c%s "$archive_path" 2>/dev/null || echo "0")
    print_info "[DEBUG] Archive size: $archive_size bytes"
    
    if [[ $archive_size -gt 1048576 ]]; then  # 1MB limit for base64 encoding
        print_error "Archive too large for transfer ($archive_size bytes). Consider reducing files."
        return 1
    fi
    
    # Encode archive as base64
    local archive_b64=$(base64 -w 0 < "$archive_path")
    local b64_length=${#archive_b64}
    print_info "[DEBUG] Base64 encoded size: $b64_length characters"
    
    # Create setup command for directory transfer
    local setup_command="mkdir -p $workspace_dir && cd $workspace_dir && echo 'Starting dbt workspace setup...' && echo '$archive_b64' | base64 -d > dbt-archive.tar.gz && echo 'Base64 decode completed, extracting...' && tar -xzf dbt-archive.tar.gz && rm -f dbt-archive.tar.gz && echo 'Setting execute permissions...' && chmod +x scripts/*.sh 2>/dev/null || true && echo 'dbt workspace transfer completed successfully'"
    
    # Execute setup
    local setup_command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$setup_command\"]}" \
        --comment "dbt Workspace Transfer" \
        --timeout-seconds 300 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -n "$setup_command_id" ]]; then
        print_info "Waiting for dbt workspace transfer completion..."
        aws ssm wait command-executed \
            --command-id "$setup_command_id" \
            --instance-id "$bastion_instance_id" \
            --region "$region" || {
            print_warning "dbt workspace transfer may have timed out"
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
        
        print_info "[DEBUG] Transfer results:"
        if [[ -n "$transfer_output" ]] && [[ "$transfer_output" != "None" ]]; then
            print_info "  Output: $transfer_output"
        fi
        if [[ -n "$transfer_error" ]] && [[ "$transfer_error" != "None" ]]; then
            print_warning "  Error: $transfer_error"
        fi
        
        print_success "dbt workspace transfer completed"
    fi
}

# Function to execute command via SSM (from Phase3)
execute_ssm_command() {
    local bastion_instance_id="$1"
    local command="$2"
    local region="$3"
    
    print_info "Executing dbt command via SSM..."
    
    # Capture start time
    local start_time=$(date +%s)
    
    # Execute command
    local command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$command\"]}" \
        --comment "Redshift dbt Command" \
        --timeout-seconds 600 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -z "$command_id" ]]; then
        print_error "Failed to initiate SSM command"
        return 1
    fi
    
    print_info "SSM Command ID: $command_id"
    print_info "Waiting for dbt command completion..."
    
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
    print_info "=== DBT COMMAND OUTPUT ==="
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
        print_success "dbt command executed successfully on Bastion Host!"
        return 0
    else
        print_error "dbt command failed on Bastion Host with exit code: ${exit_code:-unknown}"
        return 1
    fi
}

# Function to get Redshift connection information for Phase 4
get_redshift_connection_info() {
    local connection_file="bastion-redshift-connection.json"
    
    print_info "Loading Redshift connection information for Phase 4..."
    
    # Check if connection file exists
    if [[ ! -f "$connection_file" ]]; then
        print_warning "Connection file not found: $connection_file"
        print_info "Phase 4 commands may not have Redshift connection info"
        return 1
    fi
    
    # Validate jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not available, skipping Redshift connection setup"
        return 1
    fi
    
    # Extract connection information
    local host=$(jq -r '.connection.host // empty' "$connection_file" 2>/dev/null)
    local port=$(jq -r '.connection.port // 5439' "$connection_file" 2>/dev/null)
    local user=$(jq -r '.connection.username // "admin"' "$connection_file" 2>/dev/null)
    local password=$(jq -r '.connection.password // empty' "$connection_file" 2>/dev/null)
    
    # Set connection variables if available
    if [[ -n "$host" ]] && [[ "$host" != "null" ]]; then
        export REDSHIFT_HOST="$host"
        export REDSHIFT_PORT="$port"
        export REDSHIFT_USER="$user"
        export REDSHIFT_PASSWORD="$password"
        
        print_success "Phase 4 Redshift connection configured:"
        print_info "  REDSHIFT_HOST=$REDSHIFT_HOST"
        print_info "  REDSHIFT_PORT=$REDSHIFT_PORT"
        print_info "  REDSHIFT_USER=$REDSHIFT_USER"
        print_info "  REDSHIFT_PASSWORD=***set***"
        return 0
    else
        print_warning "Could not load Redshift connection info from $connection_file"
        return 1
    fi
}

# Function to execute command on Bastion Host via SSM (Generic - similar to 2-etl-manager.sh)
execute_bastion_command() {
    local command="$1"
    local bastion_instance_id="$2"
    local region=$(get_aws_region)
    
    print_info "=== BASTION HOST COMMAND EXECUTION ==="
    print_info "Instance ID: $bastion_instance_id"
    print_info "Command: $command"
    print_info "Region: $region"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would execute command on Bastion Host"
        return 0
    fi
    
    # Get Redshift connection info for Phase 4
    get_redshift_connection_info
    
    # Handle file transfer or skip-copy logic
    local workspace_dir="/tmp/workspace"
    
    if [[ "$SKIP_COPY" == true ]]; then
        print_info "Skipping file transfer (--skip-copy specified)"
        print_info "Using existing workspace: $workspace_dir"
        
        # Verify existing workspace directory exists
        local check_workspace_command="if [ -d $workspace_dir ]; then echo 'WORKSPACE: Directory exists'; ls -la $workspace_dir | head -10; else echo 'WORKSPACE: Directory does not exist'; fi"
        
        local check_command_id=$(aws ssm send-command \
            --instance-ids "$bastion_instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "{\"commands\":[\"$check_workspace_command\"]}" \
            --comment "Workspace Check" \
            --timeout-seconds 60 \
            --region "$region" \
            --query 'Command.CommandId' --output text)
        
        if [[ -n "$check_command_id" ]]; then
            aws ssm wait command-executed \
                --command-id "$check_command_id" \
                --instance-id "$bastion_instance_id" \
                --region "$region" 2>/dev/null || true
                
            local check_output=$(aws ssm get-command-invocation \
                --command-id "$check_command_id" \
                --instance-id "$bastion_instance_id" \
                --region "$region" \
                --query 'StandardOutputContent' --output text 2>/dev/null)
                
            if [[ -n "$check_output" ]] && [[ "$check_output" != "None" ]]; then
                if [[ "$check_output" == *"Directory does not exist"* ]]; then
                    print_warning "Workspace directory $workspace_dir does not exist on Bastion Host"
                    print_warning "You may need to run without --skip-copy first to transfer files"
                else
                    print_info "Workspace directory verified:"
                    echo "$check_output" | while read line; do
                        if [[ "$line" == *"WORKSPACE:"* ]]; then
                            print_info "  $line"
                        fi
                    done
                fi
            fi
        fi
        
        # Update command to run from workspace directory and set environment variables
        local env_vars=""
        if [[ -n "$REDSHIFT_HOST" ]]; then
            env_vars="export REDSHIFT_HOST='$REDSHIFT_HOST' REDSHIFT_PORT='$REDSHIFT_PORT' REDSHIFT_USER='$REDSHIFT_USER' REDSHIFT_PASSWORD='$REDSHIFT_PASSWORD' && "
        fi
        command="cd $workspace_dir && ${env_vars}$command"
        
    else
        # Create and transfer directory archive if configured
        local archive_path=""
        
        archive_path=$(create_directory_archive "$CONFIG_FILE")
        if [[ $? -eq 0 ]] && [[ -n "$archive_path" ]]; then
            print_info "Transferring directories to Bastion Host..."
            
            # Transfer and setup workspace
            transfer_workspace_to_bastion "$bastion_instance_id" "$archive_path" "$workspace_dir"
            
            # Clean up local archive  
            rm -f "$archive_path"
        fi
        
        # Update command to run from workspace directory and set environment variables
        local env_vars=""
        if [[ -n "$REDSHIFT_HOST" ]]; then
            env_vars="export REDSHIFT_HOST='$REDSHIFT_HOST' REDSHIFT_PORT='$REDSHIFT_PORT' REDSHIFT_USER='$REDSHIFT_USER' REDSHIFT_PASSWORD='$REDSHIFT_PASSWORD' && "
        fi
        command="cd $workspace_dir && ${env_vars}$command"
    fi
    
    # Capture start time
    local start_time=$(date +%s)
    
    print_info "Sending command via SSM..."
    
    # Execute command via SSM
    local command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$command\"]}" \
        --comment "Phase 4 Bastion Command: $(echo "$command" | head -c 50)..." \
        --timeout-seconds 600 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -z "$command_id" ]]; then
        print_error "Failed to initiate SSM command"
        exit 1
    fi
    
    print_info "SSM Command ID: $command_id"
    print_info "Waiting for command completion..."
    
    # Wait for command to complete
    aws ssm wait command-executed \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" || {
        print_warning "Command execution may have timed out"
    }
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
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

# Function to execute local docker command
execute_local_docker_command() {
    local command="$1"
    
    print_info "=== LOCAL DOCKER COMMAND EXECUTION ==="
    print_info "Command: $command"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would execute command in local Docker"
        return 0
    fi
    
    # Check if docker compose is available
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check if dbt-local container is running
    if ! docker compose ps dbt-local | grep -q "Up"; then
        print_error "dbt-local container is not running"
        print_info "Please start Docker environment first:"
        print_info "  docker compose up -d"
        exit 1
    fi
    
    # Capture start time
    local start_time=$(date +%s)
    
    print_info "Executing command in dbt-local container..."
    
    # Execute command in dbt-local container (working directory is /usr/app/dbt)
    local exit_code=0
    docker compose exec -T dbt-local bash -c "$command" || exit_code=$?
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_info "=== EXECUTION SUMMARY ==="
    print_info "Exit code: $exit_code"
    print_info "Execution time: ${duration}s"
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Command executed successfully in local Docker!"
        return 0
    else
        print_error "Command failed in local Docker with exit code: $exit_code"
        return 1
    fi
}

# Local mode step functions
step1_setup_dbt_environment_local() {
    print_info "=== STEP 1 (LOCAL): Setting up dbt Environment ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would setup dbt environment in local Docker"
        return 0
    fi
    
    print_info "Verifying dbt environment in local Docker..."
    
    if execute_local_docker_command "dbt debug"; then
        print_success "=== Step 1 (LOCAL) completed successfully ==="
        print_info "Next step: Run --local --step2 to create dbt models"
        print_info "dbt is available in local Docker container"
    else
        print_error "Step 1 (LOCAL) failed - dbt environment verification unsuccessful"
        return 1
    fi
}

step2_create_dbt_models_local() {
    print_info "=== STEP 2 (LOCAL): Creating dbt Analytics Models ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would run dbt models in local Docker"
        return 0
    fi
    
    print_info "Running dbt models in local Docker..."
    
    if execute_local_docker_command "dbt run"; then
        print_success "=== Step 2 (LOCAL) completed successfully ==="
        print_info "Next step: Run --local --step3 to test the dbt models"
    else
        print_error "Step 2 (LOCAL) failed - dbt run unsuccessful"
        return 1
    fi
}

step3_test_dbt_models_local() {
    print_info "=== STEP 3 (LOCAL): Testing dbt Models ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would test dbt models in local Docker"
        return 0
    fi
    
    print_info "Testing dbt models in local Docker..."
    
    if execute_local_docker_command "dbt test"; then
        print_success "=== Step 3 (LOCAL) completed successfully ==="
        print_success "🎉 Local dbt Analytics Setup Complete!"
        echo ""
        print_info "Your local dbt analytics models are now ready:"
        print_info "  ✅ dbt models executed successfully"
        print_info "  ✅ Multi-tenant data integration working"
        print_info "  ✅ Local PostgreSQL database"
        echo ""
        print_info "You can now:"
        print_info "  • Query dbt-generated models locally"
        print_info "  • Test changes before deploying to AWS"
        print_info "  • Run dbt docs generate for documentation"
        print_info "  • Extend with additional dbt models and tests"
    else
        print_error "Step 3 (LOCAL) failed - dbt test unsuccessful"
        return 1
    fi
}

# Function to execute dbt-specific command on Bastion Host via SSM (Phase4 dbt specific)
execute_bastion_dbt_command() {
    local command="$1"
    local region=$(get_aws_region)
    
    print_info "=== BASTION HOST DBT COMMAND EXECUTION ==="
    print_info "Command: $command"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would execute dbt command on Bastion Host"
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
        # Create and transfer directory archive
        local archive_path=""
        
        archive_path=$(create_directory_archive "$CONFIG_FILE")
        if [[ $? -eq 0 ]] && [[ -n "$archive_path" ]]; then
            print_info "Transferring dbt directories to Bastion Host..."
            
            # Transfer and setup workspace
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

# Step 1: Setup dbt environment on Bastion Host
step1_setup_dbt_environment() {
    print_info "=== STEP 1: Setting up dbt Environment on Bastion Host ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would setup dbt environment on Bastion Host"
        return 0
    fi
    
    print_info "Setting up dbt environment on Bastion Host..."
    
    # Execute dbt setup script from scripts directory
    if execute_bastion_dbt_command "scripts/setup-dbt-environment.sh"; then
        print_success "=== Step 1 completed successfully ==="
        print_info "Next step: Run --step2 to create dbt models"
        print_info "dbt-redshift is now available in: /tmp/dbt-venv/"
    else
        print_error "Step 1 failed - dbt environment setup unsuccessful"
        return 1
    fi
}

# Step 2: Create dbt-style analytics models
step2_create_dbt_models() {
    print_info "=== STEP 2: Creating dbt Analytics Models ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would run dbt models in Redshift"
        return 0
    fi
    
    # Execute dbt run command
    local dbt_run_command="scripts/4-dbt-execute.sh config.json 'dbt run'"
    
    print_info "Running dbt models with Zero-ETL integration..."
    
    if execute_bastion_dbt_command "$dbt_run_command"; then
        print_success "=== Step 2 completed successfully ==="
        print_info "Next step: Run --step3 to test the dbt models"
    else
        print_error "Step 2 failed - dbt run unsuccessful"
        return 1
    fi
}

# Step 3: Test dbt models and show results  
step3_test_dbt_models() {
    print_info "=== STEP 3: Testing dbt Models and Verification ==="
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would test dbt models in Redshift"
        return 0
    fi
    
    # Execute dbt test command
    local dbt_test_command="scripts/4-dbt-execute.sh config.json 'dbt test'"
    
    print_info "Testing dbt models..."
    
    if execute_bastion_dbt_command "$dbt_test_command"; then
        print_success "=== Step 3 completed successfully ==="
        print_success "🎉 Real dbt Analytics Setup Complete!"
        echo ""
        print_info "Your dbt analytics models are now ready:"
        print_info "  ✅ dbt models executed successfully"
        print_info "  ✅ Multi-tenant data integration working"
        print_info "  ✅ Zero-ETL integration providing real-time data"
        echo ""
        print_info "You can now:"
        print_info "  • Connect BI tools to Redshift Serverless"
        print_info "  • Query dbt-generated models for insights"  
        print_info "  • Run dbt docs generate to create documentation"
        print_info "  • Extend with additional dbt models and tests"
    else
        print_error "Step 3 failed - dbt test unsuccessful"
        return 1
    fi
}

# Main execution
main() {
    print_info "Starting dbt Analytics Phase 4 operations..."
    
    # Display mode
    if [[ "$LOCAL_MODE" == true ]]; then
        print_info "Mode: LOCAL (Docker)"
    else
        print_info "Mode: REMOTE (Bastion Host via SSM)"
    fi
    
    # Check prerequisites (skip for local mode)
    if [[ "$LOCAL_MODE" != true ]]; then
        check_prerequisites
    fi
    
    # Handle bastion command if specified
    if [[ -n "$BASTION_COMMAND" ]]; then
        if [[ "$LOCAL_MODE" == true ]]; then
            # Local mode: execute in Docker
            execute_local_docker_command "$BASTION_COMMAND"
        else
            # Remote mode: execute on Bastion Host
            local bastion_instance_id=$(get_bastion_instance_id)
            execute_bastion_command "$BASTION_COMMAND" "$bastion_instance_id"
        fi
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
        print_warning "  --step1         Setup dbt environment on Bastion Host"
        print_warning "  --step2         Create dbt-style analytics Views"
        print_warning "  --step3         Verify Views and show analytics results"
        print_warning "  --bastion-command  Execute custom dbt command on Bastion Host"
        echo ""
        show_usage
        exit 1
    fi
    
    # Execute step-based operations based on mode
    if [[ "$LOCAL_MODE" == true ]]; then
        # Local mode: execute in Docker
        if [[ "$STEP1" == true ]]; then
            step1_setup_dbt_environment_local
        fi
        
        if [[ "$STEP2" == true ]]; then
            step2_create_dbt_models_local
        fi
        
        if [[ "$STEP3" == true ]]; then
            step3_test_dbt_models_local
        fi
    else
        # Remote mode: execute on Bastion Host
        if [[ "$STEP1" == true ]]; then
            step1_setup_dbt_environment
        fi
        
        if [[ "$STEP2" == true ]]; then
            step2_create_dbt_models
        fi
        
        if [[ "$STEP3" == true ]]; then
            step3_test_dbt_models
        fi
    fi
    
    print_success "=== Phase 4 dbt Analytics operations completed successfully ==="
}

# Run main function
main "$@"
