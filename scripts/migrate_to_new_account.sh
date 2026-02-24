#!/bin/bash

# SRE Agent - Account Migration Helper Script
# Helps migrate the project to a new AWS account

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 SRE Agent - Account Migration Helper"
echo "========================================"
echo ""

# Step 1: Verify AWS Account
log_info "Step 1: Verifying AWS Account..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$ACCOUNT_ID" ]; then
    log_error "Failed to get AWS Account ID. Please configure AWS CLI first."
    echo "Run: aws configure"
    exit 1
fi

log_success "Connected to AWS Account: $ACCOUNT_ID"

# Confirm this is the correct account
echo ""
log_warning "Is this the correct AWS account for deployment?"
echo "Account ID: $ACCOUNT_ID"
read -p "Continue with this account? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_error "Migration cancelled. Please configure the correct AWS account."
    echo "Tip: Use 'aws configure' or set AWS_PROFILE environment variable"
    exit 1
fi

# Step 2: Get AWS Region
echo ""
log_info "Step 2: AWS Region Configuration..."
DEFAULT_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
read -p "Enter AWS region [$DEFAULT_REGION]: " AWS_REGION
AWS_REGION=${AWS_REGION:-$DEFAULT_REGION}
log_success "Using region: $AWS_REGION"

# Step 3: Get IAM Role Name
echo ""
log_info "Step 3: IAM Role Configuration..."
echo "The IAM role must have BedrockAgentCoreFullAccess policy"
echo "and trust policy for bedrock-agentcore.amazonaws.com"
echo ""
read -p "Enter IAM role name [BedrockAgentCoreRole]: " ROLE_NAME
ROLE_NAME=${ROLE_NAME:-BedrockAgentCoreRole}

# Verify role exists
log_info "Verifying IAM role exists..."
if aws iam get-role --role-name "$ROLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    log_success "IAM role '$ROLE_NAME' found"
else
    log_warning "IAM role '$ROLE_NAME' not found in account"
    echo "Please create the role with BedrockAgentCoreFullAccess policy"
    echo "See docs/auth.md for instructions"
    read -p "Continue anyway? (yes/no): " continue_anyway
    if [ "$continue_anyway" != "yes" ]; then
        exit 1
    fi
fi

# Step 4: Get Backend Domain
echo ""
log_info "Step 4: Backend Domain Configuration..."
echo "Enter your backend domain name (must have valid SSL certificate)"
read -p "Backend domain: " BACKEND_DOMAIN

if [ -z "$BACKEND_DOMAIN" ]; then
    log_error "Backend domain is required"
    exit 1
fi

# Step 5: Clean up old account data
echo ""
log_info "Step 5: Cleaning up old account data..."
read -p "Remove old gateway and deployment files? (yes/no): " cleanup_old

if [ "$cleanup_old" = "yes" ]; then
    cd "$PROJECT_ROOT"
    
    # Remove old gateway data
    rm -f gateway/.gateway_uri
    rm -f gateway/.access_token
    rm -f gateway/.cognito_config
    log_success "Removed old gateway files"
    
    # Remove old deployment data
    rm -f deployment/.agent_arn
    rm -f deployment/.cognito_config
    log_success "Removed old deployment files"
    
    # Remove old memory data
    rm -f .memory_id
    log_success "Removed old memory files"
fi

# Step 6: Setup Cognito
echo ""
log_info "Step 6: Cognito Setup..."
echo "This will create a new Cognito User Pool, Domain, and App Client"
read -p "Run automated Cognito setup? (yes/no): " setup_cognito

if [ "$setup_cognito" = "yes" ]; then
    cd "$PROJECT_ROOT/deployment"
    
    log_info "Running Cognito setup script..."
    AWS_REGION=$AWS_REGION ./setup_cognito.sh
    
    if [ $? -eq 0 ]; then
        log_success "Cognito setup completed"
        
        # Read Cognito config
        if [ -f ".cognito_config" ]; then
            source .cognito_config
            log_info "Cognito Configuration:"
            echo "  User Pool ID: $USER_POOL_ID"
            echo "  Client ID: $COGNITO_CLIENT_ID"
            echo "  Domain: $COGNITO_DOMAIN"
        fi
    else
        log_error "Cognito setup failed"
        exit 1
    fi
else
    log_warning "Skipping Cognito setup. You'll need to configure it manually."
    echo "Enter Cognito details:"
    read -p "User Pool ID: " USER_POOL_ID
    read -p "Client ID: " COGNITO_CLIENT_ID
fi

