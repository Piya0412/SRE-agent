# SRE Agent Session Report - February 26, 2026

## Summary
Successfully fixed MCP tools loading issues and completed local x86_64 container testing. Ready for ARM64 build and AgentCore deployment.

---

## TASK 1: Fix SRE Agent Local Deployment - MCP Tools Not Loading
**STATUS**: ✅ COMPLETED

### Problem
- MCP tools failing to load (0 of 20 tools)
- 401 Unauthorized errors from gateway
- ModelErrorException with tool calling

### Root Causes Identified
1. Token generation script saving to wrong location (`.access_token` instead of `gateway/.access_token`)
2. Gateway configured with OLD Cognito account (us-east-1_FDj2YGeRG)
3. Expired/invalid Cognito tokens (expire every 1 hour)
4. Nova Pro v1 model causing ModelErrorException with tool calling
5. Nova Lite v1 doesn't support tool calling via Converse API (used by container)

### Fixes Implemented
1. **Token Generation**: Updated `gateway/generate_token.py` line 87 to save to `"gateway/.access_token"` with directory creation
2. **Gateway Configuration**: Updated Cognito to new account via AWS CLI
   - User Pool ID: `us-east-1_HlFyLjX0m`
   - Client ID: `6h8v378smrepjq85t7brskkv93`
3. **Model Selection**: Switched from Nova Lite v1 to **Nova Premier v1** (`us.amazon.nova-premier-v1:0`)
   - Nova Lite doesn't support Converse API tool calling
   - Nova Premier fully supports Converse API with tool calling
4. **AWS Credentials**: Removed `AWS_PROFILE` from `sre_agent/.env` for container compatibility
5. **Environment Configuration**: Updated all `.env` files with fresh tokens and correct AWS profile

### Testing Results
- ✅ CLI agent works perfectly with Nova Premier
- ✅ Container successfully loads 20 MCP tools
- ✅ Container successfully calls tools via Converse API
- ✅ No ModelErrorException errors
- ✅ Health check passes: `curl -f http://localhost:8080/ping`
- ✅ Agent invocation successful with tool calling

### Files Modified
- `gateway/generate_token.py` - Fixed token save location
- `gateway/config.yaml` - Updated Cognito configuration
- `sre_agent/constants.py` - Changed model to Nova Premier v1
- `sre_agent/.env` - Removed AWS_PROFILE, updated tokens
- `deployment/.env` - Updated tokens
- `.cognito_config` - Updated Cognito details
- `FRIEND_ACCOUNT_DEPLOYMENT_STATUS.md` - Cleaned up old account traces

---

## TASK 2: Build and Test Local x86_64 Container
**STATUS**: ✅ COMPLETED

### Objective
Build local x86_64 container to test packaging before building ARM64 for AgentCore Runtime

### Completed Steps
1. **Dockerfile Updates**:
   - Updated `Dockerfile.x86_64` to use FastAPI entry point
   - Changed health check to `curl -f http://localhost:8080/ping`
   - Changed CMD to `["uv", "run", "uvicorn", "sre_agent.agent_runtime:app", "--host", "0.0.0.0", "--port", "8080"]`

2. **Container Build**:
   - Successfully built image: `sre_agent_test:latest`
   - Command: `LOCAL_BUILD=true PLATFORM=x86_64 ./deployment/build_and_deploy.sh sre_agent_test`

3. **Container Configuration**:
   - Removed AWS_PROFILE from `.env` (causes profile lookup issues in container)
   - Pass AWS credentials as environment variables instead
   - Fresh Cognito token generated before each run

4. **Container Testing**:
   - Container starts successfully and stays healthy
   - MCP tools load: 20 tools (5 k8s, 5 logs, 5 metrics, 5 runbooks)
   - Memory system connects: `sre_agent_memory-r2iiEh726d`
   - Tool calling works via Converse API with Nova Premier
   - Agent successfully processes queries and returns results

### Container Run Command
```bash
docker run -d -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=$(AWS_PROFILE=friend-account aws configure get aws_access_key_id) \
  -e AWS_SECRET_ACCESS_KEY=$(AWS_PROFILE=friend-account aws configure get aws_secret_access_key) \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e GATEWAY_ACCESS_TOKEN=$(cat gateway/.access_token) \
  -e BACKEND_API_KEY=1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b \
  -e GATEWAY_URL=https://sre-gateway-rrhmyjghhe.gateway.bedrock-agentcore.us-east-1.amazonaws.com \
  -e MEMORY_ID=sre_agent_memory-r2iiEh726d \
  -e USER_ID=Alice \
  --name sre_agent_test \
  sre_agent_test:latest
```

### Test Results
```bash
# Health check
curl -f http://localhost:8080/ping  # ✅ SUCCESS

# Agent invocation
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"input": {"prompt": "What pods are in CrashLoopBackOff state?"}}'
# ✅ SUCCESS - Returns investigation results with tool calls
```

---

## TASK 3: Model Selection Journey
**STATUS**: ✅ RESOLVED

### Models Tested
1. **Nova Pro v1** (`us.amazon.nova-pro-v1:0`)
   - ❌ ModelErrorException with tool calling
   - Issue: Model produces invalid sequence for ToolUse

2. **Nova Lite v1** (`us.amazon.nova-lite-v1:0`)
   - ✅ Works in CLI (uses different invocation path)
   - ❌ Fails in container (uses Converse API)
   - Issue: Nova Lite doesn't support tool calling via Converse API

