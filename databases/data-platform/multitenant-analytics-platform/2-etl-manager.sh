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
UPLOAD_SCRIPT=""
DRY_RUN=false
LOCAL_EXECUTION=false
SKIP_COPY=false

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

Phase 2: Bastion Host Remote Command Execution & Aurora Data Operations

OPTIONS:
    -p, --pattern PATTERN       Zero-ETL pattern (required)
    -c, --config CONFIG_FILE    JSON configuration file (required)
    --bastion-command COMMAND   Execute command on Bastion Host via SSM or locally
    --upload-script SCRIPT      Upload and execute script file on Bastion Host
    --skip-copy                Skip file transfer to Bastion Host (use existing workspace)
    --local                    Execute commands locally with docker compose
    --dry-run                  Show what would be executed without running
    -h, --help                 Show this help message

EXAMPLES:
    # Remote Bastion Host operations
    $0 -p aurora-postgresql -c config.json --bastion-command "whoami"
    $0 -p aurora-postgresql -c config.json --upload-script "test-script.sh"

    # Skip file transfer for faster execution (requires previous transfer)
    $0 -p aurora-postgresql -c config.json --skip-copy --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql"

    # Local execution with docker compose
    $0 -p aurora-postgresql -c config.json --bastion-command "scripts/aurora-sql-execute.sh config.json sql/aurora/verification/verify-setup.sql" --local

    # Dry run mode
    $0 -p aurora-postgresql -c config.json --bastion-command "df -h" --dry-run

PREREQUISITES:
    For remote operations, Phase 1 must be completed first:
    ./1-etl-manager.sh -p PATTERN -c CONFIG_FILE
    
    For local operations, docker and docker compose must be installed.
    
    The --skip-copy option requires files to have been transferred previously.

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
        --bastion-command)
            BASTION_COMMAND="$2"
            shift 2
            ;;
        --upload-script)
            UPLOAD_SCRIPT="$2"
            shift 2
            ;;
        --local)
            LOCAL_EXECUTION=true
            shift
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

print_info "=== Bastion Host Remote Command Execution ==="
print_info "Pattern: $PATTERN"
print_info "Config: $CONFIG_FILE"

# Function to get AWS region
get_aws_region() {
    local region=$(aws configure get region 2>/dev/null || echo "us-east-1")
    echo "$region"
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

# Function to read config and get directories to transfer
get_transfer_directories() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not found, skipping directory auto-transfer"
        return 1
    fi
    
    # Extract Phase 2 specific bastion configuration
    local auto_transfer_enabled=$(jq -r '.bastion.phase2.autoTransfer.enabled // false' "$config_file" 2>/dev/null)
    
    if [[ "$auto_transfer_enabled" == "true" ]]; then
        local directories=$(jq -r '.bastion.phase2.autoTransfer.directories[]? // empty' "$config_file" 2>/dev/null)
        echo "$directories"
        return 0
    else
        return 1
    fi
}

# Function to create directory archive for transfer
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
    
    # Get individual files to transfer (Phase 2 specific)
    local files=""
    if command -v jq >/dev/null 2>&1; then
        files=$(jq -r '.bastion.phase2.autoTransfer.files[]? // empty' "$config_file" 2>/dev/null)
    fi
    
    # Check if we have anything to transfer
    if [[ "$has_directories" == false ]] && [[ -z "$files" ]]; then
        print_info "No directories or files configured for auto-transfer" >&2
        return 1
    fi
    
    # Get exclude patterns (Phase 2 specific)
    local exclude_patterns=""
    if command -v jq >/dev/null 2>&1; then
        local patterns=$(jq -r '.bastion.phase2.autoTransfer.excludePatterns[]? // empty' "$config_file" 2>/dev/null)
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