# Step 7: Update gateway config
echo ""
log_info "Step 7: Updating Gateway Configuration..."
cd "$PROJECT_ROOT/gateway"

if [ ! -f "config.yaml" ]; then
    log_info "Creating config.yaml from template..."
    cp config.yaml.example config.yaml
fi

# Update config.yaml with new values
log_info "Updating gateway/config.yaml..."

# Use sed to update values (cross-platform compatible)
sed -i.bak "s/account_id: \".*\"/account_id: \"$ACCOUNT_ID\"/" config.yaml
sed -i.bak "s/region: \".*\"/region: \"$AWS_REGION\"/" config.yaml
sed -i.bak "s/role_name: \".*\"/role_name: \"$ROLE_NAME\"/" config.yaml

if [ -n "$USER_POOL_ID" ]; then
    sed -i.bak "s/user_pool_id: \".*\"/user_pool_id: \"$USER_POOL_ID\"/" config.yaml
fi

if [ -n "$COGNITO_CLIENT_ID" ]; then
    sed -i.bak "s/client_id: \".*\"/client_id: \"$COGNITO_CLIENT_ID\"/" config.yaml
fi

# Update endpoint URLs
sed -i.bak "s|endpoint_url: \"https://bedrock-agentcore-control\..*\.amazonaws\.com\"|endpoint_url: \"https://bedrock-agentcore-control.$AWS_REGION.amazonaws.com\"|" config.yaml
sed -i.bak "s|credential_provider_endpoint_url: \"https://bedrock-agentcore-control\..*\.amazonaws\.com\"|credential_provider_endpoint_url: \"https://bedrock-agentcore-control.$AWS_REGION.amazonaws.com\"|" config.yaml

# Update provider ARN
sed -i.bak "s|provider_arn: \"arn:aws:bedrock-agentcore:.*:.*:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider\"|provider_arn: \"arn:aws:bedrock-agentcore:$AWS_REGION:$ACCOUNT_ID:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider\"|" config.yaml

rm -f config.yaml.bak
log_success "Gateway configuration updated"

# Step 8: Generate OpenAPI specs
echo ""
log_info "Step 8: Generating OpenAPI Specifications..."
cd "$PROJECT_ROOT/backend/openapi_specs"
BACKEND_DOMAIN=$BACKEND_DOMAIN ./generate_specs.sh
log_success "OpenAPI specs generated"

# Step 9: Summary
echo ""
echo "=========================================="
log_success "Migration Configuration Complete!"
echo "=========================================="
echo ""
echo "📋 Configuration Summary:"
echo "  AWS Account: $ACCOUNT_ID"
echo "  AWS Region: $AWS_REGION"
echo "  IAM Role: $ROLE_NAME"
echo "  Backend Domain: $BACKEND_DOMAIN"
if [ -n "$USER_POOL_ID" ]; then
    echo "  User Pool ID: $USER_POOL_ID"
    echo "  Client ID: $COGNITO_CLIENT_ID"
fi
echo ""
echo "📁 Updated Files:"
echo "  ✓ gateway/config.yaml"
echo "  ✓ backend/openapi_specs/*.yaml"
if [ "$setup_cognito" = "yes" ]; then
    echo "  ✓ gateway/.env (Cognito credentials)"
fi
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Create the AgentCore Gateway:"
echo "   cd gateway && ./create_gateway.sh && ./mcp_cmds.sh"
echo ""
echo "2. Start backend servers:"
echo "   cd backend"
echo "   TOKEN=\$(curl -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\" -s)"
echo "   PRIVATE_IP=\$(curl -H \"X-aws-ec2-metadata-token: \$TOKEN\" -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "   ./scripts/start_demo_backend.sh --host \$PRIVATE_IP --ssl-keyfile /opt/ssl/privkey.pem --ssl-certfile /opt/ssl/fullchain.pem"
echo ""
echo "3. Configure agent environment:"
echo "   cd sre_agent"
echo "   cp .env.example .env"
echo "   # Update GATEWAY_ACCESS_TOKEN from gateway/.access_token"
echo ""
echo "4. Initialize memory system (takes 10-12 minutes):"
echo "   uv run python scripts/manage_memories.py update"
echo ""
echo "5. Test the agent:"
echo "   sre-agent --prompt \"List pods in production\" --provider bedrock"
echo ""
echo "📖 For detailed instructions, see:"
echo "   - DEPLOYMENT_TO_NEW_ACCOUNT.md"
echo "   - ACCOUNT_MIGRATION_CHECKLIST.md"
echo ""
log_success "Migration helper completed successfully!"
