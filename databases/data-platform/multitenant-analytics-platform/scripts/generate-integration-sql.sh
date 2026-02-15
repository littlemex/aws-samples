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
Usage: $0 [OPTIONS]

Generate SQL files from templates using integration ID from .env file

OPTIONS:
    --template TEMPLATE_FILE    Template SQL file to process (required)
    --output OUTPUT_FILE        Output SQL file path (required)
    --integration-id ID         Integration ID (overrides .env file)
    --help, -h                  Show this help message

EXAMPLES:
    # Generate from template using .env file
    $0 --template sql/redshift/database/create-integration-database.template.sql \\
       --output sql/redshift/database/create-integration-database-generated.sql

    # Generate with specific integration ID
    $0 --template sql/redshift/database/create-integration-database.template.sql \\
       --output sql/redshift/database/create-integration-database-generated.sql \\
       --integration-id baab0f11-559d-472e-9631-07c61e51bae6

TEMPLATE PLACEHOLDERS:
    {{INTEGRATION_ID}}          Replaced with Zero-ETL integration ID
    {{TIMESTAMP}}               Replaced with current timestamp
    {{DATE}}                    Replaced with current date

PREREQUISITES:
    1. .env file with ZERO_ETL_INTEGRATION_ID (unless --integration-id provided)
    2. Template SQL file must exist
    3. Output directory must be writable

EOF
}

# Parse command line arguments
TEMPLATE_FILE=""
OUTPUT_FILE=""
INTEGRATION_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --template)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --integration-id)
            INTEGRATION_ID="$2"
            shift 2
            ;;
        --help|-h)
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
if [[ -z "$TEMPLATE_FILE" ]]; then
    print_error "Template file is required. Use --template option."
    show_usage
    exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    print_error "Output file is required. Use --output option."
    show_usage
    exit 1
fi

# Validate template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

print_info "=== SQL FILE GENERATION ==="
print_info "Template: $TEMPLATE_FILE"
print_info "Output: $OUTPUT_FILE"

# Load integration ID from .env if not provided via command line
if [[ -z "$INTEGRATION_ID" ]]; then
    if [[ -f ".env" ]]; then
        print_info "Loading integration ID from .env file..."
        # Source .env file to get ZERO_ETL_INTEGRATION_ID
        set -a  # automatically export all variables
        source .env
        set +a  # stop automatically exporting
        
        INTEGRATION_ID="$ZERO_ETL_INTEGRATION_ID"
        
        if [[ -z "$INTEGRATION_ID" ]]; then
            print_error "ZERO_ETL_INTEGRATION_ID not found in .env file"
            exit 1
        fi
        
        print_success "Integration ID loaded from .env: ${INTEGRATION_ID:0:8}...${INTEGRATION_ID: -8}"
    else
        print_error ".env file not found and --integration-id not provided"
        print_error "Either create .env file with ZERO_ETL_INTEGRATION_ID or use --integration-id option"
        exit 1
    fi
else
    print_info "Using integration ID from command line: ${INTEGRATION_ID:0:8}...${INTEGRATION_ID: -8}"
fi

# Validate integration ID format (UUID)
if [[ ! "$INTEGRATION_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    print_warning "Integration ID does not match UUID format: $INTEGRATION_ID"
    print_info "Proceeding anyway as it might be a valid integration ID in different format"
fi

# Prepare replacement variables
CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_DATE=$(date '+%Y-%m-%d')

print_info "Replacement variables:"
print_info "  Integration ID: ${INTEGRATION_ID:0:8}...${INTEGRATION_ID: -8}"
print_info "  Timestamp: $CURRENT_TIMESTAMP"
print_info "  Date: $CURRENT_DATE"

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [[ ! -d "$OUTPUT_DIR" ]]; then
    print_info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
fi

# Generate SQL file from template
print_info "Generating SQL file from template..."

# Use sed to replace placeholders
sed -e "s/{{INTEGRATION_ID}}/$INTEGRATION_ID/g" \
    -e "s/{{TIMESTAMP}}/$CURRENT_TIMESTAMP/g" \
    -e "s/{{DATE}}/$CURRENT_DATE/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Verify output file was created
if [[ ! -f "$OUTPUT_FILE" ]]; then
    print_error "Failed to create output file: $OUTPUT_FILE"
    exit 1
fi

# Show file sizes for verification
TEMPLATE_SIZE=$(wc -c < "$TEMPLATE_FILE")
OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE")

print_success "SQL file generated successfully!"
print_info "Template size: $TEMPLATE_SIZE bytes"
print_info "Output size: $OUTPUT_SIZE bytes"
print_info "Output file: $OUTPUT_FILE"

# Show a preview of the generated file (first few lines with integration ID)
print_info "Generated file preview (lines containing integration ID):"
grep -n "{{INTEGRATION_ID}}\|$INTEGRATION_ID" "$OUTPUT_FILE" | head -3 || true

print_success "=== SQL FILE GENERATION COMPLETED ==="
