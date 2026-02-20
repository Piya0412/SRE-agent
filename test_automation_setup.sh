#!/bin/bash

# ============================================================================
# Test Automation Setup
# ============================================================================
# This script verifies that all prerequisites are installed and configured
# Run this before using the automation scripts for the first time
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

ERRORS=0

print_header "Testing Automation Setup"

# Check if scripts exist
print_info "Checking if automation scripts exist..."
SCRIPTS=("setup_ngrok_session.sh" "stop_ngrok_session.sh" "check_ngrok_session.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_success "$script exists and is executable"
        else
            print_warning "$script exists but is not executable"
            print_info "Run: bash make_scripts_executable.sh"
            ((ERRORS++))
        fi
    else
        print_error "$script not found"
        ((ERRORS++))
    fi
done

# Check ngrok
print_info "Checking ngrok installation..."
if command -v ngrok &> /dev/null; then
    NGROK_VERSION=$(ngrok version 2>&1 | head -1)
    print_success "ngrok is installed: $NGROK_VERSION"
    
    # Check if ngrok is authenticated
    if ngrok config check &> /dev/null; then
        print_success "ngrok is authenticated"
    else
        print_warning "ngrok may not be authenticated"
        print_info "Run: ngrok config add-authtoken YOUR_TOKEN"
    fi
else
    print_error "ngrok is not installed"
    print_info "Install with: sudo snap install ngrok"
    ((ERRORS++))
fi

# Check AWS CLI
print_info "Checking AWS CLI installation..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    print_success "AWS CLI is installed: $AWS_VERSION"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        print_success "AWS credentials are configured"
    else
        print_error "AWS credentials are not configured"
        print_info "Run: aws configure"
        ((ERRORS++))
    fi
else
    print_error "AWS CLI is not installed"
    ((ERRORS++))
fi

# Check Python
print_info "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    print_success "Python is installed: $PYTHON_VERSION"
else
    print_error "Python 3 is not installed"
    ((ERRORS++))
fi

# Check project structure
print_info "Checking project structure..."
REQUIRED_DIRS=("backend/servers" "backend/openapi_specs" "gateway" "sre_agent")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directory exists: $dir"
    else
        print_error "Directory not found: $dir"
        print_info "Are you in the project root?"
        ((ERRORS++))
    fi
done

# Check backend files
print_info "Checking backend files..."
if [ -f "backend/servers/run_all_servers.py" ]; then
    print_success "Backend server runner found"
else
    print_error "Backend server runner not found"
    ((ERRORS++))
fi

# Check OpenAPI templates
print_info "Checking OpenAPI templates..."
TEMPLATES=("k8s_api.yaml.template" "logs_api.yaml.template" "metrics_api.yaml.template" "runbooks_api.yaml.template")
for template in "${TEMPLATES[@]}"; do
    if [ -f "backend/openapi_specs/$template" ]; then
        print_success "Template found: $template"
    else
        print_error "Template not found: $template"
        ((ERRORS++))
    fi
done

# Check gateway scripts
print_info "Checking gateway scripts..."
GATEWAY_SCRIPTS=("generate_token.py" "add_gateway_targets.py" "check_gateway_targets.py")
for script in "${GATEWAY_SCRIPTS[@]}"; do
    if [ -f "gateway/$script" ]; then
        print_success "Gateway script found: $script"
    else
        print_error "Gateway script not found: $script"
        ((ERRORS++))
    fi
done

# Check S3 bucket access
print_info "Checking S3 bucket access..."
S3_BUCKET="sre-agent-specs-1771225925"
if aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
    print_success "S3 bucket is accessible: $S3_BUCKET"
else
    print_error "Cannot access S3 bucket: $S3_BUCKET"
    print_info "Check AWS credentials and bucket permissions"
    ((ERRORS++))
fi

# Summary
print_header "Test Summary"

if [ $ERRORS -eq 0 ]; then
    print_success "All checks passed! You're ready to use the automation."
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo -e "  1. Run: ${BLUE}./setup_ngrok_session.sh${NC}"
    echo -e "  2. Wait 10 minutes for gateway targets"
    echo -e "  3. Run: ${BLUE}./check_ngrok_session.sh${NC}"
    echo -e "  4. Test: ${BLUE}cd sre_agent && uv run sre-agent --prompt \"Test\"${NC}"
    echo ""
else
    print_error "Found $ERRORS error(s). Please fix them before proceeding."
    echo ""
    echo -e "${YELLOW}Common fixes:${NC}"
    echo -e "  - Make scripts executable: ${BLUE}bash make_scripts_executable.sh${NC}"
    echo -e "  - Install ngrok: ${BLUE}sudo snap install ngrok${NC}"
    echo -e "  - Authenticate ngrok: ${BLUE}ngrok config add-authtoken YOUR_TOKEN${NC}"
    echo -e "  - Configure AWS: ${BLUE}aws configure${NC}"
    echo ""
fi

exit $ERRORS
