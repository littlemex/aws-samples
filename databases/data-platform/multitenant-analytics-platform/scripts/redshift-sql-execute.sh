#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Show usage
show_usage() {
    cat << EOF
Usage: $0 CONFIG_FILE SQL_FILE

Unified SQL execution script for Redshift Serverless (Remote) and Local Docker PostgreSQL

ARGUMENTS:
    CONFIG_FILE     Path to config.json file (required)
    SQL_FILE        Path to SQL file to execute (required)

EXAMPLES:
    # Local execution (Docker PostgreSQL)
    LOCAL_EXECUTION=true $0 config.json sql/redshift/database/create-integration-database.sql
    
    # Remote execution (Redshift Serverless)
    $0 config.json sql/redshift/database/create-integration-database.sql

    # Execute with custom config file
    $0 custom-config.json sql/redshift/verification/verify-tenant-data-sync.sql

ENVIRONMENT VARIABLES:
    LOCAL_EXECUTION         Set to 'true' for local Docker execution (default: false)
    REDSHIFT_ENDPOINT       Redshift cluster endpoint (overrides config)
    REDSHIFT_PASSWORD       Redshift database password (overrides config)
    REDSHIFT_USER           Redshift database user (overrides config)
    REDSHIFT_DATABASE       Redshift database name (overrides config)
    REDSHIFT_PORT           Redshift database port (overrides config)
    ZERO_ETL_INTEGRATION_ID Zero-ETL integration ID (loaded from .env)

LOCAL EXECUTION:
    When LOCAL_EXECUTION=true, connects to Docker Compose PostgreSQL:
    - Host: postgres (Docker service name)
    - User: dbt_user
    - Password: dbt_password
    - Port: 5432
    - Database: multitenant_analytics_zeroetl (simulates Redshift database)

REMOTE EXECUTION:
    Uses Redshift Serverless connection from bastion-redshift-connection.json or config.json.

.ENV FILE SUPPORT:
    Automatically loads .env file for Zero-ETL integration ID and other variables.

EOF
}

# Parse arguments
if [[ $# -lt 2 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    if [[ $# -lt 2 ]]; then
        print_error "Both CONFIG_FILE and SQL_FILE are required"
    fi
    show_usage
    exit 0
fi

CONFIG_FILE="$1"
SQL_FILE="$2"

# Validate SQL file exists
if [[ ! -f "$SQL_FILE" ]]; then
    print_error "SQL file not found: $SQL_FILE"
    exit 1
fi

# Load .env file if it exists
if [[ -f ".env" ]]; then
    print_info "Loading environment variables from .env file..."
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
    print_success "Environment variables loaded from .env"
else
    print_warning ".env file not found - some features may not work without Zero-ETL integration ID"
fi

# Determine execution mode
LOCAL_MODE="${LOCAL_EXECUTION:-false}"

print_info "=== REDSHIFT SQL EXECUTION ==="
print_info "SQL File: $SQL_FILE"
print_info "Config File: $CONFIG_FILE"
print_info "Execution Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL (Docker PostgreSQL)" || echo "REMOTE (Redshift Serverless)")"

# Function to read config value with jq fallback
read_config_value() {
    local key="$1"
    local default_value="$2"
    local config_file="$3"
    
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local value=$(jq -r "$key // \"$default_value\"" "$config_file" 2>/dev/null)
        # Handle environment variable substitution
        if [[ "$value" =~ ^\$\{(.+)\}$ ]]; then
            local env_var="${BASH_REMATCH[1]}"
            value="${!env_var:-$default_value}"
        fi
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Function to detect phase from SQL file path
detect_phase_from_sql_file() {
    local sql_file="$1"
    
    # Extract phase from path pattern: sql/redshift/{phase}/
    if [[ "$sql_file" =~ sql/redshift/([^/]+)/ ]]; then
        local phase="${BASH_REMATCH[1]}"
        echo "$phase"
    else
        # Default phase if pattern doesn't match
        echo "database"
    fi
}

# Function to get phase-specific database for Redshift
get_phase_database() {
    local phase="$1"
    local config_file="$2"
    local default_db="$3"
    local is_local="$4"
    
    # Check config.json for phase-specific database
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local phase_db=$(jq -r ".redshift.phases.\"$phase\".connection_db // \"$default_db\"" "$config_file" 2>/dev/null)
        if [[ "$phase_db" != "null" ]] && [[ -n "$phase_db" ]]; then
            echo "$phase_db"
            return 0
        fi
    fi
    
    # Redshift phase-specific database mapping
    case "$phase" in
        "database")
            # Database creation phase - connect to default 'dev' database
            echo "dev"
            ;;
        "schema"|"data"|"verification")
            # Connect to Zero-ETL integrated database
            if [[ "$is_local" == "true" ]]; then
                echo "multitenant_analytics_zeroetl"
            else
                echo "multitenant_analytics_zeroetl"
            fi
            ;;
        *)
            # Fallback to default
            echo "$default_db"
            ;;
    esac
}

