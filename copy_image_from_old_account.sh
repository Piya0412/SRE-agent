#!/bin/bash
# Copy ARM64 image from old account to friend's account

set -e

OLD_ACCOUNT=310485116687
NEW_ACCOUNT=573054851765
REGION=us-east-1
REPO_NAME=sre_agent

echo "🔄 Copying ARM64 image from old account to friend's account"
echo "============================================================"

# Login to old account ECR
echo "🔐 Logging in to old account ECR..."
aws ecr get-login-password --region $REGION --profile old-account | \
    docker login --username AWS --password-stdin $OLD_ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Pull the ARM64 image from old account
echo "⬇️  Pulling ARM64 image from old account..."
# Use the digest of the ARM64 image
docker pull --platform linux/arm64 $OLD_ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME@sha256:8c7d88cfbf78146bc8792594ea6e553d66dcb0fd4ce4e19a4d6a4eff0e39dc37

# Tag for new account
echo "🏷️  Tagging for friend's account..."
docker tag $OLD_ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME@sha256:8c7d88cfbf78146bc8792594ea6e553d66dcb0fd4ce4e19a4d6a4eff0e39dc37 \
    $NEW_ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

# Login to new account ECR
echo "🔐 Logging in to friend's account ECR..."
aws ecr get-login-password --region $REGION --profile friend-account | \
    docker login --username AWS --password-stdin $NEW_ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Push to new account
echo "⬆️  Pushing to friend's account ECR..."
docker push $NEW_ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

echo ""
echo "✅ Image copied successfully!"
echo ""
echo "Verifying architecture..."
docker inspect $NEW_ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest | jq -r '.[0].Architecture'
