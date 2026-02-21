# AgentCore Runtime vs Raw Bedrock — Why This Architecture

## What is AgentCore Runtime?

**AgentCore Runtime** is a managed container execution environment for AI agents, provided by AWS Bedrock AgentCore service.

**Think of it as:** AWS Lambda for AI agents — you provide a container image, AWS runs it on-demand with managed scaling, networking, and IAM integration.

---

## The /invocations Endpoint

### FastAPI App Inside the Container

**File:** `sre_agent/agent_runtime.py`

```python
from fastapi import FastAPI

app = FastAPI(title="SRE Agent Runtime", version="1.0.0")

@app.post("/invocations", response_model=InvocationResponse)
async def invoke_agent(request: InvocationRequest):
    # Extract user prompt
    user_prompt = request.input.get("prompt", "")
    
    # Create initial state
    initial_state: AgentState = {
        "messages": [HumanMessage(content=user_prompt)],
        "next": "supervisor",
        "auto_approve_plan": True,
        "session_id": request.input.get("session_id", ""),
        "user_id": request.input.get("user_id", "default_user")
    }
    
    # Execute agent graph
    async for event in agent_graph.astream(initial_state):
        for node_name, node_output in event.items():
            if node_name == "aggregate":
                final_response = node_output.get("final_response", "")
    
    # Return response
    return InvocationResponse(output={
        "message": final_response,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "model": "sre-multi-agent"
    })
```

### Request Format

```json
{
  "input": {
    "prompt": "Why is the API server pod restarting?",
    "session_id": "runtime-20250122143052",
    "user_id": "Alice"
  }
}
```

### Response Format

```json
{
  "output": {
    "message": "## Investigation Results\n\nThe API server pod is restarting due to...",
    "timestamp": "2025-01-22T14:35:00Z",
    "model": "sre-multi-agent"
  }
}
```

### How AgentCore Calls This Endpoint

**Step 1: User invokes runtime**
```python
# File: invoke_agent_runtime.py
response = bedrock_client.invoke_agent_runtime(
    runtimeArn=runtime_arn,
    input={
        "prompt": "Check pod status",
        "session_id": "runtime-20250122143052",
        "user_id": "Alice"
    }
)
```

**Step 2: AgentCore routes to container**
```
AgentCore Service → Container (port 8080) → POST /invocations
```

**Step 3: Container processes request**
```
FastAPI receives request → Initialize agent → Execute graph → Return response
```

**Step 4: AgentCore returns response**
```
Container → AgentCore Service → User
```

---

## ARM64 vs x86_64: Architecture Differences

### Why AgentCore Uses ARM64

**AWS Graviton processors:**
- ARM64-based custom silicon
- Better price/performance ratio
- Lower power consumption
- Optimized for cloud workloads

**AgentCore Runtime requirement:**
- Must use ARM64 container images
- No x86_64 support (as of 2025)

### Why Local Testing Uses x86_64

**Most development machines:**
- Intel/AMD processors (x86_64)
- Cannot run ARM64 containers natively
- Would require emulation (slow)

**Solution: Multi-architecture builds**

**File:** `Dockerfile.x86_64`
```dockerfile
FROM --platform=linux/amd64 python:3.11-slim
# Rest of Dockerfile...
```

**File:** `Dockerfile` (for ARM64)
```dockerfile
FROM --platform=linux/arm64 python:3.11-slim
# Rest of Dockerfile...
```

**Build commands:**
```bash
# For local testing (x86_64)
docker build -f Dockerfile.x86_64 -t sre-agent:local .

# For AgentCore (ARM64)
docker build -f Dockerfile -t sre-agent:arm64 .
```

**Cross-compilation:**
```bash
# Build ARM64 image on x86_64 machine
docker buildx build --platform linux/arm64 -t sre-agent:arm64 .
```

---

## What the Runtime Manages For You

### 1. Scaling

**Automatic:**
- Scales to zero when not in use (no cost)
- Scales up on demand (handles concurrent requests)
- No configuration needed

**vs. ECS/Lambda:**
- ECS: Manual scaling configuration
- Lambda: Automatic, but cold starts
- AgentCore: Automatic, optimized for agents

### 2. Networking

**Managed:**
- Public or VPC networking
- Load balancing
- TLS termination

**Network modes:**

**PUBLIC (current setup):**
```python
network_mode = "PUBLIC"
# Container can access internet
# Accessible via public endpoint
```

**VPC (production):**
```python
network_mode = "VPC"
vpc_config = {
    "subnetIds": ["subnet-abc123", "subnet-def456"],
    "securityGroupIds": ["sg-xyz789"]
}
# Container runs in VPC
# Can access private resources
# More secure
```

### 3. IAM Credential Injection

**Automatic:**
- Runtime assumes execution role
- Injects temporary credentials into container
- Rotates credentials automatically

