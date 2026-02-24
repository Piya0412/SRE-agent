#!/bin/bash
# Final deployment to AgentCore Runtime

set -e

export AWS_PROFILE=friend-account
export AWS_REGION=us-east-1

echo "🚀 Deploying to AgentCore Runtime"
echo "================================="
echo ""

# Generate fresh token
echo "🔑 Generating fresh access token..."
python3 gateway/generate_token.py
cp .access_token deployment/.access_token

# Update .env
TOKEN=$(cat .access_token)
cat > deployment/.env << EOF
USER_ID=Alice
LLM_PROVIDER=bedrock
AWS_PROFILE=friend-account
AWS_DEFAULT_REGION=us-east-1
GATEWAY_ACCESS_TOKEN=$TOKEN
EOF

echo "✅ Configuration ready"
echo ""

# Deploy
echo "🚀 Deploying to AgentCore Runtime..."
cd deployment
uv run python deploy_agent_runtime.py \
    --container-uri 573054851765.dkr.ecr.us-east-1.amazonaws.com/sre_agent:latest \
    --role-arn arn:aws:iam::573054851765:role/BedrockAgentCoreRole \
    --runtime-name sre_agent \
    --region us-east-1 \
    --force-recreate

echo ""
echo "🎉 Deployment Complete!"
