#!/bin/bash
# Deploy SRE Agent to AgentCore Runtime in Friend's Account

set -e

echo "🚀 Deploying SRE Agent to AgentCore Runtime"
echo "============================================"
echo ""

# Set AWS profile
export AWS_PROFILE=friend-account
export AWS_REGION=us-east-1

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📋 AWS Account: $ACCOUNT_ID"
echo "📍 Region: $AWS_REGION"
echo ""

# Generate fresh access token
echo "🔑 Generating fresh Cognito access token..."
python3 gateway/generate_token.py
if [ $? -ne 0 ]; then
    echo "❌ Failed to generate access token"
    exit 1
fi

# Copy token to deployment directory
cp .access_token deployment/.access_token
echo "✅ Access token ready"
echo ""

# Update deployment .env with token
echo "📝 Updating deployment configuration..."
TOKEN=$(cat .access_token)
cat > deployment/.env << EOF
# SRE Agent Environment Variables for Friend's Account
USER_ID=Alice
LLM_PROVIDER=bedrock
AWS_PROFILE=friend-account
AWS_DEFAULT_REGION=us-east-1
GATEWAY_ACCESS_TOKEN=$TOKEN
EOF

echo "✅ Configuration updated"
echo ""

# Build and push Docker image
echo "🐳 Building Docker image..."
echo "   This will take 5-10 minutes..."
echo ""

cd deployment
bash build_and_deploy.sh sre_agent

echo ""
echo "🎉 Deployment Complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Check AgentCore Runtime console to see your deployed agent"
echo "   2. Test with: uv run python deployment/invoke_agent_runtime.py --prompt 'List pods in production'"
echo ""
