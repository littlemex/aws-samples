#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_info "Starting dbt environment setup..."

# Install system dependencies (git is required by dbt)
print_info "Installing system dependencies..."
if ! command -v git >/dev/null 2>&1; then
    print_info "Installing git (required by dbt)..."
    yum update -y >/dev/null 2>&1
    yum install -y git >/dev/null 2>&1
    print_success "Git installed: $(git --version)"
else
    print_info "Git already available: $(git --version)"
fi

# Install Python3 and pip if not available
if ! command -v python3 >/dev/null 2>&1; then
    print_info "Installing Python3..."
    sudo yum update -y
    sudo yum install -y python3 python3-pip
fi

# Create Python virtual environment for dbt
print_info "Creating Python virtual environment for dbt..."
python3 -m venv /tmp/dbt-venv
source /tmp/dbt-venv/bin/activate

# Install dbt-redshift with compatible redshift-connector version
print_info "Installing dbt-redshift with compatible dependencies..."
pip install --upgrade pip

# Install exact compatible redshift-connector version first
print_info "Installing redshift-connector 2.0.910 (required for dbt-redshift 1.5.0)..."
pip install 'redshift-connector==2.0.910' --quiet

# Install dbt-redshift
print_info "Installing dbt-redshift 1.5.0..."
pip install dbt-redshift==1.5.0 --quiet

print_info "Final package versions:"
pip list | grep -E "(dbt|redshift)" || echo "Package listing completed"

# Verify dbt installation
print_info "Verifying dbt installation..."
dbt --version

# Create minimal test dbt project for verification
print_info "Creating test dbt project for verification..."
mkdir -p /tmp/dbt-test-project
cd /tmp/dbt-test-project

# Create minimal dbt_project.yml for testing
cat > dbt_project.yml << 'EOF'
name: 'test_project'
version: '1.0.0'
config-version: 2
profile: 'test_profile'
model-paths: ["models"]
target-path: "target"
clean-targets: ["target", "dbt_packages"]
models:
  test_project:
    +materialized: view
EOF

# Create minimal profiles.yml for testing
mkdir -p ~/.dbt
cat > ~/.dbt/profiles.yml << 'EOF'
test_profile:
  outputs:
    dev:
      type: redshift
      host: localhost
      user: test
      password: test
      port: 5439
      dbname: test
      schema: test
      threads: 1
  target: dev
EOF

# Test basic dbt commands
print_info "Testing basic dbt commands..."

print_info "Testing: dbt parse..."
if dbt parse --no-version-check; then
    print_success "dbt parse: OK"
else
    print_error "dbt parse: FAILED"
    exit 1
fi

print_info "Testing: dbt compile..."
if dbt compile --no-version-check; then
    print_success "dbt compile: OK"  
else
    print_error "dbt compile: FAILED"
    exit 1
fi

print_info "Testing: dbt list..."
if dbt list --no-version-check; then
    print_success "dbt list: OK"
else
    print_error "dbt list: FAILED"
    exit 1
fi

# Clean up test project
cd /
rm -rf /tmp/dbt-test-project

print_success "dbt environment setup and verification completed successfully!"
print_info "dbt-redshift is now available in: /tmp/dbt-venv/"
print_success "✅ All basic dbt commands are working correctly"
