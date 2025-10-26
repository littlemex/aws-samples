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

Unified SQL execution script for Aurora PostgreSQL (Remote) and Local Docker PostgreSQL

ARGUMENTS:
    CONFIG_FILE     Path to config.json file (required)
    SQL_FILE        Path to SQL file to execute (required)

EXAMPLES:
    # Local execution (Docker PostgreSQL)
    LOCAL_EXECUTION=true $0 config.json sql/aurora/schema/create-tenant-schemas.sql
    
    # Remote execution (Aurora PostgreSQL)
    $0 config.json sql/aurora/schema/create-tenant-schemas.sql

    # Execute with custom config file
    $0 custom-config.json sql/aurora/data/insert-sample-data.sql

    # Execute verification queries
    $0 config.json sql/aurora/verification/verify-setup.sql

ENVIRONMENT VARIABLES:
    LOCAL_EXECUTION     Set to 'true' for local Docker execution (default: false)
    AURORA_ENDPOINT     Aurora cluster endpoint (overrides config)
    AURORA_PASSWORD     Aurora database password (overrides config)
    AURORA_USER         Aurora database user (overrides config)
    AURORA_DATABASE     Aurora database name (overrides config)
    AURORA_PORT         Aurora database port (overrides config)

LOCAL EXECUTION:
    When LOCAL_EXECUTION=true, connects to Docker Compose PostgreSQL:
    - Host: postgres (Docker service name)
    - User: dbt_user
    - Password: dbt_password
    - Port: 5432

REMOTE EXECUTION:
    Uses Aurora PostgreSQL connection from config.json or environment variables.

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

# Determine execution mode
LOCAL_MODE="${LOCAL_EXECUTION:-false}"

print_info "=== AURORA SQL EXECUTION ==="
print_info "SQL File: $SQL_FILE"
print_info "Config File: $CONFIG_FILE"
print_info "Execution Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL (Docker)" || echo "REMOTE (Aurora)")"

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
    
    # Extract phase from path pattern: sql/aurora/{phase}/
    if [[ "$sql_file" =~ sql/aurora/([^/]+)/ ]]; then
        local phase="${BASH_REMATCH[1]}"
        echo "$phase"
    else
        # Default phase if pattern doesn't match
        echo "schema"
    fi
}