3. **Nova Premier v1** (`us.amazon.nova-premier-v1:0`) - **FINAL CHOICE**
   - ✅ Works in CLI
   - ✅ Works in container
   - ✅ Fully supports Converse API with tool calling
   - ✅ No ModelErrorException errors

### Key Learning
The container uses Bedrock Converse API for tool calling, which requires a model that fully supports it. Nova Lite doesn't support tool calling via Converse API, but Nova Premier does.

---

## Current Configuration

### AWS Account (friend-account)
- **Account ID**: 573054851765
- **Region**: us-east-1
- **Profile**: friend-account

### Cognito Configuration
- **User Pool ID**: us-east-1_HlFyLjX0m
- **Client ID**: 6h8v378smrepjq85t7brskkv93
- **Client Secret**: 1k3qs8i6guovka27darocojta6t6ppkrupi27c3pgt88v5a228rm
- **Domain**: https://sre-agent-1772052612-379.auth.us-east-1.amazoncognito.com
- **Token Expiry**: 1 hour (regenerate with: `AWS_PROFILE=friend-account python gateway/generate_token.py`)

### Gateway & Backend
- **Gateway URL**: https://sre-gateway-rrhmyjghhe.gateway.bedrock-agentcore.us-east-1.amazonaws.com
- **Backend API Key**: 1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
- **Backend Servers**: localhost:8011-8014

### MCP Tools
- **Total Tools**: 20 (5 k8s, 5 logs, 5 metrics, 5 runbooks)
- **Status**: ✅ All loading successfully

### Memory System
- **Memory ID**: sre_agent_memory-r2iiEh726d
- **Memory Name**: sre_agent_memory
- **Status**: ACTIVE
- **User ID**: Alice

### Model Configuration
- **Provider**: bedrock
- **Model**: Nova Premier v1 (`us.amazon.nova-premier-v1:0`)
- **Supports**: Converse API with tool calling

### Container Images
- **Local Test Image**: sre_agent_test:latest (x86_64)
- **ECR Repository**: sre-agent-runtime (for ARM64 deployment)

---

## Next Steps

### 1. Commit Changes
```bash
git add sre_agent/constants.py sre_agent/.env gateway/generate_token.py gateway/config.yaml
git commit -m "Switch to Nova Premier for Converse API tool calling support"
git push
```

### 2. Build ARM64 Image for AgentCore
```bash
# This will build ARM64, push to ECR, and deploy to AgentCore
./deployment/build_and_deploy.sh sre_agent_runtime
```

### 3. Test AgentCore Deployment
- Verify agent loads in AgentCore Runtime
- Test agent invocation via AgentCore API
- Verify MCP tools work in production environment

### 4. Monitor and Validate
- Check CloudWatch logs for any errors
- Verify token refresh mechanism works
- Test with various SRE queries

---

## Important Commands

### Generate Fresh Token
```bash
AWS_PROFILE=friend-account python gateway/generate_token.py
```

### Test CLI Agent
```bash
AWS_PROFILE=friend-account uv run python -m sre_agent.cli --prompt "What pods are in CrashLoopBackOff state?"
```

### Build Local x86_64 Container
```bash
LOCAL_BUILD=true PLATFORM=x86_64 ./deployment/build_and_deploy.sh sre_agent_test
```

### Build and Deploy ARM64 to AgentCore
```bash
./deployment/build_and_deploy.sh sre_agent_runtime
```

### Check Container Logs
```bash
docker logs sre_agent_test 2>&1 | tail -100
```

### Test Container Health
```bash
curl -f http://localhost:8080/ping
```

### Test Container Agent
```bash
curl -X POST http://localhost:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"input": {"prompt": "What pods are in CrashLoopBackOff state?"}}'
```

---

## Troubleshooting Notes

### If MCP Tools Don't Load
1. Check token is valid: `cat gateway/.access_token`
2. Regenerate token: `AWS_PROFILE=friend-account python gateway/generate_token.py`
3. Verify gateway URL is correct
4. Check AWS credentials are passed correctly

### If Container Fails to Start
1. Check AWS credentials are passed as environment variables (not profile)
2. Verify token is fresh (expires every hour)
3. Check container logs: `docker logs sre_agent_test`
4. Ensure `AWS_PROFILE` is NOT in `sre_agent/.env`

### If Tool Calling Fails
1. Verify model is Nova Premier v1 (not Lite or Pro)
2. Check model supports Converse API
3. Review error logs for ModelErrorException
4. Test CLI first to isolate container issues

---

## Architecture Notes

### x86_64 vs ARM64
- **x86_64 = AMD64** (same architecture, different names)
- **ARM64** (required for AgentCore Runtime)
- Build x86_64 locally first to test packaging
- Then build ARM64 for production deployment

### CLI vs Container Differences
- **CLI**: Uses local venv, direct model invocation
- **Container**: Uses fresh packages, Converse API for tool calling
- Models must support Converse API for container deployment
- Package versions can differ between CLI and container

### Converse API Requirements
- Nova Lite: ❌ No tool calling support via Converse API
- Nova Pro: ❌ ModelErrorException with tool calling
- Nova Premier: ✅ Full Converse API tool calling support
- Claude 3.5 Sonnet: ✅ Alternative with excellent tool calling

---

## Session End Status

✅ **All Issues Resolved**
- MCP tools loading successfully (20 tools)
- Container running and healthy on x86_64
- Tool calling working via Converse API with Nova Premier
- Ready for ARM64 build and AgentCore deployment

**Next Session**: Build ARM64 image and deploy to AgentCore Runtime
