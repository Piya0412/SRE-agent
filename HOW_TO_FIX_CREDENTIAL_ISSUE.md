# How to Fix the Gateway Credential Issue

## ⚠️ IMPORTANT: What This Document Is About

**You asked: "Are we doing all this just for testing? In the end, do we deploy to AgentCore Runtime?"**

**Answer:** You're partially correct! Let me clarify:

### Two Separate Deployments

```
┌─────────────────────────────────────────────────────────────────┐
│ DEPLOYMENT 1: Backend APIs (THIS DOCUMENT)                      │
│ ─────────────────────────────────────────────────────────────── │
│ What: 4 demo servers (k8s, logs, metrics, runbooks)             │
│ Where: EC2 instance with public domain + SSL                    │
│ Why: Gateway needs to call these to get data                    │
│ Status: PERMANENT (not just for testing)                        │
│                                                                 │
│ Testing option: ngrok (temporary, for quick testing)            │
│ Production option: EC2 (permanent, for real use)                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ DEPLOYMENT 2: SRE Agent (COMES LATER)                           │
│ ─────────────────────────────────────────────────────────────── │
│ What: Your AI agent (multi-agent system)                        │
│ Where: AgentCore Runtime (as Docker container)                  │
│ Why: To make it accessible via API for production use           │
│ Status: FINAL production deployment                             │
│                                                                 │
│ Steps:                                                          │
│ 1. Fix backend first (this document) ✅                          │
│ 2. Test agent locally: uv run sre-agent ✅                       │
│ 3. Build Docker image ✅                                         │
│ 4. Deploy to AgentCore Runtime ✅ FINAL STEP                     │
└─────────────────────────────────────────────────────────────────┘
```

### The Complete Journey

**Phase 1: Fix Backend (THIS DOCUMENT)**
- Backend APIs must be accessible from AWS
- Use EC2 for production OR ngrok for quick testing
- Backend stays running permanently (not just for testing)

**Phase 2: Test Agent Locally**
- Run: `uv run sre-agent --prompt "List pods"`
- Verify agent can call Gateway → Gateway can call Backend
- This confirms everything works end-to-end

**Phase 3: Deploy Agent to AgentCore Runtime (FINAL)**
- Build Docker image: `./deployment/build_and_deploy.sh`
- Deploy to AgentCore Runtime
- Now your agent runs in AWS and can be called via API

**So YES, you're correct!** The backend deployment is needed for the agent to work, and the final step is deploying the agent to AgentCore Runtime.

---

## The Real Problem

The error message "Failed to obtain execution role credentials" is **misleading**. The actual problem is:

**Your backend servers are running on `127.0.0.1` (localhost), but the AWS Gateway is running in AWS cloud and CANNOT reach localhost!**

```
┌─────────────────────────────────────────────────────────────┐
│ YOUR LOCAL MACHINE                                          │
│ ─────────────────────────────────────────────────────────── │
│ Backend servers running on:                                 │
│ - http://127.0.0.1:8011 (k8s-api)                           │
│ - http://127.0.0.1:8012 (logs-api)                          │
│ - http://127.0.0.1:8013 (metrics-api)                       │
│ - http://127.0.0.1:8014 (runbooks-api)                      │
└─────────────────────────────────────────────────────────────┘
                            ↑
                            │ ❌ CANNOT REACH!
                            │
┌─────────────────────────────────────────────────────────────┐
│ AWS CLOUD (us-east-1)                                       │
│ ─────────────────────────────────────────────────────────── │
│ Gateway trying to call:                                     │
│ - https://your-backend-domain.com:8011                      │
│   (from OpenAPI spec in S3)                                 │
│                                                             │
│ But this domain doesn't exist or points to localhost!       │
└─────────────────────────────────────────────────────────────┘
```

## Why This Happens

