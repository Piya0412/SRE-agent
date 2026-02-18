#!/bin/bash
# Complete Cognito Configuration for Gateway Authentication

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Cognito Resource Server & OAuth2 Configuration         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Load Cognito config
cd gateway
source .cognito_config

echo "Step 1: Configure Cognito Resource Server"
echo "==========================================="
echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo ""

# Step 1: Create Resource Server
echo "Creating resource server..."
RESOURCE_SERVER_ID="gateway-api"
RESOURCE_SERVER_NAME="Gateway API"

aws cognito-idp create-resource-server \
    --user-pool-id "$USER_POOL_ID" \
    --identifier "$RESOURCE_SERVER_ID" \
    --name "$RESOURCE_SERVER_NAME" \
    --scopes \
        ScopeName=invoke,ScopeDescription="Invoke gateway endpoints" \
    --region us-east-1 2>&1 | tee /tmp/resource_server.json

if [ $? -eq 0 ]; then
    echo "✅ Resource server created: $RESOURCE_SERVER_ID"
else
    # Check if it already exists
    if grep -q "ResourceServerAlreadyExists" /tmp/resource_server.json; then
        echo "✅ Resource server already exists: $RESOURCE_SERVER_ID"
    else
        echo "❌ Failed to create resource server"
        cat /tmp/resource_server.json
        exit 1
    fi
fi

echo ""
echo "Step 2: Update App Client with OAuth2 Scopes"
echo "============================================="

# Update app client to support client credentials flow
aws cognito-idp update-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --allowed-o-auth-flows client_credentials \
    --allowed-o-auth-flows-user-pool-client \
    --allowed-o-auth-scopes "${RESOURCE_SERVER_ID}/invoke" \
    --region us-east-1 2>&1

if [ $? -eq 0 ]; then
    echo "✅ App client updated with OAuth2 scopes"
else
    echo "⚠️  App client update had issues, but may still work"
fi

echo ""
echo "Step 3: Generate JWT Token"
echo "=========================="

# Get Cognito domain
DOMAIN="sre-agent-1771399755"
TOKEN_URL="https://${DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token"

echo "Token URL: $TOKEN_URL"
echo "Requesting access token..."

# Create base64 encoded credentials
AUTH_STRING="${CLIENT_ID}:${CLIENT_SECRET}"
AUTH_HEADER=$(echo -n "$AUTH_STRING" | base64 -w 0)

# Request token
RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic $AUTH_HEADER" \
    -d "grant_type=client_credentials" \
    -d "scope=${RESOURCE_SERVER_ID}/invoke")

echo "Response received"

# Extract access token
ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('access_token', ''))
except:
    print('')
" 2>/dev/null)

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "None" ] && [ ${#ACCESS_TOKEN} -gt 50 ]; then
    echo "✅ Valid JWT token generated!"
    echo "   Token length: ${#ACCESS_TOKEN} characters"
    
    # Save token
    echo "$ACCESS_TOKEN" > .access_token
    echo "✅ Token saved to gateway/.access_token"
    
    # Update agent .env
    cd ..
    sed -i "s|GATEWAY_ACCESS_TOKEN=.*|GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN|" sre_agent/.env
    echo "✅ Token updated in sre_agent/.env"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                  SUCCESS!                                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ Cognito Resource Server: Configured"
    echo "✅ OAuth2 Scopes: Added"
    echo "✅ JWT Token: Generated and saved"
    echo ""
    echo "Token preview: ${ACCESS_TOKEN:0:50}..."
    echo ""
    echo "Next: Test MCP tools with:"
    echo "  uv run sre-agent --prompt 'What tools do you have?' --provider bedrock"
    
else
    echo "❌ Failed to generate valid JWT token"
    echo "Response: $RESPONSE"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if resource server was created successfully"
    echo "2. Verify app client has correct OAuth flows enabled"
    echo "3. Check Cognito domain is accessible"
    exit 1
fi