# Function to load Redshift connection from bastion connection file (for remote mode)
load_redshift_connection() {
    local connection_file="bastion-redshift-connection.json"
    
    print_info "Loading Redshift connection information..."
    
    # Check if connection file exists
    if [[ ! -f "$connection_file" ]]; then
        print_warning "Connection file not found: $connection_file"
        print_info "Will use config.json or environment variables for connection"
        return 1
    fi
    
    # Validate jq is available
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required to parse connection information"
        exit 1
    fi
    
    # Extract connection information
    local host=$(jq -r '.connection.host // empty' "$connection_file" 2>/dev/null)
    local port=$(jq -r '.connection.port // 5439' "$connection_file" 2>/dev/null)
    local user=$(jq -r '.connection.username // "admin"' "$connection_file" 2>/dev/null)
    local password=$(jq -r '.connection.password // empty' "$connection_file" 2>/dev/null)
    
    # Set connection variables (allow environment variable override)
    export REDSHIFT_HOST="${REDSHIFT_ENDPOINT:-$host}"
    export REDSHIFT_PORT="${REDSHIFT_PORT:-$port}"
    export REDSHIFT_USER="${REDSHIFT_USER:-$user}"
    export REDSHIFT_PASSWORD="${REDSHIFT_PASSWORD:-$password}"
    
    print_success "Redshift connection loaded from bastion connection file"
    return 0
}

# Detect phase from SQL file path
DETECTED_PHASE=$(detect_phase_from_sql_file "$SQL_FILE")
print_info "Detected phase: $DETECTED_PHASE"