**What you don't manage:**
- Credential storage
- Credential rotation
- Credential expiry

**What you do manage:**
- Execution role permissions
- Trust policy

### 4. Logging

**Automatic:**
- Stdout/stderr → CloudWatch Logs
- Log group: `/aws/bedrock-agentcore/runtime/{runtime-name}`
- No configuration needed

**Example logs:**
```
2025-01-22 14:30:00 INFO Starting SRE Agent system...
2025-01-22 14:30:05 INFO Retrieved 21 tools from MCP
2025-01-22 14:30:10 INFO Processing query: Check pod status
2025-01-22 14:30:35 INFO Successfully processed agent request
```

---

## ECR → AgentCore Runtime Deployment Flow

### Step 1: Build Container Image

```bash
# Build ARM64 image
docker buildx build --platform linux/arm64 -t sre-agent:latest .
```

**Dockerfile key sections:**
```dockerfile
FROM --platform=linux/arm64 python:3.11-slim

# Install dependencies
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen

# Copy agent code
COPY sre_agent/ ./sre_agent/
COPY backend/ ./backend/
COPY gateway/ ./gateway/

# Expose port
EXPOSE 8080

# Start FastAPI server
CMD ["uvicorn", "sre_agent.agent_runtime:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Step 2: Tag for ECR

```bash
# Tag with ECR repository URL
docker tag sre-agent:latest \
    310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest
```

### Step 3: Push to ECR

```bash
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    310485116687.dkr.ecr.us-east-1.amazonaws.com

# Push image
docker push 310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest
```

### Step 4: Deploy to AgentCore Runtime

**File:** `deploy_agent_runtime.py`

```python
def deploy_agent_runtime(
    runtime_name: str,
    image_uri: str,
    execution_role_arn: str,
    region: str = "us-east-1"
):
    client = boto3.client("bedrock-agentcore-control", region_name=region)
    
    response = client.create_runtime(
        name=runtime_name,
        description="SRE Multi-Agent System",
        imageUri=image_uri,
        executionRoleArn=execution_role_arn,
        networkMode="PUBLIC",
        containerConfig={
            "port": 8080,
            "healthCheckPath": "/ping"
        }
    )
    
    return response

# Usage
image_uri = "310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest"
execution_role_arn = "arn:aws:iam::310485116687:role/BedrockAgentCoreRole"

runtime = deploy_agent_runtime(
    runtime_name="sre_agent_v2",
    image_uri=image_uri,
    execution_role_arn=execution_role_arn
)

print(f"Runtime ARN: {runtime['runtimeArn']}")
```

### Step 5: Verify Deployment

```bash
# Check runtime status
aws bedrock-agentcore-control get-runtime \
    --runtime-identifier sre_agent_v2 \
    --region us-east-1

# Expected output:
# {
#   "runtimeArn": "arn:aws:bedrock-agentcore:us-east-1:310485116687:runtime/sre_agent_v2-9o4nAB5ARI",
#   "status": "ACTIVE",
#   "imageUri": "310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest",
#   ...
# }
```

---

## The Runtime ARN

**Format:**
```
arn:aws:bedrock-agentcore:us-east-1:310485116687:runtime/sre_agent_v2-9o4nAB5ARI
```

**Components:**
- Service: `bedrock-agentcore`
- Region: `us-east-1`
- Account: `310485116687`
- Resource type: `runtime`
- Resource name: `sre_agent_v2-9o4nAB5ARI`

**Usage:**
```python
# Invoke runtime
response = bedrock_client.invoke_agent_runtime(
    runtimeArn="arn:aws:bedrock-agentcore:us-east-1:310485116687:runtime/sre_agent_v2-9o4nAB5ARI",
    input={"prompt": "Check pod status"}
)
```

---

## How invoke_agent_runtime.py Constructs the Invocation Request

**File:** `invoke_agent_runtime.py`

```python
import boto3
import json

def invoke_agent_runtime(
    runtime_arn: str,
    prompt: str,
    session_id: str = None,
    user_id: str = "default_user"
):
    client = boto3.client("bedrock-agentcore-runtime", region_name="us-east-1")
    
    # Construct input
    input_data = {
        "prompt": prompt,
        "user_id": user_id
    }
    
    if session_id:
        input_data["session_id"] = session_id
    
    # Invoke runtime
    response = client.invoke_runtime(
        runtimeArn=runtime_arn,
        input=input_data
    )
    
    # Parse response
    output = response["output"]
    message = output.get("message", "")
    
    return message

# Usage
runtime_arn = "arn:aws:bedrock-agentcore:us-east-1:310485116687:runtime/sre_agent_v2-9o4nAB5ARI"
result = invoke_agent_runtime(
    runtime_arn=runtime_arn,
    prompt="Why is the API server pod restarting?",
    session_id="runtime-20250122143052",
    user_id="Alice"
)

