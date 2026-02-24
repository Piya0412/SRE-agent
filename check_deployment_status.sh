#!/bin/bash
# Check deployment status

export AWS_PROFILE=friend-account

echo "🔍 Checking Deployment Status"
echo "=============================="
echo ""

# Check if Docker build is running
if pgrep -f "docker build" > /dev/null; then
    echo "🐳 Docker build is still running..."
    echo ""
fi

# Check ECR for latest image
echo "📦 Checking ECR for images..."
aws ecr describe-images \
    --repository-name sre_agent \
    --region us-east-1 \
    --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0], imagePushedAt, imageSizeInBytes]' \
    --output table 2>/dev/null || echo "No images found yet"

echo ""

# Check AgentCore Runtime
echo "🤖 Checking AgentCore Runtime..."
if [ -f deployment/.agent_arn ]; then
    AGENT_ARN=$(cat deployment/.agent_arn)
    echo "Found agent ARN: $AGENT_ARN"
    
    # Get runtime status
    RUNTIME_ID=$(echo $AGENT_ARN | awk -F'/' '{print $NF}')
    aws bedrock-agentcore get-runtime \
        --runtime-identifier "$RUNTIME_ID" \
        --region us-east-1 \
        --query '{Name:name,Status:status,CreatedAt:createdAt}' \
        --output table 2>/dev/null || echo "Runtime not found or not accessible"
else
    echo "No agent deployed yet (.agent_arn file not found)"
fi

echo ""
echo "💡 Tip: Run this script again to check progress"
