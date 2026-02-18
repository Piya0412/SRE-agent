#!/bin/bash
# Generate Cognito Access Token for Gateway

set -e

cd gateway

# Load Cognito config
if [ ! -f ".cognito_config" ]; then
    echo "❌ Cognito config not found"
    exit 1
fi

source .cognito_config

echo "Generating Cognito access token..."
echo "User Pool: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo ""

# Create a test user if needed (for client credentials flow)
# For now, we'll use client credentials grant

# Get the domain
DOMAIN="sre-agent-1771399755"
TOKEN_URL="https://${DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token"

echo "Token URL: $TOKEN_URL"
echo ""

# Try to get token using client credentials
echo "Attempting to get access token..."

# Encode client credentials
AUTH_HEADER=$(echo -n "${CLIENT_ID}:${CLIENT_SECRET}" | base64)

# Request token
RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic $AUTH_HEADER" \
    -d "grant_type=client_credentials" \
    -d "scope=openid" 2>&1)

echo "Response: $RESPONSE"
echo ""

# Try to extract access token
ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('access_token', ''))" 2>/dev/null || echo "")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "None" ]; then
    echo "$ACCESS_TOKEN" > .access_token
    echo "✅ Access token saved to .access_token"
    echo "Token length: ${#ACCESS_TOKEN} characters"
    
    # Copy to agent .env
    cd ..
    sed -i "s|GATEWAY_ACCESS_TOKEN=.*|GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN|" sre_agent/.env
    echo "✅ Token updated in sre_agent/.env"
else
    echo "❌ Failed to get access token"
    echo "This is expected - Cognito needs resource server configuration"
    echo ""
    echo "WORKAROUND: Using a test token for now"
    echo "test-token-$(date +%s)" > .access_token
    TEST_TOKEN=$(cat .access_token)
    cd ..
    sed -i "s|GATEWAY_ACCESS_TOKEN=.*|GATEWAY_ACCESS_TOKEN=$TEST_TOKEN|" sre_agent/.env
    echo "⚠️  Using test token (MCP may not work without proper JWT)"
fi
