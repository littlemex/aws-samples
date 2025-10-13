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

Generic SQL execution script for Aurora PostgreSQL

ARGUMENTS:
    CONFIG_FILE     Path to config.json file (required)
    SQL_FILE        Path to SQL file to execute (required)

EXAMPLES:
    # Execute a single SQL file
    $0 config.json sql/aurora/schema/create-tenant-schemas.sql

    # Execute with custom config file
    $0 custom-config.json sql/aurora/data/insert-sample-data.sql

    # Execute verification queries
    $0 config.json sql/aurora/verification/verify-setup.sql

ENVIRONMENT VARIABLES (optional, overrides config):
    AURORA_ENDPOINT     Aurora cluster endpoint
    AURORA_PASSWORD     Aurora database password
    AURORA_USER         Aurora database user
    AURORA_DATABASE     Aurora database name
    AURORA_PORT         Aurora database port

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

print_info "=== GENERIC SQL EXECUTION ==="
print_info "SQL File: $SQL_FILE"
print_info "Config File: $CONFIG_FILE"

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
    
    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        local phase_db=$(jq -r ".aurora.phases.\"$phase\".connection_db // \"$default_db\"" "$config_file" 2>/dev/null)
        if [[ "$phase_db" != "null" ]] && [[ -n "$phase_db" ]]; then
            echo "$phase_db"
            return 0
        fi
    fi
    
    # Fallback to default
    echo "$default_db"
}

# Detect phase from SQL file path
DETECTED_PHASE=$(detect_phase_from_sql_file "$SQL_FILE")
print_info "Detected phase: $DETECTED_PHASE"

# Get Aurora connection configuration
# Priority: Environment Variables > Config File > Defaults
AURORA_HOST="${AURORA_ENDPOINT:-$(read_config_value '.aurora.connection.host' 'localhost' "$CONFIG_FILE")}"
AURORA_PORT="${AURORA_PORT:-$(read_config_value '.aurora.connection.port' '5432' "$CONFIG_FILE")}"

# Use phase-specific database if not overridden by environment variable
if [[ -z "$AURORA_DATABASE" ]]; then
    # Get default database from config
    DEFAULT_DB=$(read_config_value '.aurora.connection.database' 'multitenant_analytics' "$CONFIG_FILE")
    # Override with phase-specific database
    AURORA_DB=$(get_phase_database "$DETECTED_PHASE" "$CONFIG_FILE" "$DEFAULT_DB")
    print_info "Using phase-specific database: $AURORA_DB (phase: $DETECTED_PHASE)"
else
    AURORA_DB="$AURORA_DATABASE"
    print_info "Using environment override database: $AURORA_DB"
fi

AURORA_USER="${AURORA_USER:-$(read_config_value '.aurora.connection.username' 'postgres' "$CONFIG_FILE")}"
AURORA_PASSWORD="${AURORA_PASSWORD:-$(read_config_value '.aurora.connection.password' '' "$CONFIG_FILE")}"

# Handle environment variable substitution for password
if [[ "$AURORA_PASSWORD" =~ ^\$\{(.+)\}$ ]]; then
    local env_var="${BASH_REMATCH[1]}"
    AURORA_PASSWORD="${!env_var:-}"
fi

print_info "Aurora Connection Configuration:"
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
    print_warning "Aurora password not set. Database connection may fail."
fi

# Check if psql is available
if ! command -v psql >/dev/null 2>&1; then
    print_error "psql command not found. Please install PostgreSQL client."
    exit 1
fi

# Function to execute SQL file
execute_sql_file() {
    local sql_file="$1"
    
    print_info "Executing SQL file: $sql_file"
    print_info "File size: $(wc -c < "$sql_file") bytes"
    
    # Set PGPASSWORD for psql
    export PGPASSWORD="$AURORA_PASSWORD"
    
    # Execute SQL file with psql
    if psql -h "$AURORA_HOST" -p "$AURORA_PORT" -U "$AURORA_USER" -d "$AURORA_DB" -f "$sql_file" -v ON_ERROR_STOP=1 --echo-queries; then
        print_success "SQL file executed successfully"
        return 0
    else
        local exit_code=$?
        print_error "SQL file execution failed with exit code: $exit_code"
        return $exit_code
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
    exit 0
else
    # Calculate execution time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    print_error "=== SQL EXECUTION FAILED ==="
    print_info "Execution time: ${duration}s"
    print_info "SQL File: $SQL_FILE"
    exit 1
fi