# Function to get phase-specific database
get_phase_database() {
    local phase="$1"
    local config_file="$2"
    local default_db="$3"
    local is_local="$4"
    
    # Always check config.json for phase-specific database, even for local execution
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local phase_db=$(jq -r ".aurora.phases.\"$phase\".connection_db // \"$default_db\"" "$config_file" 2>/dev/null)
        if [[ "$phase_db" != "null" ]] && [[ -n "$phase_db" ]]; then
            # Use the phase-specific database as configured, regardless of local/remote mode
            # This is important for database creation phase which needs to connect to 'postgres' DB
            echo "$phase_db"
            return 0
        fi
    fi
    
    # Fallback to default
    if [[ "$is_local" == "true" ]]; then
        echo "multitenant_analytics"
    else
        echo "$default_db"
    fi
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
        # Local Docker PostgreSQL configuration from config.json
        print_info "Configuring for local Docker PostgreSQL..."
        
        # Get local configuration from config.json
        AURORA_HOST="${AURORA_ENDPOINT:-$(read_config_value '.aurora.local.host' 'localhost' "$config_file")}"
        AURORA_PORT="${AURORA_PORT:-$(read_config_value '.aurora.local.port' '5432' "$config_file")}"
        AURORA_USER="${AURORA_USER:-$(read_config_value '.aurora.local.username' 'dbt_user' "$config_file")}"
        AURORA_PASSWORD="${AURORA_PASSWORD:-$(read_config_value '.aurora.local.password' 'dbt_password' "$config_file")}"
        
        # Use phase-specific database for local execution too
        if [[ -z "$AURORA_DATABASE" ]]; then
            # Get default database from local config
            DEFAULT_DB=$(read_config_value '.aurora.local.database' 'multitenant_analytics' "$config_file")
            # Override with phase-specific database
            AURORA_DB=$(get_phase_database "$phase" "$config_file" "$DEFAULT_DB" "true")
            print_info "Using database: $AURORA_DB (phase: $phase, local mode)"
        else
            AURORA_DB="$AURORA_DATABASE"
            print_info "Using environment override database: $AURORA_DB"
        fi
        
        # Set database owner for SQL substitution (use the local username)
        export DATABASE_OWNER="$AURORA_USER"
        print_info "Database owner for SQL operations: $DATABASE_OWNER"
        
    else
        # Remote Aurora PostgreSQL configuration
        print_info "Configuring for remote Aurora PostgreSQL..."
        
        # Get Aurora remote configuration
        # Priority: Environment Variables > Config File > Defaults
        AURORA_HOST="${AURORA_ENDPOINT:-$(read_config_value '.aurora.remote.host' 'localhost' "$config_file")}"
        AURORA_PORT="${AURORA_PORT:-$(read_config_value '.aurora.remote.port' '5432' "$config_file")}"
        AURORA_USER="${AURORA_USER:-$(read_config_value '.aurora.remote.username' 'postgres' "$config_file")}"
        AURORA_PASSWORD="${AURORA_PASSWORD:-$(read_config_value '.aurora.remote.password' '' "$config_file")}"
        
        # Handle environment variable substitution for password
        if [[ "$AURORA_PASSWORD" =~ ^\$\{(.+)\}$ ]]; then
            local env_var="${BASH_REMATCH[1]}"
            AURORA_PASSWORD="${!env_var:-}"
        fi
        
        # Handle environment variable substitution for username
        if [[ "$AURORA_USER" =~ ^\$\{(.+)\}$ ]]; then
            local env_var="${BASH_REMATCH[1]}"
            AURORA_USER="${!env_var:-postgres}"
        fi
        
        # Use phase-specific database if not overridden by environment variable
        if [[ -z "$AURORA_DATABASE" ]]; then
            # Get default database from remote config
            DEFAULT_DB=$(read_config_value '.aurora.remote.database' 'multitenant_analytics' "$config_file")
            # Override with phase-specific database
            AURORA_DB=$(get_phase_database "$phase" "$config_file" "$DEFAULT_DB" "false")
            print_info "Using phase-specific database: $AURORA_DB (phase: $phase)"
        else
            AURORA_DB="$AURORA_DATABASE"
            print_info "Using environment override database: $AURORA_DB"
        fi
        
        # Set database owner for SQL substitution (use the resolved username)
        export DATABASE_OWNER="$AURORA_USER"
        print_info "Database owner for SQL operations: $DATABASE_OWNER"
    fi
}

# Configure connection based on execution mode
get_connection_config "$LOCAL_MODE" "$CONFIG_FILE" "$DETECTED_PHASE"

print_info "Connection Configuration:"
print_info "  Host: $AURORA_HOST"
print_info "  Port: $AURORA_PORT" 
print_info "  Database: $AURORA_DB"
print_info "  User: $AURORA_USER"
print_info "  Password: ${AURORA_PASSWORD:+***set***}"

# Validate required connection parameters
if [[ -z "$AURORA_HOST" ]] || [[ "$AURORA_HOST" == "null" ]]; then
    print_error "Aurora host is required. Set AURORA_ENDPOINT environment variable or configure in config.json"
    exit 1
fi

if [[ -z "$AURORA_PASSWORD" ]] || [[ "$AURORA_PASSWORD" == "null" ]]; then
    if [[ "$LOCAL_MODE" == "true" ]]; then
        print_error "Local PostgreSQL password not set correctly"
        exit 1
    else
        print_warning "Aurora password not set. Database connection may fail."
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
    
    if PGPASSWORD="$AURORA_PASSWORD" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1;" >/dev/null 2>&1; then
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
    
    local db_exists=$(PGPASSWORD="$AURORA_PASSWORD" psql -h "$host" -p "$port" -U "$user" -d "$admin_db" -tAc "SELECT 1 FROM pg_database WHERE datname='$target_db';" 2>/dev/null)
    
    if [[ "$db_exists" == "1" ]]; then
        return 0  # Database exists
    else
        return 1  # Database does not exist
    fi
}

