#!/bin/bash

# Docker Image Copy Script
# Copies SRE Agent Docker image from old AWS account to new account

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
OLD_ACCOUNT="${OLD_ACCOUNT:-310485116687}"
NEW_ACCOUNT="${NEW_ACCOUNT:-573054851765}"
REGION="${REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-sre_agent}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

OLD_ECR="${OLD_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"
NEW_ECR="${NEW_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

echo "🚀 Docker Image Copy Script"
echo "============================"
echo ""
log_info "Configuration:"
echo "  Old Account: ${OLD_ACCOUNT}"
echo "  New Account: ${NEW_ACCOUNT}"
echo "  Region: ${REGION}"
echo "  Repository: ${REPO_NAME}"
echo "  Tag: ${IMAGE_TAG}"
echo ""
echo "  Old ECR: ${OLD_ECR}:${IMAGE_TAG}"
echo "  New ECR: ${NEW_ECR}:${IMAGE_TAG}"
echo ""

# Confirm
read -p "Continue with image copy? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    log_error "Copy cancelled"
    exit 0
fi

# Step 1: Create repository in new account
echo ""
log_info "Step 1: Creating ECR repository in new account..."
if aws ecr create-repository \
  --repository-name ${REPO_NAME} \
  --region ${REGION} \
  --profile friend-account 2>/dev/null; then
    log_success "Repository created"
else
    log_warning "Repository already exists (this is OK)"
fi

# Step 2: Login to old account ECR
echo ""
log_info "Step 2: Logging into old account ECR..."
if aws ecr get-login-password \
  --region ${REGION} \
  --profile old-account 2>/dev/null | docker login \
  --username AWS \
  --password-stdin ${OLD_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com; then
    log_success "Logged into old account ECR"
else
    log_error "Failed to login to old account ECR"
    echo "Make sure you have AWS CLI profile 'old-account' configured"
    exit 1
fi

# Step 3: Pull image from old account
echo ""
log_info "Step 3: Pulling image from old account..."
log_info "This may take a few minutes depending on image size..."
if docker pull ${OLD_ECR}:${IMAGE_TAG}; then
    log_success "Image pulled successfully"
else
    log_error "Failed to pull image from old account"
    exit 1
fi

# Step 4: Tag for new account
echo ""
log_info "Step 4: Tagging image for new account..."
if docker tag ${OLD_ECR}:${IMAGE_TAG} ${NEW_ECR}:${IMAGE_TAG}; then
    log_success "Image tagged"
else
    log_error "Failed to tag image"
    exit 1
fi

# Step 5: Login to new account ECR
echo ""
log_info "Step 5: Logging into new account ECR..."
if aws ecr get-login-password \
  --region ${REGION} \
  --profile friend-account 2>/dev/null | docker login \
  --username AWS \
  --password-stdin ${NEW_ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com; then
    log_success "Logged into new account ECR"
else
    log_error "Failed to login to new account ECR"
    echo "Make sure you have AWS CLI profile 'friend-account' configured"
    exit 1
fi

# Step 6: Push to new account
echo ""
log_info "Step 6: Pushing image to new account..."
log_info "This may take a few minutes depending on image size..."
if docker push ${NEW_ECR}:${IMAGE_TAG}; then
    log_success "Image pushed successfully"
else
    log_error "Failed to push image to new account"
    exit 1
fi

# Step 7: Verify
echo ""
log_info "Step 7: Verifying image in new account..."
if aws ecr describe-images \
  --repository-name ${REPO_NAME} \
  --region ${REGION} \
  --profile friend-account >/dev/null 2>&1; then
    log_success "Image verified in new account"
else
    log_warning "Could not verify image (but push succeeded)"
fi

# Summary
echo ""
echo "=========================================="
log_success "Docker Image Copy Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  Source: ${OLD_ECR}:${IMAGE_TAG}"
echo "  Destination: ${NEW_ECR}:${IMAGE_TAG}"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Deploy to AgentCore Runtime:"
echo "   cd deployment"
echo "   uv run python deploy_agent_runtime.py \\"
echo "     --container-uri ${NEW_ECR}:${IMAGE_TAG} \\"
echo "     --role-arn arn:aws:iam::${NEW_ACCOUNT}:role/BedrockAgentCoreRole \\"
echo "     --runtime-name sre_agent_v1 \\"
echo "     --region ${REGION}"
echo ""
echo "2. Test the runtime:"
echo "   uv run python deployment/invoke_agent_runtime.py \\"
echo "     --prompt \"List pods in production\""
echo ""
log_success "Image copy completed successfully!"