# Function to transfer files to Docker container based on config.json
transfer_files_to_docker_container() {
    local config_file="$1"
    local container_name="multitenant-analytics-platform-dbt-local-1"
    local container_path="/usr/app"
    
    print_info "=== DOCKER CONTAINER FILE TRANSFER ==="
    print_info "Config file: $config_file"
    print_info "Container: $container_name"
    print_info "Target path: $container_path"
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not found, using default file transfer"
        # Fallback: copy essential files
        docker cp config.json "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy config.json"
        docker cp sql/ "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy sql directory"
        docker cp scripts/ "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy scripts directory"
        return 0
    fi
    
    # Check if Phase 2 auto-transfer is enabled
    local auto_transfer_enabled=$(jq -r '.bastion.phase2.autoTransfer.enabled // false' "$config_file" 2>/dev/null)
    
    if [[ "$auto_transfer_enabled" != "true" ]]; then
        print_info "Auto-transfer not enabled in config, using default file transfer"
        # Fallback: copy essential files
        docker cp config.json "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy config.json"
        docker cp sql/ "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy sql directory"
        docker cp scripts/ "$container_name:$container_path/" 2>/dev/null || print_warning "Failed to copy scripts directory"
        return 0
    fi
    
    # Get directories to transfer (Phase 2 specific)
    local directories=$(jq -r '.bastion.phase2.autoTransfer.directories[]? // empty' "$config_file" 2>/dev/null)
    
    # Get individual files to transfer (Phase 2 specific)
    local files=$(jq -r '.bastion.phase2.autoTransfer.files[]? // empty' "$config_file" 2>/dev/null)
    
    # Get exclude patterns (Phase 2 specific)
    local exclude_patterns=$(jq -r '.bastion.phase2.autoTransfer.excludePatterns[]? // empty' "$config_file" 2>/dev/null)
    
    print_info "Transfer configuration:"
    print_info "  Directories: $(echo "$directories" | tr '\n' ' ')"
    print_info "  Files: $(echo "$files" | tr '\n' ' ')"
    print_info "  Exclude patterns: $(echo "$exclude_patterns" | tr '\n' ' ')"
    
    # Transfer directories
    local transfer_count=0
    for dir in $directories; do
        if [[ -d "$dir" ]]; then
            local dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local file_count=$(find "$dir" -type f | wc -l)
            print_info "Copying directory: $dir (size: $dir_size, files: $file_count)"
            
            # Create parent directory structure in container if needed
            local parent_dir=$(dirname "$dir")
            if [[ "$parent_dir" != "." ]]; then
                docker exec "$container_name" mkdir -p "$container_path/$parent_dir" 2>/dev/null || true
            fi
            
            if docker cp "$dir" "$container_name:$container_path/$dir"; then
                print_success "Successfully copied directory: $dir"
                transfer_count=$((transfer_count + 1))
            else
                print_warning "Failed to copy directory: $dir"
            fi
        else
            print_warning "Directory not found, skipping: $dir"
        fi
    done
    
    # Transfer individual files
    for file in $files; do
        if [[ -f "$file" ]]; then
            local file_size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
            print_info "Copying file: $file (size: $file_size)"
            
            # Create directory structure in container if needed
            local file_dir=$(dirname "$file")
            if [[ "$file_dir" != "." ]]; then
                docker exec "$container_name" mkdir -p "$container_path/$file_dir" 2>/dev/null || true
            fi
            
            if docker cp "$file" "$container_name:$container_path/$file"; then
                print_success "Successfully copied file: $file"
                transfer_count=$((transfer_count + 1))
            else
                print_warning "Failed to copy file: $file"
            fi
        else
            print_warning "File not found, skipping: $file"
        fi
    done
    
    # Set execute permissions on scripts
    print_info "Setting execute permissions on scripts..."
    docker exec "$container_name" bash -c "find $container_path/scripts -name '*.sh' -type f -exec chmod +x {} \; 2>/dev/null || true"
    
    # Verify transfer
    print_info "Verifying transferred files in Docker container..."
    local verify_output=$(docker exec "$container_name" bash -c "cd $container_path && echo 'VERIFY: Current directory:' && pwd && echo 'VERIFY: Directory contents:' && ls -la && echo 'VERIFY: Key files check:' && if [ -f config.json ]; then echo 'VERIFY: config.json exists'; else echo 'VERIFY: config.json MISSING'; fi && if [ -f scripts/aurora-sql-execute.sh ]; then echo 'VERIFY: scripts/aurora-sql-execute.sh exists'; else echo 'VERIFY: scripts/auora.sh MISSING'; fi && if [ -f sql/aurora/schema/create-tenant-schemas.sql ]; then echo 'VERIFY: sql/aurora/schema/create-tenant-schemas.sql exists'; else echo 'VERIFY: sql/aurora/schema/create-tenant-schemas.sql MISSING'; fi" 2>/dev/null)
    
    if [[ -n "$verify_output" ]]; then
        print_info "Docker container file verification:"
        echo "$verify_output" | while read line; do
            if [[ "$line" == *"VERIFY:"* ]]; then
                print_info "  $line"
            fi
        done
    fi
    
    print_success "File transfer to Docker container completed"
    print_info "Total items transferred: $transfer_count"
}