print(result)
```

---

## AgentCore Gateway vs API Gateway

### AgentCore Gateway

**Purpose:** MCP protocol gateway for AI agents

**Features:**
- MCP protocol support
- OpenAPI spec → tool discovery
- JWT authorization
- Credential provider integration
- Semantic search (for MCP search type)

**Use case:** AI agents calling backend APIs

### API Gateway

**Purpose:** HTTP API gateway for web/mobile clients

**Features:**
- REST/HTTP APIs
- API key, IAM, Cognito authorization
- Request/response transformation
- Rate limiting, throttling
- Custom domains

**Use case:** Web/mobile apps calling backend APIs

### Key Differences

| Feature | AgentCore Gateway | API Gateway |
|---------|-------------------|-------------|
| Protocol | MCP | HTTP/REST |
| Tool discovery | OpenAPI → MCP tools | Manual API definition |
| Authorization | JWT (Cognito) | API key, IAM, Cognito |
| Credentials | Credential Provider | Manual management |
| Target audience | AI agents | Web/mobile clients |
| Pricing | Per-request | Per-request |

---

## Why Not Raw Bedrock Agents?

### Bedrock Agents (Managed Service)

**Pros:**
- Fully managed
- No code needed
- Built-in orchestration

**Cons:**
- Black-box orchestration
- Limited control over agent flow
- Hard to debug
- No custom memory strategies
- No LangGraph integration

### LangGraph + AgentCore Runtime (This System)

**Pros:**
- Full control over agent flow
- Explicit routing logic
- Easy to debug (inspect state at each node)
- Custom memory strategies
- LangGraph's powerful features

**Cons:**
- More code to write
- More complexity
- Need to manage container deployment

**Why we chose this:**
- Need explicit control for demo purposes
- Want to show how multi-agent systems work
- Need custom memory strategies
- Want to use LangGraph's features

---

## Why Not ECS/Lambda?

### ECS (Elastic Container Service)

**Pros:**
- Full control over containers
- Can run any workload
- Flexible networking

**Cons:**
- Manual scaling configuration
- Manual IAM setup
- Manual logging setup
- Not optimized for agent workloads

### Lambda

**Pros:**
- Automatic scaling
- Pay per invocation
- Simple deployment

**Cons:**
- 15-minute timeout (too short for long investigations)
- Cold starts (slow first request)
- Limited memory (10GB max)
- Not optimized for agent workloads

### AgentCore Runtime

**Pros:**
- Automatic scaling (like Lambda)
- No timeout limits (can run for hours)
- Optimized for agent workloads
- Built-in session management
- Integrated with AgentCore Gateway

**Cons:**
- Newer service (less mature)
- Limited documentation
- ARM64 only

**Why we chose this:**
- Purpose-built for AI agents
- Handles long-running investigations
- Integrated with AgentCore ecosystem
- Better than ECS/Lambda for this use case

---

## Cost Model: Per-Invocation Pricing vs Always-On

### AgentCore Runtime (Per-Invocation)

**Pricing:**
- $0.00X per invocation
- $0.00Y per GB-second of execution
- No cost when idle

**Example:**
- 100 investigations per day
- Average 30 seconds per investigation
- 2GB memory
- Cost: ~$5-10/month

### ECS (Always-On)

**Pricing:**
- $0.04 per hour for Fargate task (1 vCPU, 2GB)
- 24/7 operation
- Cost: ~$30/month

**Example:**
- Same workload (100 investigations/day)
- Task runs 24/7 even when idle
- Cost: ~$30/month (3-6x more expensive)

### Lambda (Per-Invocation)

**Pricing:**
- $0.20 per 1M requests
- $0.0000166667 per GB-second
- No cost when idle

**Example:**
- 100 investigations per day
- Average 30 seconds per investigation
- 2GB memory
- Cost: ~$1-2/month

**But:**
- 15-minute timeout (too short)
- Cold starts (slow)

### Why AgentCore Runtime Wins

**For agent workloads:**
- Pay only for actual usage (like Lambda)
- No timeout limits (unlike Lambda)
- Optimized for agents (unlike ECS)
- Reasonable pricing (between Lambda and ECS)

---

## Summary: AgentCore Runtime Architecture

**What it is:**
- Managed container execution for AI agents
- FastAPI app at `/invocations` endpoint
- ARM64 architecture (Graviton processors)

**What it manages:**
- Scaling (automatic, to zero)
- Networking (public or VPC)
- IAM credentials (automatic injection)
- Logging (CloudWatch Logs)

**Deployment flow:**
- Build ARM64 container
- Push to ECR
- Deploy to AgentCore Runtime
- Invoke via runtime ARN

**Why this architecture:**
- Full control (vs. Bedrock Agents)
- Optimized for agents (vs. ECS/Lambda)
- Cost-effective (pay per use)
- Integrated with AgentCore ecosystem
