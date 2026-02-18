#!/bin/bash
# Generate Valid JWT Token from Cognito

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Generating Valid JWT Token                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd gateway
source .cognito_config

DOMAIN="sre-agent-1771399755"
TOKEN_URL="https://${DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token"

echo "Configuration:"
echo "  Domain: $DOMAIN"
echo "  Token URL: $TOKEN_URL"
echo "  Client ID: $CLIENT_ID"
echo "  Scope: gateway-api/invoke"
echo ""

echo "Generating JWT token using client credentials flow..."
echo ""

# Encode credentials for Basic Auth
AUTH_STRING="${CLIENT_ID}:${CLIENT_SECRET}"
AUTH_HEADER=$(echo -n "$AUTH_STRING" | base64 -w 0)

# Request token
RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic $AUTH_HEADER" \
    -d "grant_type=client_credentials" \
    -d "scope=gateway-api/invoke")

echo "Response received:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Extract access token
ACCESS_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('access_token', ''))" 2>/dev/null || echo "")

if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "None" ] && [ ${#ACCESS_TOKEN} -gt 50 ]; then
    echo "✅ JWT Token Generated Successfully!"
    echo ""
    echo "Token Details:"
    echo "  Length: ${#ACCESS_TOKEN} characters"
    echo "  Preview: ${ACCESS_TOKEN:0:50}..."
    echo ""
    
    # Save token
    echo "$ACCESS_TOKEN" > .access_token
    echo "✅ Token saved to gateway/.access_token"
    
    # Update agent .env
    cd ..
    
    # Update sre_agent/.env
    if [ -f "sre_agent/.env" ]; then
        # Remove old token line
        sed -i '/^GATEWAY_ACCESS_TOKEN=/d' sre_agent/.env
        # Add new token
        echo "GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN" >> sre_agent/.env
        echo "✅ Token updated in sre_agent/.env"
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║              JWT TOKEN READY!                               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "✅ Valid JWT token generated and configured"
    echo "✅ Agent can now connect to gateway via MCP"
    echo ""
    echo "Next: Test MCP tools loading"
    echo "  uv run sre-agent --prompt 'List your tools' --provider bedrock"
    
else
    echo "❌ Failed to generate JWT token"
    echo ""
    echo "Response was:"
    echo "$RESPONSE"
    exit 1
fi
