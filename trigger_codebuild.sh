#!/bin/bash
# Trigger CodeBuild to build ARM64 Docker image

set -e

export AWS_PROFILE=friend-account
export AWS_REGION=us-east-1

PROJECT_NAME="sre-agent-arm64-build"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Triggering CodeBuild for ARM64 Docker build"
echo "=============================================="
echo ""

# Step 1: Create S3 bucket for source code (if needed)
BUCKET_NAME="codebuild-sre-agent-${ACCOUNT_ID}"

if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "✅ S3 bucket exists: $BUCKET_NAME"
else
    echo "📦 Creating S3 bucket: $BUCKET_NAME"
    aws s3 mb "s3://${BUCKET_NAME}" --region $AWS_REGION
fi

# Step 2: Package source code
echo "📦 Packaging source code..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SOURCE_ZIP="sre-agent-source-${TIMESTAMP}.zip"

# Create zip with necessary files
zip -r /tmp/$SOURCE_ZIP \
    buildspec.yml \
    Dockerfile \
    pyproject.toml \
    uv.lock \
    sre_agent/ \
    backend/ \
    gateway/ \
    scripts/ \
    -x "*.pyc" "*__pycache__*" "*.git*" "*node_modules*" "*.venv*" "*logs/*" "*reports/*"

echo "✅ Source packaged: /tmp/$SOURCE_ZIP"

# Step 3: Upload to S3
echo "⬆️  Uploading source to S3..."
aws s3 cp /tmp/$SOURCE_ZIP "s3://${BUCKET_NAME}/$SOURCE_ZIP"
echo "✅ Uploaded to s3://${BUCKET_NAME}/$SOURCE_ZIP"

# Step 4: Start CodeBuild
echo ""
echo "🚀 Starting CodeBuild..."

BUILD_ID=$(aws codebuild start-build \
    --project-name $PROJECT_NAME \
    --source-location-override "s3://${BUCKET_NAME}/$SOURCE_ZIP" \
    --source-type-override S3 \
    --query 'build.id' \
    --output text)

echo "✅ Build started!"
echo "   Build ID: $BUILD_ID"
echo ""

# Step 5: Monitor build
echo "📊 Monitoring build progress..."
echo "   (Press Ctrl+C to stop monitoring, build will continue)"
echo ""

while true; do
    BUILD_STATUS=$(aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].buildStatus' --output text)
    PHASE=$(aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].currentPhase' --output text)
    
    echo "   Status: $BUILD_STATUS | Phase: $PHASE"
    
    if [ "$BUILD_STATUS" = "SUCCEEDED" ]; then
        echo ""
        echo "🎉 Build completed successfully!"
        echo ""
        echo "📦 Docker image pushed to ECR:"
        echo "   ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/sre_agent:latest"
        echo ""
        echo "📋 Next step: Deploy to AgentCore Runtime"
        echo "   bash deploy_runtime_final.sh"
        break
    elif [ "$BUILD_STATUS" = "FAILED" ] || [ "$BUILD_STATUS" = "FAULT" ] || [ "$BUILD_STATUS" = "TIMED_OUT" ] || [ "$BUILD_STATUS" = "STOPPED" ]; then
        echo ""
        echo "❌ Build failed with status: $BUILD_STATUS"
        echo ""
        echo "📋 View logs:"
        echo "   aws codebuild batch-get-builds --ids $BUILD_ID --query 'builds[0].logs.deepLink' --output text"
        exit 1
    fi
    
    sleep 10
done

# Cleanup
rm -f /tmp/$SOURCE_ZIP

echo ""
echo "🔗 View build in AWS Console:"
echo "   https://console.aws.amazon.com/codesuite/codebuild/projects/$PROJECT_NAME/build/$BUILD_ID?region=$AWS_REGION"