# Function to get connection configuration based on execution mode
get_connection_config() {
    local is_local="$1"
    local config_file="$2"
    local phase="$3"
    
    if [[ "$is_local" == "true" ]]; then
        # Local Docker PostgreSQL configuration
        print_info "Configuring for local Docker PostgreSQL..."
        
        # Get local configuration from config.json
        REDSHIFT_HOST="${REDSHIFT_ENDPOINT:-$(read_config_value '.redshift.local.host' 'localhost' "$config_file")}"
        REDSHIFT_PORT="${REDSHIFT_PORT:-$(read_config_value '.redshift.local.port' '5432' "$config_file")}"
        REDSHIFT_USER="${REDSHIFT_USER:-$(read_config_value '.redshift.local.username' 'dbt_user' "$config_file")}"
        REDSHIFT_PASSWORD="${REDSHIFT_PASSWORD:-$(read_config_value '.redshift.local.password' 'dbt_password' "$config_file")}"
        
        # Use phase-specific database for local execution
        if [[ -z "$REDSHIFT_DATABASE" ]]; then
            # Get default database from local config
            DEFAULT_DB=$(read_config_value '.redshift.local.database' 'multitenant_analytics_zeroetl' "$config_file")
            # Override with phase-specific database
            REDSHIFT_DB=$(get_phase_database "$phase" "$config_file" "$DEFAULT_DB" "true")
            print_info "Using database: $REDSHIFT_DB (phase: $phase, local mode)"
        else
            REDSHIFT_DB="$REDSHIFT_DATABASE"
            print_info "Using environment override database: $REDSHIFT_DB"
        fi
        
    else
        # Remote Redshift Serverless configuration
        print_info "Configuring for remote Redshift Serverless..."
        
        # Try to load from bastion connection file first
        if ! load_redshift_connection; then
            # Fallback to config.json
            print_info "Using config.json for Redshift connection..."
            REDSHIFT_HOST="${REDSHIFT_ENDPOINT:-$(read_config_value '.redshift.remote.host' 'localhost' "$config_file")}"
            REDSHIFT_PORT="${REDSHIFT_PORT:-$(read_config_value '.redshift.remote.port' '5439' "$config_file")}"
            REDSHIFT_USER="${REDSHIFT_USER:-$(read_config_value '.redshift.remote.username' 'admin' "$config_file")}"
            REDSHIFT_PASSWORD="${REDSHIFT_PASSWORD:-$(read_config_value '.redshift.remote.password' '' "$config_file")}"
        fi
        
        # Handle environment variable substitution for password
        if [[ "$REDSHIFT_PASSWORD" =~ ^\$\{(.+)\}$ ]]; then
            local env_var="${BASH_REMATCH[1]}"
            REDSHIFT_PASSWORD="${!env_var:-}"
        fi
        
        # Use phase-specific database if not overridden by environment variable
        if [[ -z "$REDSHIFT_DATABASE" ]]; then
            # Get default database from remote config
            DEFAULT_DB=$(read_config_value '.redshift.remote.database' 'dev' "$config_file")
            # Override with phase-specific database
            REDSHIFT_DB=$(get_phase_database "$phase" "$config_file" "$DEFAULT_DB" "false")
            print_info "Using phase-specific database: $REDSHIFT_DB (phase: $phase)"
        else
            REDSHIFT_DB="$REDSHIFT_DATABASE"
            print_info "Using environment override database: $REDSHIFT_DB"
        fi
    fi
}

# Configure connection based on execution mode
get_connection_config "$LOCAL_MODE" "$CONFIG_FILE" "$DETECTED_PHASE"

print_info "Connection Configuration:"
print_info "  Host: $REDSHIFT_HOST"
print_info "  Port: $REDSHIFT_PORT" 
print_info "  Database: $REDSHIFT_DB"
print_info "  User: $REDSHIFT_USER"
print_info "  Password: ${REDSHIFT_PASSWORD:+***set***}"

# Show Zero-ETL integration ID if available
if [[ -n "$ZERO_ETL_INTEGRATION_ID" ]]; then
    print_info "  Zero-ETL Integration ID: ${ZERO_ETL_INTEGRATION_ID:0:8}...${ZERO_ETL_INTEGRATION_ID: -8}"
else
    print_warning "  Zero-ETL Integration ID: Not set (may be required for some operations)"
fi

# Validate required connection parameters
if [[ -z "$REDSHIFT_HOST" ]] || [[ "$REDSHIFT_HOST" == "null" ]]; then
    print_error "Redshift host is required. Set REDSHIFT_ENDPOINT environment variable or configure in config.json"
    exit 1
fi

if [[ -z "$REDSHIFT_PASSWORD" ]] || [[ "$REDSHIFT_PASSWORD" == "null" ]]; then
    if [[ "$LOCAL_MODE" == "true" ]]; then
        print_error "Local PostgreSQL password not set correctly"
        exit 1
    else
        print_warning "Redshift password not set. Database connection may fail."
    fi
fi

# Check if psql is available
if ! command -v psql >/dev/null 2>&1; then
    print_error "psql command not found. Please install PostgreSQL client."
    exit 1
fi

# Function to wait for database availability (for local mode)
wait_for_database() {
    local host="$1"
    local port="$2"
    local user="$3"
    local database="$4"
    
    print_info "Testing database connection..."
    
    if PGPASSWORD="$REDSHIFT_PASSWORD" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" >/dev/null 2>&1; then
        print_success "Database is available"
        return 0
    else
        print_error "Cannot connect to database. Check connection settings."
        return 1
    fi
}

# Function to check if database exists
check_database_exists() {
    local host="$1"
    local port="$2"
    local user="$3"
    local admin_db="$4"
    local target_db="$5"
    
    local db_exists=$(PGPASSWORD="$REDSHIFT_PASSWORD" psql -h "$host" -p "$port" -U "$user" -d "$admin_db" -tAc "SELECT 1 FROM pg_database WHERE datname='$target_db';" 2>/dev/null)
    
    if [[ "$db_exists" == "1" ]]; then
        return 0  # Database exists
    else
        return 1  # Database does not exist
    fi
}

