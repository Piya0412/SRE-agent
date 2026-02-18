#!/bin/bash
# Configure Cognito Resource Server for Gateway Authentication

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Configuring Cognito Resource Server                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Load Cognito config
cd gateway
source .cognito_config

echo "Step 1: Create Resource Server"
echo "-------------------------------"
echo "User Pool ID: $USER_POOL_ID"
echo ""

# Create resource server with custom scope
echo "Creating resource server 'gateway-api'..."

aws cognito-idp create-resource-server \
    --user-pool-id "$USER_POOL_ID" \
    --identifier "gateway-api" \
    --name "Gateway API Resource Server" \
    --scopes \
        ScopeName=invoke,ScopeDescription="Invoke gateway endpoints" \
    --region us-east-1 > /tmp/resource_server.json 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Resource server created successfully"
    cat /tmp/resource_server.json | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))"
else
    ERROR_MSG=$(cat /tmp/resource_server.json)
    if echo "$ERROR_MSG" | grep -q "ResourceServerIdentifierAlreadyExists"; then
        echo "⚠️  Resource server already exists (this is OK)"
    else
        echo "❌ Error creating resource server:"
        cat /tmp/resource_server.json
        exit 1
    fi
fi

echo ""
echo "Step 2: Update App Client with OAuth Scopes"
echo "--------------------------------------------"
echo "Client ID: $CLIENT_ID"
echo ""

# Update app client to use resource server scopes
echo "Updating app client with OAuth2 configuration..."

aws cognito-idp update-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --allowed-o-auth-flows "client_credentials" \
    --allowed-o-auth-flows-user-pool-client \
    --allowed-o-auth-scopes "gateway-api/invoke" \
    --region us-east-1 > /tmp/client_update.json 2>&1

if [ $? -eq 0 ]; then
    echo "✅ App client updated successfully"
else
    echo "❌ Error updating app client:"
    cat /tmp/client_update.json
    exit 1
fi

echo ""
echo "Step 3: Verify Configuration"
echo "-----------------------------"

# Get app client details
aws cognito-idp describe-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --region us-east-1 \
    --query 'UserPoolClient.{ClientId:ClientId,AllowedOAuthFlows:AllowedOAuthFlows,AllowedOAuthScopes:AllowedOAuthScopes}' \
    --output json

echo ""
echo "✅ Cognito Resource Server Configuration Complete!"
echo ""
echo "Next: Generate JWT token using client credentials flow"