# Function to get Aurora connection information
get_aurora_connection_info() {
    local is_local_execution="$1"  # true for local, false for bastion
    local pattern="$2"
    local region=$(get_aws_region)
    
    if [[ "$is_local_execution" == "true" ]]; then
        # Local execution: use docker compose values
        print_info "Setting up local PostgreSQL connection..."
        export AURORA_ENDPOINT="localhost"
        export AURORA_USER="dbt_user" 
        export AURORA_PASSWORD="dbt_password"
        
        print_info "Local connection configured:"
        print_info "  AURORA_ENDPOINT=$AURORA_ENDPOINT"
        print_info "  AURORA_USER=$AURORA_USER"
        print_info "  AURORA_PASSWORD=***set***"
    else
        # Bastion execution: get Aurora info from AWS
        print_info "Retrieving Aurora connection information from AWS..."
        
        # Find Aurora stack by looking for stacks with Aurora cluster outputs
        print_info "Searching for Aurora stack with cluster outputs..."
        local aurora_stacks=$(aws cloudformation list-stacks --region "$region" \
            --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
            --query "StackSummaries[?contains(StackName, \`Aurora\`)].StackName" \
            --output text)
        
        local aurora_stack=""
        local aurora_endpoint=""
        local secret_name=""
        
        for stack in $aurora_stacks; do
            print_info "Checking stack: $stack"
            # Check if this stack has Aurora cluster outputs
            aurora_endpoint=$(aws cloudformation describe-stacks \
                --stack-name "$stack" --region "$region" \
                --query 'Stacks[0].Outputs[?contains(OutputKey, `DBClusterEndpoint`)].OutputValue' \
                --output text 2>/dev/null)
            
            secret_name=$(aws cloudformation describe-stacks \
                --stack-name "$stack" --region "$region" \
                --query 'Stacks[0].Outputs[?contains(OutputKey, `DBSecretName`)].OutputValue' \
                --output text 2>/dev/null)
                
            if [[ -n "$aurora_endpoint" ]]; then
                aurora_stack="$stack"
                print_info "Found Aurora stack: $aurora_stack"
                break
            fi
        done
        
        if [[ -z "$aurora_stack" ]]; then
            print_error "Aurora stack with cluster outputs not found"
            exit 1
        fi
        
        if [[ -z "$aurora_endpoint" ]]; then
            print_error "Could not retrieve Aurora endpoint from CloudFormation"
            exit 1
        fi
        
        if [[ -z "$secret_name" ]]; then
            print_error "Could not retrieve Aurora secret name from CloudFormation"
            exit 1
        fi
        
        print_info "Aurora endpoint: $aurora_endpoint"
        print_info "Secret name: $secret_name"
        
        # Get credentials from Secrets Manager
        local secret_json=$(aws secretsmanager get-secret-value \
            --secret-id "$secret_name" --region "$region" \
            --query 'SecretString' --output text)
        
        if [[ -z "$secret_json" ]]; then
            print_error "Could not retrieve Aurora credentials from Secrets Manager"
            exit 1
        fi
        
        # Parse username and password from secret JSON
        local aurora_user=$(echo "$secret_json" | jq -r '.username // "postgres"')
        local aurora_password=$(echo "$secret_json" | jq -r '.password')
        
        if [[ -z "$aurora_password" ]] || [[ "$aurora_password" == "null" ]]; then
            print_error "Could not parse Aurora password from secret"
            exit 1
        fi
        
        # Separate host and port from endpoint (format: host:port)
        local aurora_host="${aurora_endpoint%:*}"  # Remove :port suffix
        local aurora_port="${aurora_endpoint##*:}" # Extract port number
        
        # Validate that we actually have a port, otherwise use default
        if [[ "$aurora_port" == "$aurora_endpoint" ]] || [[ ! "$aurora_port" =~ ^[0-9]+$ ]]; then
            aurora_port="5432"  # Default PostgreSQL port
        fi
        
        # Export environment variables with separated host and port
        export AURORA_ENDPOINT="$aurora_host"
        export AURORA_PORT="$aurora_port"
        export AURORA_USER="$aurora_user"
        export AURORA_PASSWORD="$aurora_password"
        
        print_success "Aurora connection configured:"
        print_info "  AURORA_ENDPOINT=$AURORA_ENDPOINT"
        print_info "  AURORA_PORT=$AURORA_PORT"
        print_info "  AURORA_USER=$AURORA_USER"
        print_info "  AURORA_PASSWORD=***set***"
    fi
}

