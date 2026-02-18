#!/bin/bash
# Day 3 - AgentCore Gateway Setup Script
# Follows AWS Best Practices for Bedrock AgentCore Gateway

set -e  # Exit on error

PROJECT_ROOT="/home/piyush/projects/SRE-agent"
cd "$PROJECT_ROOT"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          DAY 3: AgentCore Gateway Setup                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# PHASE 0: Prerequisites Check
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "  PHASE 0: Prerequisites Check"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check backend servers
BACKEND_COUNT=$(ps aux | grep python | grep server | grep -v grep | wc -l)
echo "Backend Servers: $BACKEND_COUNT/4"

if [ "$BACKEND_COUNT" -ne 4 ]; then
    echo "⚠️  Backend servers not running. Starting them..."
    cd backend
    export BACKEND_API_KEY="1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b"
    nohup ./scripts/start_demo_backend.sh --host 127.0.0.1 > ../logs/backend_startup.log 2>&1 &
    cd ..
    echo "   Waiting for backends to start..."
    sleep 5
    BACKEND_COUNT=$(ps aux | grep python | grep server | grep -v grep | wc -l)
    echo "   Backend Servers now: $BACKEND_COUNT/4"
fi

# Check S3 bucket
if [ -f ".s3_bucket_name" ]; then
    BUCKET_NAME=$(cat .s3_bucket_name)
    echo "✅ S3 Bucket: $BUCKET_NAME"
    
    SPEC_COUNT=$(aws s3 ls s3://$BUCKET_NAME/ 2>/dev/null | wc -l)
    echo "   OpenAPI specs in S3: $SPEC_COUNT files"
else
    echo "❌ S3 bucket not configured - BLOCKER"
    exit 1
fi

# Check for existing gateway
if [ -f "gateway/.gateway_uri" ]; then
    EXISTING_URI=$(cat gateway/.gateway_uri)
    echo "⚠️  Existing gateway found: $EXISTING_URI"
    echo "   Will reuse if still active"
fi

echo ""

# ============================================================================
# PHASE 1: Gateway Configuration
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "  PHASE 1: Gateway Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Step 1.1: Cognito Setup
echo "Step 1.1: Cognito Identity Provider Setup"
echo "-------------------------------------------"

cd gateway

# Check if Cognito already configured
if [ -f ".cognito_config" ]; then
    echo "✅ Cognito config already exists"
    source .cognito_config
    echo "   User Pool ID: $USER_POOL_ID"
    echo "   Client ID: $CLIENT_ID"
else
    echo "Creating new Cognito User Pool..."
    
    # Create user pool
    aws cognito-idp create-user-pool \
        --pool-name "sre-agent-user-pool" \
        --policies "PasswordPolicy={MinimumLength=8,RequireUppercase=false,RequireLowercase=false,RequireNumbers=false,RequireSymbols=false}" \
        --auto-verified-attributes email \
        --region us-east-1 > /tmp/cognito_pool.json
    
    USER_POOL_ID=$(python3 -c "import sys,json; print(json.load(open('/tmp/cognito_pool.json'))['UserPool']['Id'])")
    echo "✅ User Pool created: $USER_POOL_ID"
    
    # Create app client
    aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name "sre-agent-client" \
        --generate-secret \
        --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
        --region us-east-1 > /tmp/cognito_client.json
    
    CLIENT_ID=$(python3 -c "import sys,json; print(json.load(open('/tmp/cognito_client.json'))['UserPoolClient']['ClientId'])")
    CLIENT_SECRET=$(python3 -c "import sys,json; print(json.load(open('/tmp/cognito_client.json'))['UserPoolClient']['ClientSecret'])")
    
    echo "✅ App Client created: $CLIENT_ID"
    
    # Save configuration
    cat > .cognito_config << EOF
USER_POOL_ID=$USER_POOL_ID
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET
REGION=us-east-1
EOF
    
    echo "✅ Cognito config saved to .cognito_config"
fi

echo ""

# Step 1.2: Gateway Configuration File
echo "Step 1.2: Gateway Configuration File"
echo "-------------------------------------"

source .cognito_config
S3_BUCKET=$(cat ../.s3_bucket_name)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Get IAM role name (current role or default)
ROLE_ARN=$(aws sts get-caller-identity --query Arn --output text)
if echo "$ROLE_ARN" | grep -q "assumed-role"; then
    ROLE_NAME=$(echo "$ROLE_ARN" | cut -d'/' -f2)
else
    # If not using a role, we need to create one or use existing
    echo "⚠️  Not running with IAM role. Checking for existing gateway role..."
    ROLE_NAME="BedrockAgentCoreGatewayRole"
fi

echo "Configuration values:"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo "  Role Name: $ROLE_NAME"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
echo "  S3 Bucket: $S3_BUCKET"

# Create config.yaml from example if needed
if [ ! -f "config.yaml" ]; then
    if [ -f "config.yaml.example" ]; then
        cp config.yaml.example config.yaml
        echo "✅ Created config.yaml from example"
    fi
fi

# Update config.yaml using Python
python3 << EOF
import yaml

with open('config.yaml', 'r') as f:
    config = yaml.safe_load(f) or {}

config['account_id'] = '$ACCOUNT_ID'
config['region'] = '$REGION'
config['role_name'] = '$ROLE_NAME'
config['user_pool_id'] = '$USER_POOL_ID'
config['client_id'] = '$CLIENT_ID'
config['s3_bucket'] = '$S3_BUCKET'
config['gateway_name'] = 'sre-gateway'
config['credential_provider_name'] = 'sre-agent-api-key-credential-provider'

with open('config.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False)

print("✅ config.yaml updated")
EOF

echo ""

# Step 1.3: Environment Variables
echo "Step 1.3: Gateway Environment Variables"
echo "----------------------------------------"

cat > .env << EOF
# Cognito Configuration
COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_CLIENT_ID=$CLIENT_ID
COGNITO_CLIENT_SECRET=$CLIENT_SECRET
COGNITO_REGION=$REGION

# AWS Configuration
AWS_REGION=$REGION
AWS_ACCOUNT_ID=$ACCOUNT_ID

# Backend Configuration
BACKEND_DOMAIN=127.0.0.1
BACKEND_API_KEY=1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
EOF

echo "✅ .env file created"

cd ..
echo ""

# ============================================================================
# PHASE 2: Gateway Creation
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "  PHASE 2: Gateway Creation"
echo "═══════════════════════════════════════════════════════════"
echo ""

cd gateway

# Step 2.1: Create Gateway
echo "Step 2.1: Create AgentCore Gateway"
echo "-----------------------------------"

if [ -f ".gateway_uri" ]; then
    GATEWAY_URI=$(cat .gateway_uri)
    GATEWAY_ID=$(echo "$GATEWAY_URI" | grep -oP '(?<=https://)[^.]+')
    
    echo "Checking existing gateway: $GATEWAY_ID"
    GATEWAY_STATUS=$(aws bedrock-agentcore get-gateway \
        --gateway-identifier "$GATEWAY_ID" \
        --region us-east-1 \
        --query 'status' \
        --output text 2>&1 || echo "NOT_FOUND")
    
    if [ "$GATEWAY_STATUS" = "ACTIVE" ]; then
        echo "✅ Gateway already active: $GATEWAY_ID"
        echo "   Skipping creation, will reuse existing gateway"
    else
        echo "⚠️  Existing gateway not active. Creating new gateway..."
        chmod +x create_gateway.sh
        ./create_gateway.sh
    fi
else
    echo "Creating new gateway..."
    chmod +x create_gateway.sh
    ./create_gateway.sh
fi

# Verify gateway was created
if [ ! -f ".gateway_uri" ]; then
    echo "❌ Gateway creation failed - no URI file found"
    exit 1
fi

GATEWAY_URI=$(cat .gateway_uri)
echo "✅ Gateway URI: $GATEWAY_URI"

cd ..
echo ""

# ============================================================================
# PHASE 3: Agent Configuration
# ============================================================================
echo "═══════════════════════════════════════════════════════════"
echo "  PHASE 3: Agent Configuration"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Step 3.1: Configure Agent with Gateway"
echo "---------------------------------------"

# Load gateway URI and token
GATEWAY_URI=$(cat gateway/.gateway_uri)
ACCESS_TOKEN=$(cat gateway/.access_token 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
    echo "⚠️  No access token found, generating..."
    cd gateway
    python3 generate_token.py --audience MCPGateway
    ACCESS_TOKEN=$(cat .access_token)
    cd ..
fi

echo "Gateway URI: $GATEWAY_URI"
echo "Access Token: ${ACCESS_TOKEN:0:50}... (${#ACCESS_TOKEN} chars)"

# Update agent config if needed
if [ -f "sre_agent/config/agent_config.yaml" ]; then
    # Check current URI
    CURRENT_URI=$(grep "uri:" sre_agent/config/agent_config.yaml | grep -oP '(?<=uri: ")[^"]+' || echo "")
    
    if [ "$CURRENT_URI" != "$GATEWAY_URI" ]; then
        echo "Updating gateway URI in agent_config.yaml..."
        sed -i "s|uri: \".*\"|uri: \"$GATEWAY_URI\"|" sre_agent/config/agent_config.yaml
        echo "✅ URI updated"
    else
        echo "✅ URI already correct"
    fi
fi

# Update/create agent .env
if [ -f "sre_agent/.env" ]; then
    # Remove old token
    sed -i '/^GATEWAY_ACCESS_TOKEN=/d' sre_agent/.env
    echo "GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN" >> sre_agent/.env
    echo "✅ Access token updated in sre_agent/.env"
else
    cat > sre_agent/.env << EOF
# AWS Configuration
AWS_REGION=us-east-1

# Gateway Access Token
GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN

# Debug mode
DEBUG=false
EOF
    echo "✅ Created sre_agent/.env with token"
fi

echo ""
echo "✅ Day 3 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Test gateway connection: cd gateway && curl test"
echo "2. Run agent test: uv run sre-agent --prompt 'What tools do you have?'"
echo ""