# Function to execute SQL file with environment variable substitution
execute_sql_file() {
    local sql_file="$1"
    
    print_info "Executing SQL file: $sql_file"
    print_info "File size: $(wc -c < "$sql_file") bytes"
    
    # Check if this is a database creation script
    local is_database_creation=false
    if [[ "$sql_file" == *"database/create-"* ]]; then
        is_database_creation=true
        print_info "Detected database creation script"
    fi
    
    # Set PGPASSWORD for psql
    export PGPASSWORD="$REDSHIFT_PASSWORD"
    
    # For local mode, wait for database availability
    if [[ "$LOCAL_MODE" == "true" ]]; then
        if ! wait_for_database "$REDSHIFT_HOST" "$REDSHIFT_PORT" "$REDSHIFT_USER" "$REDSHIFT_DB"; then
            print_error "Cannot connect to local PostgreSQL database"
            return 1
        fi
    fi
    
    # Create temporary SQL file with environment variable substitution
    local temp_sql_file=$(mktemp /tmp/redshift-sql-XXXXXX.sql)
    
    # Perform environment variable substitution
    print_info "Performing environment variable substitution..."
    envsubst < "$sql_file" > "$temp_sql_file"
    
    # Show what variables were substituted (for debugging)
    if [[ -n "$ZERO_ETL_INTEGRATION_ID" ]]; then
        print_info "Substituted ZERO_ETL_INTEGRATION_ID: ${ZERO_ETL_INTEGRATION_ID:0:8}...${ZERO_ETL_INTEGRATION_ID: -8}"
    fi
    
    # Execute SQL file with psql
    print_info "Executing SQL commands..."
    
    local psql_exit_code=0
    
    if [[ "$is_database_creation" == true ]]; then
        # For database creation, use more lenient error handling
        if [[ "$LOCAL_MODE" == "true" ]]; then
            # Local mode: use standard PostgreSQL error handling
            psql -h "$REDSHIFT_HOST" -p "$REDSHIFT_PORT" -U "$REDSHIFT_USER" -d "$REDSHIFT_DB" -f "$temp_sql_file" --echo-queries
        else
            # Remote mode: use Redshift-compatible error handling
            psql -h "$REDSHIFT_HOST" -p "$REDSHIFT_PORT" -U "$REDSHIFT_USER" -d "$REDSHIFT_DB" -f "$temp_sql_file" --set ON_ERROR_STOP=off --echo-queries
        fi
        psql_exit_code=$?
    else
        # For non-database creation scripts, use strict error handling
        psql -h "$REDSHIFT_HOST" -p "$REDSHIFT_PORT" -U "$REDSHIFT_USER" -d "$REDSHIFT_DB" -f "$temp_sql_file" -v ON_ERROR_STOP=1 --echo-queries
        psql_exit_code=$?
    fi
    
    # Clean up temporary file
    rm -f "$temp_sql_file"
    
    if [[ $psql_exit_code -eq 0 ]]; then
        print_success "SQL file executed successfully"
        return 0
    else
        print_error "SQL file execution failed with exit code: $psql_exit_code"
        return $psql_exit_code
    fi
}

# Execute the SQL file
print_info "=== STARTING REDSHIFT SQL EXECUTION ==="

# Record start time
start_time=$(date +%s)

# Execute SQL file
if execute_sql_file "$SQL_FILE"; then
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_success "=== REDSHIFT SQL EXECUTION COMPLETED SUCCESSFULLY ==="
    print_info "Execution time: ${duration}s"
    print_info "SQL File: $SQL_FILE"
    print_info "Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL" || echo "REMOTE")"
    exit 0
else
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_error "=== REDSHIFT SQL EXECUTION FAILED ==="
    print_info "Execution time: ${duration}s"
    print_info "SQL File: $SQL_FILE"
    print_info "Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL" || echo "REMOTE")"
    exit 1
fi