# Function to execute command on Bastion Host via SSM
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
    
    # Get Aurora connection info for remote execution
    get_aurora_connection_info "false" "$PATTERN"
    
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
        command="cd $workspace_dir && export AURORA_ENDPOINT='$AURORA_ENDPOINT' AURORA_PORT='$AURORA_PORT' AURORA_USER='$AURORA_USER' AURORA_PASSWORD='$AURORA_PASSWORD' && $command"
        
    else
        # Create and transfer directory archive if configured
        local archive_path=""
        
        archive_path=$(create_directory_archive "$CONFIG_FILE")
        if [[ $? -eq 0 ]] && [[ -n "$archive_path" ]]; then
            print_info "Transferring directories to Bastion Host..."
            
            # Encode archive as base64 (split into chunks to avoid command line length limits)
            local archive_size=$(stat -c%s "$archive_path" 2>/dev/null || echo "0")
            print_info "[DEBUG] Archive size: $archive_size bytes"
            
            if [[ $archive_size -gt 1048576 ]]; then  # 1MB limit for base64 encoding
                print_error "Archive too large for transfer ($archive_size bytes). Consider reducing files or using exclude patterns."
                return 1
            fi
            
            local archive_b64=$(base64 -w 0 < "$archive_path")
            local b64_length=${#archive_b64}
            print_info "[DEBUG] Base64 encoded size: $b64_length characters"
            
            # Create setup command for directory transfer with better error handling
            local setup_command="mkdir -p $workspace_dir && cd $workspace_dir && echo 'Starting base64 decode...' && echo '$archive_b64' | base64 -d > archive.tar.gz && echo 'Base64 decode completed, extracting...' && tar -xzf archive.tar.gz && rm -f archive.tar.gz && echo 'Directory transfer completed successfully'"
            
            # Execute directory setup
            print_info "Setting up workspace directories..."
            local setup_command_id=$(aws ssm send-command \
                --instance-ids "$bastion_instance_id" \
                --document-name "AWS-RunShellScript" \
                --parameters "{\"commands\":[\"$setup_command\"]}" \
                --comment "Directory Transfer Setup" \
                --timeout-seconds 300 \
                --region "$region" \
                --query 'Command.CommandId' --output text)
            
            if [[ -n "$setup_command_id" ]]; then
                print_info "Waiting for directory transfer completion..."
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
                # Use a simpler verification approach to avoid JSON escaping issues
                local verify_command="cd $workspace_dir && echo 'VERIFY: Current directory:' && pwd && echo 'VERIFY: Directory contents:' && ls -la && echo 'VERIFY: Checking key files:' && if [ -f scripts/aurora-sql-execute.sh ]; then echo 'VERIFY: scripts/aurora-sql-execute.sh exists'; else echo 'VERIFY: scripts/aurora-sql-execute.sh MISSING'; fi && if [ -f config.json ]; then echo 'VERIFY: config.json exists'; else echo 'VERIFY: config.json MISSING'; fi && if [ -f sql/aurora/schema/create-tenant-schemas.sql ]; then echo 'VERIFY: sql/aurora/schema/create-tenant-schemas.sql exists'; else echo 'VERIFY: sql/aurora/schema/create-tenant-schemas.sql MISSING'; fi && echo 'VERIFY: Setting execute permissions on scripts...' && chmod +x scripts/*.sh 2>/dev/null || true && echo 'VERIFY: Verification completed'"
                
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
            fi
            
            # Clean up local archive  
            rm -f "$archive_path"
            
            # Update command to run from workspace directory and set environment variables
            command="cd $workspace_dir && export AURORA_ENDPOINT='$AURORA_ENDPOINT' AURORA_PORT='$AURORA_PORT' AURORA_USER='$AURORA_USER' AURORA_PASSWORD='$AURORA_PASSWORD' && $command"
        else
            # Set environment variables even without directory transfer
            command="export AURORA_ENDPOINT='$AURORA_ENDPOINT' AURORA_PORT='$AURORA_PORT' AURORA_USER='$AURORA_USER' AURORA_PASSWORD='$AURORA_PASSWORD' && $command"
        fi
    fi
    
    # Capture start time
    local start_time=$(date +%s)
    
    print_info "Sending command via SSM..."
    
    # Execute command via SSM
    local command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$command\"]}" \
        --comment "Bastion Command: $(echo "$command" | head -c 50)..." \
        --timeout-seconds 300 \
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

# Function to upload and execute script on Bastion Host
upload_and_execute_script() {
    local script_path="$1"
    local bastion_instance_id="$2"
    
    print_info "=== SCRIPT UPLOAD AND EXECUTION ==="
    print_info "Script: $script_path"
    print_info "Instance ID: $bastion_instance_id"
    
    # Validate script file exists
    if [[ ! -f "$script_path" ]]; then
        print_error "Script file not found: $script_path"
        exit 1
    fi
    
    # Get script content and metadata
    local script_content=$(cat "$script_path")
    local script_name=$(basename "$script_path")
    local region=$(get_aws_region)
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would upload and execute script"
        print_info "Script size: $(wc -c < "$script_path") bytes"
        print_info "Script name: $script_name"
        return 0
    fi
    
    print_info "Uploading script content via SSM..."
    
    # Encode script content as base64 to avoid JSON escaping issues
    local script_b64=$(base64 -w 0 < "$script_path")
    
    # Create a command that decodes and executes the script
    # This avoids complex JSON escaping of multi-line content with quotes
    local upload_command="echo 'Creating script file: /tmp/$script_name' && echo '$script_b64' | base64 -d > /tmp/$script_name && chmod +x /tmp/$script_name && echo 'Executing script: /tmp/$script_name' && cd /tmp && ./$script_name && echo 'Script execution completed'"
    
    print_info "Executing upload command via SSM..."
    
    # Capture start time
    local start_time=$(date +%s)
    
    # Execute command via SSM with proper JSON escaping
    local command_id=$(aws ssm send-command \
        --instance-ids "$bastion_instance_id" \
        --document-name "AWS-RunShellScript" \
        --parameters "{\"commands\":[\"$upload_command\"]}" \
        --comment "Script Upload: $script_name" \
        --timeout-seconds 300 \
        --region "$region" \
        --query 'Command.CommandId' --output text)
    
    if [[ -z "$command_id" ]]; then
        print_error "Failed to initiate SSM script upload command"
        exit 1
    fi
    
    print_info "SSM Command ID: $command_id"
    print_info "Waiting for script execution completion..."
    
    # Wait for command to complete
    aws ssm wait command-executed \
        --command-id "$command_id" \
        --instance-id "$bastion_instance_id" \
        --region "$region" || {
        print_warning "Script execution may have timed out"
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
    print_info "=== SCRIPT OUTPUT ==="
    if [[ -n "$command_output" ]] && [[ "$command_output" != "None" ]]; then
        echo "$command_output"
    else
        print_warning "No standard output"
    fi
    
    if [[ -n "$command_error" ]] && [[ "$command_error" != "None" ]]; then
        print_warning "=== ERROR OUTPUT ==="
        echo "$command_error"
    fi
    
    print_info "=== SCRIPT EXECUTION SUMMARY ==="
    print_info "Script: $script_name"
    print_info "Exit code: ${exit_code:-unknown}"
    print_info "Execution time: ${duration}s"
    print_info "Command ID: $command_id"
    
    if [[ "$exit_code" == "0" ]]; then
        print_success "Script uploaded and executed successfully on Bastion Host!"
        return 0
    else
        print_error "Script execution failed on Bastion Host with exit code: ${exit_code:-unknown}"
        return 1
    fi
}

# Main execution
main() {
    print_info "Starting Bastion Host operations..."
    
    # Handle different operation modes
    local operation_count=0
    
    if [[ -n "$BASTION_COMMAND" ]]; then
        operation_count=$((operation_count + 1))
    fi
    
    if [[ -n "$UPLOAD_SCRIPT" ]]; then
        operation_count=$((operation_count + 1))
    fi
    
    # If no specific operation is requested, show usage
    if [[ $operation_count -eq 0 ]]; then
        print_warning "No operation specified. Use one of:"
        print_warning "  --bastion-command     Execute command on Bastion Host"
        print_warning "  --upload-script       Upload and execute script on Bastion Host"
        echo ""
        show_usage
        exit 1
    fi
    
    # Validate only one operation at a time
    if [[ $operation_count -gt 1 ]]; then
        print_error "Only one operation can be performed at a time"
        print_error "Choose one of: --bastion-command, --upload-script"
        exit 1
    fi
    
    # Execute the requested operation
    if [[ -n "$BASTION_COMMAND" ]]; then
        if [[ "$LOCAL_EXECUTION" == true ]]; then
            # Local execution mode
            if [[ "$DRY_RUN" == true ]]; then
                print_info "DRY RUN: Would execute command locally"
                print_info "Command: $BASTION_COMMAND"
                print_success "=== DRY RUN COMPLETED ==="
                return
            fi
            
            print_info "=== LOCAL COMMAND EXECUTION ==="
            print_info "Command: $BASTION_COMMAND"
            
            # Start docker compose postgres if needed
            print_info "Starting local PostgreSQL with docker compose..."
            if ! docker compose up -d postgres 2>/dev/null; then
                print_warning "Failed to start docker compose postgres, continuing anyway"
            else
                print_success "PostgreSQL started successfully"
                sleep 2  # Give postgres time to start
            fi
            
            # Handle file transfer to Docker container (similar to Bastion Host transfer)
            if [[ "$SKIP_COPY" == true ]]; then
                print_info "Skipping file transfer to Docker container (--skip-copy specified)"
            else
                # Transfer files to Docker container based on config.json
                transfer_files_to_docker_container "$CONFIG_FILE"
            fi
            
            # Execute command locally with LOCAL_EXECUTION environment variable
            print_info "Executing command locally..."
            local start_time=$(date +%s)
            
            if LOCAL_EXECUTION=true eval "$BASTION_COMMAND"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                print_success "Local command executed successfully!"
                print_info "Execution time: ${duration}s"
            else
                local exit_code=$?
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                print_error "Local command failed with exit code: $exit_code"
                print_info "Execution time: ${duration}s"
                return $exit_code
            fi
        else
            # Remote Bastion Host execution
            if [[ "$DRY_RUN" == true ]]; then
                print_info "DRY RUN: Would execute command on Bastion Host"
                print_info "Command: $BASTION_COMMAND"
                print_success "=== DRY RUN COMPLETED ==="
                return
            fi
            
            # Get Bastion Host instance ID for actual execution
            local bastion_instance_id=$(get_bastion_instance_id)
            execute_bastion_command "$BASTION_COMMAND" "$bastion_instance_id"
        fi
        
    elif [[ -n "$UPLOAD_SCRIPT" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_info "DRY RUN: Would upload and execute script on Bastion Host"
            if [[ -f "$UPLOAD_SCRIPT" ]]; then
                print_info "Script: $UPLOAD_SCRIPT"
                print_info "Script size: $(wc -c < "$UPLOAD_SCRIPT") bytes"
                print_success "=== DRY RUN COMPLETED ==="
            else
                print_error "Script file not found: $UPLOAD_SCRIPT"
            fi
            return
        fi
        
        # Get Bastion Host instance ID for actual execution
        local bastion_instance_id=$(get_bastion_instance_id)
        upload_and_execute_script "$UPLOAD_SCRIPT" "$bastion_instance_id"
    fi
    
    print_success "=== OPERATION COMPLETED ==="
}

# Run main function
main "$@"
