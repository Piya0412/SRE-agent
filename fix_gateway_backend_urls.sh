#!/bin/bash
# Fix Gateway Backend URLs
# This script regenerates OpenAPI specs with the correct backend domain and re-uploads them

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Fixing Gateway Backend URLs                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [ -f gateway/.env ]; then
    echo "📋 Loading environment variables from gateway/.env..."
    export $(grep -v '^#' gateway/.env | xargs)
else
    echo "❌ Error: gateway/.env not found"
    exit 1
fi

# Check if BACKEND_DOMAIN is set
if [ -z "$BACKEND_DOMAIN" ]; then
    echo "❌ Error: BACKEND_DOMAIN not set in gateway/.env"
    exit 1
fi

echo "🌐 Backend Domain: $BACKEND_DOMAIN"
echo ""

# Check if backend servers are running on this domain
echo "🔍 Checking if backend servers are accessible..."
if curl -s -f -H "X-API-Key: $BACKEND_API_KEY" "http://$BACKEND_DOMAIN:8011/docs" > /dev/null 2>&1; then
    echo "✅ Backend servers are accessible at http://$BACKEND_DOMAIN:8011"
elif curl -s -f -H "X-API-Key: $BACKEND_API_KEY" "https://$BACKEND_DOMAIN:8011/docs" > /dev/null 2>&1; then
    echo "✅ Backend servers are accessible at https://$BACKEND_DOMAIN:8011"
else
    echo "⚠️  Warning: Cannot reach backend servers at $BACKEND_DOMAIN"
    echo "   Make sure backend servers are running and accessible from AWS"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "📝 Regenerating OpenAPI specs with correct backend domain..."

# Regenerate OpenAPI specs
cd backend/openapi_specs
BACKEND_DOMAIN=$BACKEND_DOMAIN ./generate_specs.sh

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate OpenAPI specs"
    exit 1
fi

cd ../..

echo "✅ OpenAPI specs regenerated"
echo ""

# Check if S3 bucket exists
S3_BUCKET="${S3_BUCKET:-sre-agent-specs-1771225925}"
echo "📦 Checking S3 bucket: $S3_BUCKET..."

if aws s3 ls "s3://$S3_BUCKET" > /dev/null 2>&1; then
    echo "✅ S3 bucket exists"
else
    echo "❌ S3 bucket $S3_BUCKET does not exist"
    exit 1
fi

echo ""
echo "📤 Uploading OpenAPI specs to S3..."

# Upload specs to S3
aws s3 cp backend/openapi_specs/k8s_api.yaml "s3://$S3_BUCKET/devops-multiagent-demo/k8s_api.yaml"
aws s3 cp backend/openapi_specs/logs_api.yaml "s3://$S3_BUCKET/devops-multiagent-demo/logs_api.yaml"
aws s3 cp backend/openapi_specs/metrics_api.yaml "s3://$S3_BUCKET/devops-multiagent-demo/metrics_api.yaml"
aws s3 cp backend/openapi_specs/runbooks_api.yaml "s3://$S3_BUCKET/devops-multiagent-demo/runbooks_api.yaml"

echo "✅ OpenAPI specs uploaded to S3"
echo ""

# Update gateway targets to reload the specs
GATEWAY_ID="${GATEWAY_ID:-sre-gateway-rks2qobw3q}"
REGION="${AWS_REGION:-us-east-1}"

echo "🔄 Updating gateway targets to reload OpenAPI specs..."
echo "   Gateway ID: $GATEWAY_ID"
echo "   Region: $REGION"
echo ""

# Get all target IDs
TARGET_IDS=$(aws bedrock-agentcore-control list-gateway-targets \
    --gateway-identifier "$GATEWAY_ID" \
    --region "$REGION" \
    --query 'items[].targetId' \
    --output text)

if [ -z "$TARGET_IDS" ]; then
    echo "❌ No targets found for gateway $GATEWAY_ID"
    exit 1
fi

echo "Found targets: $TARGET_IDS"
echo ""

# Update each target (this forces a reload of the OpenAPI spec from S3)
for TARGET_ID in $TARGET_IDS; do
    echo "🔄 Updating target: $TARGET_ID..."
    
    # Get target details
    TARGET_NAME=$(aws bedrock-agentcore-control get-gateway-target \
        --gateway-identifier "$GATEWAY_ID" \
        --target-id "$TARGET_ID" \
        --region "$REGION" \
        --query 'name' \
        --output text)
    
    # Trigger an update by updating the description (this forces a reload)
    aws bedrock-agentcore-control update-gateway-target \
        --gateway-identifier "$GATEWAY_ID" \
        --target-id "$TARGET_ID" \
        --region "$REGION" \
        --description "Updated $(date +%Y-%m-%d) - $TARGET_NAME" \
        > /dev/null 2>&1
    
    echo "   ✅ Updated $TARGET_NAME"
done

echo ""
echo "⏳ Waiting 10 seconds for targets to update..."
sleep 10

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    SUCCESS                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Gateway backend URLs have been fixed!"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for gateway targets to fully update"
echo "2. Test the agent:"
echo "   cd sre_agent"
echo "   uv run sre-agent --prompt 'List pods in production'"
echo ""
