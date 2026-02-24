#!/bin/bash

# SRE Agent - ngrok Setup Migration Script
# Migrates the SRE Agent from old AWS account to new account using ngrok

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 SRE Agent - ngrok Setup Migration"
echo "====================================="
echo ""

# Step 1: Verify AWS Account
log_info "Step 1: Verifying AWS Account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$ACCOUNT_ID" ]; then
    log_error "Failed to get AWS Account ID. Please configure AWS CLI first."
    exit 1
fi

log_success "Connected to AWS Account: $ACCOUNT_ID"

# Confirm account
echo ""
log_warning "Is this the correct AWS account for deployment?"
echo "Account ID: $ACCOUNT_ID"
read -p "Continue with this account? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_error "Migration cancelled."
    exit 1
fi

# Step 2: Check ngrok
log_info "Step 2: Checking ngrok installation..."
if ! command -v ngrok &> /dev/null; then
    log_error "ngrok is not installed."
    echo "Install ngrok:"
    echo "  - Ubuntu/Debian: sudo snap install ngrok"
    echo "  - macOS: brew install ngrok"
    echo "  - Or download from: https://ngrok.com/download"
    exit 1
fi

log_success "ngrok is installed"

# Check ngrok authentication
if ! ngrok config check &> /dev/null; then
    log_warning "ngrok is not authenticated"
    echo "Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
    read -p "Enter your ngrok authtoken: " NGROK_TOKEN
    ngrok config add-authtoken "$NGROK_TOKEN"
    log_success "ngrok authenticated"
fi

# Step 3: Get ngrok domain
echo ""
log_info "Step 3: ngrok Domain Configuration..."
echo "Do you have a paid ngrok plan with a fixed domain?"
read -p "(yes/no): " HAS_FIXED_DOMAIN

if [ "$HAS_FIXED_DOMAIN" = "yes" ]; then
    read -p "Enter your ngrok domain (e.g., your-domain.ngrok-free.app): " NGROK_DOMAIN
else
    log_warning "Free tier: ngrok URL will change on each restart"
    log_info "You'll need to update OpenAPI specs each time"
    NGROK_DOMAIN="<will-be-assigned-by-ngrok>"
fi

# Step 4: Setup Cognito
echo ""
log_info "Step 4: Setting up Cognito..."
read -p "Run automated Cognito setup? (yes/no): " SETUP_COGNITO

if [ "$SETUP_COGNITO" = "yes" ]; then
    cd "$PROJECT_ROOT/deployment"
    
    if [ -f "setup_cognito.sh" ]; then
        log_info "Running Cognito setup..."
        bash setup_cognito.sh
        
        if [ -f ".cognito_config" ]; then
            source .cognito_config
            log_success "Cognito setup completed"
            echo "  User Pool ID: $USER_POOL_ID"
            echo "  Client ID: $COGNITO_CLIENT_ID"
        else
            log_error "Cognito setup failed"
            exit 1
        fi
    else
        log_error "setup_cognito.sh not found"
        exit 1
    fi
else
    log_info "Skipping Cognito setup. You'll need to configure manually."
    read -p "User Pool ID: " USER_POOL_ID
    read -p "Client ID: " COGNITO_CLIENT_ID
    read -p "Client Secret: " COGNITO_CLIENT_SECRET
    read -p "Cognito Domain: " COGNITO_DOMAIN
fi

# Step 5: Update gateway config
echo ""
log_info "Step 5: Updating Gateway Configuration..."
cd "$PROJECT_ROOT/gateway"

if [ ! -f "config.yaml" ]; then
    cp config.yaml.example config.yaml
fi

# Update config.yaml
log_info "Updating gateway/config.yaml..."
sed -i.bak "s/account_id: \".*\"/account_id: \"$ACCOUNT_ID\"/" config.yaml
sed -i.bak "s/user_pool_id: \".*\"/user_pool_id: \"$USER_POOL_ID\"/" config.yaml
sed -i.bak "s/client_id: \".*\"/client_id: \"$COGNITO_CLIENT_ID\"/" config.yaml
sed -i.bak "s|provider_arn: \"arn:aws:bedrock-agentcore:.*:.*:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider\"|provider_arn: \"arn:aws:bedrock-agentcore:us-east-1:$ACCOUNT_ID:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider\"|" config.yaml
rm -f config.yaml.bak

log_success "Gateway configuration updated"

# Update .env
if [ -n "$COGNITO_CLIENT_SECRET" ]; then
    log_info "Updating gateway/.env..."
    cat > .env << EOF
# Cognito Configuration
COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_CLIENT_ID=$COGNITO_CLIENT_ID
COGNITO_CLIENT_SECRET=$COGNITO_CLIENT_SECRET
COGNITO_REGION=us-east-1
COGNITO_DOMAIN=$COGNITO_DOMAIN

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$ACCOUNT_ID

# Backend Configuration
BACKEND_DOMAIN=127.0.0.1
BACKEND_API_KEY=1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
EOF
    log_success "Gateway .env updated"
fi

# Step 6: Instructions for next steps
echo ""
echo "=========================================="
log_success "Configuration Complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Start backend servers:"
echo "   cd backend"
echo "   ./scripts/start_demo_backend.sh --host 127.0.0.1"
echo ""
echo "2. Start ngrok tunnel (in separate terminal):"
if [ "$HAS_FIXED_DOMAIN" = "yes" ]; then
    echo "   ngrok http 8000 --domain=$NGROK_DOMAIN"
else
    echo "   ngrok http 8000"
    echo "   (Note the assigned URL for next step)"
fi
echo ""
echo "3. Update OpenAPI specs with ngrok URL:"
echo "   Edit backend/openapi_specs/*.yaml files"
echo "   Update servers[0].url with your ngrok domain"
echo ""
echo "4. Create gateway and upload specs:"
echo "   cd gateway"
echo "   ./create_gateway.sh"
echo "   ./mcp_cmds.sh"
echo "   (Wait 10 minutes for targets to be READY)"
echo ""
echo "5. Update agent configuration:"
echo "   GATEWAY_URI=\$(cat gateway/.gateway_uri)"
echo "   sed -i \"s|uri: \\\".*\\\"|uri: \\\"\$GATEWAY_URI\\\"|\" sre_agent/config/agent_config.yaml"
echo "   cd sre_agent"
echo "   cp .env.example .env"
echo "   echo \"GATEWAY_ACCESS_TOKEN=\$(cat ../gateway/.access_token)\" >> .env"
echo ""
echo "6. Initialize memory system:"
echo "   uv run python scripts/manage_memories.py update"
echo "   (Wait 10-12 minutes, then check status)"
echo ""
echo "7. Test the agent:"
echo "   sre-agent --prompt \"List pods in production\" --provider bedrock"
echo ""
echo "📖 For detailed instructions, see:"
echo "   - NGROK_MIGRATION_GUIDE.md"
echo "   - archive/NGROK_SESSION_GUIDE.md"
echo ""
log_success "Migration helper completed!"