# Function to execute SQL file
execute_sql_file() {
    local sql_file="$1"
    
    print_info "Executing SQL file: $sql_file"
    print_info "File size: $(wc -c < "$sql_file") bytes"
    
    # Check if this is a database creation script
    local is_database_creation=false
    if [[ "$sql_file" == *"database/create-"* ]]; then
        is_database_creation=true
        
        # Check if the target database already exists
        if check_database_exists "$AURORA_HOST" "$AURORA_PORT" "$AURORA_USER" "$AURORA_DB" "multitenant_analytics"; then
            print_info "Detected database creation script - target database already exists, will handle gracefully"
        else
            print_info "Detected database creation script - target database does not exist, will create new database"
        fi
    fi
    
    # Set PGPASSWORD for psql
    export PGPASSWORD="$AURORA_PASSWORD"
    
    # For local mode, wait for database availability
    if [[ "$LOCAL_MODE" == "true" ]]; then
        if ! wait_for_database "$AURORA_HOST" "$AURORA_PORT" "$AURORA_USER" "$AURORA_DB"; then
            print_error "Cannot connect to local PostgreSQL database"
            return 1
        fi
    fi
    
    # Execute SQL file with psql
    print_info "Executing SQL commands..."
    
    if [[ "$is_database_creation" == true ]]; then
        # For database creation, capture output to check for "already exists" error
        local psql_output=""
        local psql_exit_code=0
        
        psql_output=$(psql -h "$AURORA_HOST" -p "$AURORA_PORT" -U "$AURORA_USER" -d "$AURORA_DB" -f "$sql_file" -v ON_ERROR_STOP=1 -v DATABASE_OWNER="$DATABASE_OWNER" --echo-queries 2>&1)
        psql_exit_code=$?
        
        # Check if the error is "database already exists"
        if [[ $psql_exit_code -ne 0 ]] && [[ "$psql_output" == *"database \"multitenant_analytics\" already exists"* ]]; then
            print_warning "Database already exists - this is expected and safe to ignore"
            print_info "Database creation output: $psql_output"
            print_success "SQL file executed successfully (database already exists)"
            return 0
        elif [[ $psql_exit_code -eq 0 ]]; then
            print_info "Database creation output: $psql_output"
            print_success "SQL file executed successfully"
            return 0
        else
            print_error "SQL file execution failed with exit code: $psql_exit_code"
            print_error "Error output: $psql_output"
            return $psql_exit_code
        fi
    else
        # For non-database creation scripts, use original logic
        if psql -h "$AURORA_HOST" -p "$AURORA_PORT" -U "$AURORA_USER" -d "$AURORA_DB" -f "$sql_file" -v ON_ERROR_STOP=1 --echo-queries; then
            print_success "SQL file executed successfully"
            return 0
        else
            local exit_code=$?
            print_error "SQL file execution failed with exit code: $exit_code"
            return $exit_code
        fi
    fi
}

# Execute the SQL file
print_info "=== STARTING SQL EXECUTION ==="

# Record start time
start_time=$(date +%s)

# Execute SQL file
if execute_sql_file "$SQL_FILE"; then
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_success "=== SQL EXECUTION COMPLETED SUCCESSFULLY ==="
    print_info "Execution time: ${duration}s"
    print_info "SQL File: $SQL_FILE"
    print_info "Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL" || echo "REMOTE")"
    exit 0
else
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_error "=== SQL EXECUTION FAILED ==="
    print_info "Execution time: ${duration}s"
    print_info "SQL File: $SQL_FILE"
    print_info "Mode: $([ "$LOCAL_MODE" == "true" ] && echo "LOCAL" || echo "REMOTE")"
    exit 1
fi