According to the README, this project is designed to run on an **EC2 instance** with:
1. Backend servers running on the EC2 instance
2. A **public domain name** (e.g., from no-ip.com)
3. **SSL certificates** (e.g., from Let's Encrypt)
4. Backend servers accessible via HTTPS from the internet

But you're running it on your **local machine (WSL)** which the AWS Gateway cannot reach.

---

## Understanding What Needs to Be Deployed

**IMPORTANT CLARIFICATION:**

There are **TWO separate things** you need to deploy:

1. **Backend APIs (4 demo servers)** ← This is what these options are about!
   - These serve fake data (pods, logs, metrics, runbooks)
   - Must be accessible from AWS Gateway via HTTPS
   - Options: EC2, ngrok, Lambda, etc.

2. **SRE Agent (your AI agent)** ← This is deployed separately later!
   - This is your Python code with the multi-agent system
   - Will be deployed to AgentCore Runtime as a Docker container
   - This is Option C (comes after you fix the backend)

**So YES, you're correct!** The options below are for **testing the backend APIs** so your agent can access them. Once backend is working, you'll deploy the agent to AgentCore Runtime.

---

## Solution Options (For Backend APIs Only)

### Option 1: Run Backend on EC2 Instance (Recommended for Production)

This is the intended setup from the README.

**Steps:**

1. **Launch an EC2 instance** (t3.xlarge or larger)

2. **Register a domain name** (e.g., using no-ip.com)
   - Point it to your EC2 instance's public IP

3. **Get SSL certificates** (e.g., using Let's Encrypt)
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```

4. **Configure backend domain** in `gateway/.env`:
   ```bash
   BACKEND_DOMAIN=your-domain.com
   ```

5. **Start backend servers with SSL**:
   ```bash
   cd backend
   ./scripts/start_demo_backend.sh \
     --host 0.0.0.0 \
     --ssl-keyfile /etc/letsencrypt/live/your-domain.com/privkey.pem \
     --ssl-certfile /etc/letsencrypt/live/your-domain.com/fullchain.pem
   ```

6. **Regenerate and upload OpenAPI specs**:
   ```bash
   cd backend/openapi_specs
   BACKEND_DOMAIN=your-domain.com ./generate_specs.sh
   
   # Upload to S3
   aws s3 cp k8s_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/
   aws s3 cp logs_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/
   aws s3 cp metrics_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/
   aws s3 cp runbooks_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/
   ```

7. **Update gateway targets** (forces reload of OpenAPI specs):
   ```bash
   # Run the fix script
   bash fix_gateway_backend_urls.sh
   ```

8. **Test the agent**:
   ```bash
   cd sre_agent
   uv run sre-agent --prompt "List pods in production"
   ```

---

### Option 2: Use ngrok for Local Testing (Quick Fix)

If you want to test locally without EC2, use ngrok to expose your local backend to the internet.

**Steps:**

1. **Install ngrok**:
   ```bash
   # Download from https://ngrok.com/download
   # Or use snap:
   sudo snap install ngrok
   ```

2. **Start ngrok tunnels** (you need 4 tunnels for 4 backend servers):
   ```bash
   # Terminal 1
   ngrok http 8011
   
   # Terminal 2
   ngrok http 8012
   
   # Terminal 3
   ngrok http 8013
   
   # Terminal 4
   ngrok http 8014
   ```

3. **Get the ngrok URLs** (e.g., `https://abc123.ngrok.io`)

4. **Update OpenAPI specs manually** with ngrok URLs:
   ```yaml
   # backend/openapi_specs/k8s_api.yaml.template
   servers:
     - url: https://abc123.ngrok.io  # Your ngrok URL for port 8011
   ```

5. **Regenerate and upload specs**:
   ```bash
   cd backend/openapi_specs
   ./generate_specs.sh
   
   # Upload to S3
   aws s3 cp k8s_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/
   # ... repeat for other specs
   ```

6. **Update gateway targets** to reload specs

7. **Test the agent**

**Limitations:**
- ngrok free tier has rate limits
- URLs change every time you restart ngrok
- Not suitable for production

---

### Option 3: Deploy to AgentCore Runtime (Skip Gateway Testing)

**IMPORTANT:** This option still requires Option 1 or 2 first!

If you don't need to test the Gateway locally, you can skip straight to deploying the agent as a container to AgentCore Runtime. But the backend APIs must still be accessible from AWS.

**Steps:**

1. **First, deploy backend APIs** (use Option 1 or 2 above)
   - Backend must be accessible via HTTPS from AWS

2. **Then, build and deploy the agent container**:
   ```bash
   cd deployment
   ./build_and_deploy.sh
   ```

3. **The container will run in AWS** and can reach the Gateway

4. **Test via AgentCore Runtime**:
   ```bash
   python invoke_agent_runtime.py --prompt "List pods in production"
   ```

**Note:** This deploys your AGENT to AWS, but backend APIs still need to be accessible (Option 1 or 2).

---

## Complete Deployment Flow (The Full Picture)

Here's what you need to understand about the complete deployment:

### Phase 1: Deploy Backend APIs (What these options are about)

```
┌─────────────────────────────────────────────────────────────────┐
│ BACKEND APIs (4 demo servers)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Choose ONE option:                                              │
│ ├── Option 1: EC2 with domain + SSL (production)               │
│ ├── Option 2: ngrok tunnels (quick testing)                    │
│ └── Option 4: Mock Lambda (not recommended)                    │
│                                                                 │
│ Result: Backend APIs accessible via HTTPS from AWS             │
│         Example: https://my-backend.com:8011                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Purpose:** So AgentCore Gateway can call your backend APIs

**Testing:** Run agent locally to verify backend works
```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production"
```

---

### Phase 2: Deploy SRE Agent to AgentCore Runtime (Option 3)

```
┌─────────────────────────────────────────────────────────────────┐
│ SRE AGENT (your AI agent)                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. Build Docker image (ARM64 for AWS)                          │
│    cd deployment                                                │
│    ./build_and_deploy.sh                                        │
│                                                                 │
│ 2. Push to ECR (Amazon's Docker registry)                      │
│    (script does this automatically)                            │
│                                                                 │
│ 3. Deploy to AgentCore Runtime                                 │
│    (script does this automatically)                            │
│                                                                 │
│ Result: Agent running in AWS, accessible via API               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Purpose:** Production deployment of your agent in AWS

**Testing:** Invoke via AgentCore Runtime API
```bash
python deployment/invoke_agent_runtime.py --prompt "List pods"
```

---

## The Complete Picture

```
┌─────────────────────────────────────────────────────────────────┐
│ WHAT YOU NEED TO DEPLOY                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. BACKEND APIs (Phase 1)                                      │
│    ├── Where: EC2 instance (or ngrok for testing)              │
│    ├── What: 4 FastAPI servers serving fake data               │
│    ├── Why: So Gateway can call them                           │
│    └── Status: ❌ Currently on localhost (broken)               │
│                                                                 │
│ 2. SRE AGENT (Phase 2)                                         │
│    ├── Where: AgentCore Runtime (AWS managed)                  │
│    ├── What: Docker container with your agent code             │
│    ├── Why: Production deployment                              │
│    └── Status: ⏳ Not deployed yet                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Your Understanding is Correct!

**You said:**
> "So we are doing all this only for testing and to know if our agents are giving the output or not, correct? And in the end we have to build a docker image and have to deploy in Agentcore runtime, correct?"

**Answer:** YES, exactly right! Let me break it down:

### What Options 1, 2, 4 Are For:

✅ **Testing the backend APIs** - Making sure Gateway can reach them
✅ **Verifying the agent works** - Running agent locally to test
✅ **Development and debugging** - Iterating on your agent code

**These are NOT the final deployment!** They're just to get the backend working so you can test.

### The Final Deployment (Option 3):

✅ **Build Docker image** - Package your agent as a container
✅ **Deploy to AgentCore Runtime** - Production deployment in AWS
✅ **Agent runs in AWS** - Fully managed, scalable, production-ready

---

## Recommended Path for You

Since you want production deployment, here's what you should do:

### Step 1: Deploy Backend to EC2 (Option 1)

**Why:** Production-ready, no rate limits, stable URLs

```bash
1. Launch EC2 instance (t3.xlarge)
2. Get domain name (no-ip.com or similar)
3. Get SSL certificates (Let's Encrypt)
4. Deploy backend servers with SSL
5. Update OpenAPI specs with your domain
6. Upload specs to S3
```

**Time:** 1-2 hours
**Cost:** ~$0.15/hour for EC2

---

### Step 2: Test Agent Locally

**Why:** Verify everything works before deploying to AWS

```bash
cd sre_agent
uv run sre-agent --prompt "List pods in production"
```

**Expected:** Agent successfully calls Gateway → Gateway calls Backend → Returns pod data

---

### Step 3: Deploy Agent to AgentCore Runtime (Option 3)

**Why:** Production deployment, fully managed by AWS

```bash
cd deployment
./build_and_deploy.sh
```

**What this does:**
1. Builds ARM64 Docker image
2. Pushes to Amazon ECR
3. Deploys to AgentCore Runtime
4. Returns runtime ARN

---

### Step 4: Test Production Deployment

```bash
python deployment/invoke_agent_runtime.py --prompt "List pods in production"
```

**Expected:** Agent running in AWS successfully investigates and returns results

---

## Summary

**Options 1, 2, 4:** Deploy BACKEND APIs (so Gateway can reach them)
- Purpose: Testing and development
- Required: Yes, must do one of these first
- Your choice: Option 1 (EC2) for production

**Option 3:** Deploy SRE AGENT to AgentCore Runtime
- Purpose: Production deployment of your agent
- Required: Yes, this is the final goal
- When: After backend is working (after Option 1 or 2)

**You're absolutely correct:** The backend deployment is for testing, and the final step is deploying the agent as a Docker container to AgentCore Runtime!

---

### Option 4: Mock Backend in AWS (For Testing Only)

Create a simple Lambda function or API Gateway that returns fake data, so the Gateway has something to call.

**Not recommended** - too much work for testing.

---

## Recommended Approach

**For learning/testing:**
- Use **Option 2 (ngrok)** for quick local testing

**For production:**
- Use **Option 1 (EC2 with domain and SSL)** as intended by the project

**For deployment testing:**
- Use **Option 3 (AgentCore Runtime)** after setting up Option 1 or 2

---

## Why the Error Message is Confusing

The error "Failed to obtain execution role credentials" makes it sound like an IAM permissions issue, but it's actually:

1. Gateway tries to call `https://your-backend-domain.com:8011`
2. DNS lookup fails or connection times out
3. Gateway's internal error handling returns a generic "credential" error
4. The real issue is network connectivity, not credentials

---

## Quick Test: Verify Backend is Accessible

From your local machine:
```bash
# This works (local)
curl -H "X-API-Key: $BACKEND_API_KEY" http://127.0.0.1:8011/pods/status?namespace=production

# This is what the Gateway tries (and fails)
curl -H "X-API-Key: $BACKEND_API_KEY" https://your-backend-domain.com:8011/pods/status?namespace=production
```

If the second command fails, that's your problem!

---

## Summary

✅ **Credential Provider**: Working correctly
✅ **Gateway Targets**: Configured correctly  
✅ **Backend Servers**: Running correctly on localhost
✅ **API Key**: Stored correctly in Credential Provider
❌ **Network Connectivity**: Gateway cannot reach localhost backend servers

**Fix**: Make backend servers accessible from AWS (EC2 + domain + SSL, or ngrok for testing)
