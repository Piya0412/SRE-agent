# Failure Modes and Hard Interview Questions

## PART 1: FAILURE MODES

### Failure Mode 1: JWT Token Expired

**What breaks:** All MCP tool calls fail after 1 hour

**Error message:**
```
401 Unauthorized: Token has expired
```

**Root cause:**
- JWT token has 1-hour expiry (Cognito default)
- Token generated at 14:00, expires at 15:00
- Agent tries to call tool at 15:05 → fails

**How to detect:**
```bash
# Check token expiration
python -c "import jwt, os; print(jwt.decode(open('gateway/.access_token').read(), options={'verify_signature': False})['exp'])"
```

**How to fix:**
```bash
# Regenerate token
python gateway/generate_token.py

# Update environment variable
export GATEWAY_ACCESS_TOKEN=$(cat gateway/.access_token)

# Restart agent
python -m sre_agent.cli
```

**Prevention:**
- Implement automatic token refresh
- Extend token lifetime to 4-24 hours
- Use refresh tokens

---

### Failure Mode 2: Gateway Targets Not READY

**What breaks:** MCP tools not available, agent cannot call backends

**Error message:**
```
Error: Tool 'k8s-api___get_pod_status' not found
```

**Root cause:**
- Gateway targets in CREATING state
- OpenAPI spec parsing failed
- S3 bucket not accessible

**How to detect:**
```bash
python gateway/check_gateway_targets.py
```

**Output:**
```
Gateway Targets:
  • k8s-api (ID: target-abc123)
    Status: CREATING  ← Problem!
```

**How to fix:**
```bash
# Wait for targets to become READY (can take 2-5 minutes)
watch -n 10 python gateway/check_gateway_targets.py

# If stuck in CREATING for >10 minutes, check CloudWatch logs
aws logs tail /aws/bedrock-agentcore/gateway/sre-gateway --follow

# If FAILED status, recreate target
python gateway/add_gateway_targets.py --recreate
```

**Prevention:**
- Validate OpenAPI specs before uploading
- Check S3 bucket permissions
- Monitor target status after creation

---

### Failure Mode 3: Backend Servers Not Running

**What breaks:** Gateway can reach target, but backend doesn't respond

**Error message:**
```
502 Bad Gateway: Connection refused
```

**Root cause:**
- Backend server not started
- Wrong port number
- ngrok tunnel expired

**How to detect:**
```bash
# Check if backends are running
ps aux | grep python | grep server

# Test backend directly
curl -H "X-API-KEY: $BACKEND_API_KEY" http://127.0.0.1:8001/health
```

**How to fix:**
```bash
# Start all backend servers
cd backend/scripts
./start_demo_backend.sh

# Verify they're running
curl http://127.0.0.1:8001/health  # k8s
curl http://127.0.0.1:8002/health  # logs
curl http://127.0.0.1:8003/health  # metrics
curl http://127.0.0.1:8004/health  # runbooks
```

**Prevention:**
- Use process manager (systemd, supervisor)
- Add health check monitoring
- Auto-restart on failure

---

### Failure Mode 4: Wrong Container Architecture

**What breaks:** Container fails to start in AgentCore Runtime

**Error message:**
```
Error: exec format error
```

**Root cause:**
- Built x86_64 image, deployed to ARM64 runtime
- AgentCore Runtime only supports ARM64

**How to detect:**
```bash
# Check image architecture
docker inspect sre-agent:latest | grep Architecture

# Should show: "Architecture": "arm64"
# If shows "amd64" or "x86_64", wrong architecture
```

**How to fix:**
```bash
# Build ARM64 image
docker buildx build --platform linux/arm64 -t sre-agent:arm64 .

# Tag and push
docker tag sre-agent:arm64 310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest
docker push 310485116687.dkr.ecr.us-east-1.amazonaws.com/sre-agent:latest

# Redeploy runtime
python deploy_agent_runtime.py
```

**Prevention:**
- Always specify `--platform linux/arm64` in build
- Add architecture check in CI/CD
- Use multi-arch builds for flexibility

---

### Failure Mode 5: IAM Trust Policy Misconfigured

**What breaks:** AgentCore cannot assume execution role

**Error message:**
```
AccessDeniedException: User: arn:aws:sts::310485116687:assumed-role/... is not authorized to perform: sts:AssumeRole
```

**Root cause:**
- Trust policy doesn't allow bedrock-agentcore.amazonaws.com
- Wrong account ID in condition
- Role doesn't exist

**How to detect:**
```bash
# Check trust policy
aws iam get-role --role-name BedrockAgentCoreRole --query 'Role.AssumeRolePolicyDocument'
```

**Expected output:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "bedrock-agentcore.amazonaws.com"},
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": {"aws:SourceAccount": "310485116687"}
    }
  }]
}
```

**How to fix:**
```bash
# Update trust policy
aws iam update-assume-role-policy \
    --role-name BedrockAgentCoreRole \
    --policy-document file://trust-policy.json
```

**Prevention:**
- Use CloudFormation/Terraform for IAM
- Validate trust policy before deployment
- Test with least-privilege first

---

## PART 2: HARD INTERVIEW QUESTIONS

### Question 1: "Walk me through the architecture end to end"

**Strong answer:**

"The SRE Agent system has three layers: Agent, Gateway, and Backend.

**Agent Layer:** Built with LangGraph, it has a Supervisor that creates investigation plans and routes to 4 specialist agents (Kubernetes, Logs, Metrics, Runbooks). Each agent uses the ReAct pattern to reason, act with tools, and observe results.

**Gateway Layer:** AWS AgentCore Gateway implements MCP protocol. It reads OpenAPI specs from S3 to discover tools, validates JWT tokens from Cognito, fetches backend credentials from a Credential Provider, and translates MCP tool calls to HTTP requests.

**Backend Layer:** Four FastAPI servers (k8s, logs, metrics, runbooks) serve demo data from JSON files. They validate API keys and return responses.

**Memory System:** Bedrock Memory stores three types: user preferences (session-independent), infrastructure knowledge (agent-scoped), and investigation summaries (user-scoped). Memory is retrieved before planning and saved after completion.

**Request flow:** CLI → Initialize (MCP tools, Memory, LangGraph) → Supervisor retrieves memory → Creates plan → Routes to agents → Agents call MCP tools → Gateway translates to HTTP → Backend responds → Supervisor aggregates → Save to memory → Generate report."

---

### Question 2: "Why did you choose LangGraph over Bedrock Agents?"

**Strong answer:**

"We needed explicit control over agent orchestration for three reasons:

**1. Debuggability:** LangGraph lets us inspect state at each node, log routing decisions, and understand exactly why the supervisor chose a particular agent. Bedrock Agents is a black box.

**2. Custom memory:** We implemented three memory strategies with specific namespaces and retrieval patterns. Bedrock Agents has built-in memory, but it's not customizable to our needs.

**3. Complex routing:** Our supervisor creates investigation plans with 3-5 steps and routes sequentially through agents. We can easily modify this to parallel execution or add new agents. Bedrock Agents has fixed orchestration patterns.

The trade-off is more code complexity, but for a demo showcasing multi-agent patterns, the transparency is worth it."

---

### Question 3: "What is MCP and why is it used here?"

**Strong answer:**

"MCP (Model Context Protocol) is a standardized protocol for LLMs to interact with external tools. It's like OpenAPI for AI agents.

**Why we use it:**

**1. Tool abstraction:** Agents call tools like `k8s-api___get_pod_status` without knowing the backend URL, authentication, or HTTP details. The gateway handles translation.

**2. Security:** Agents never see backend credentials. The gateway fetches API keys from a Credential Provider at runtime.

**3. Replaceability:** To replace the demo K8s backend with a real cluster, we just update the OpenAPI spec and credential provider. Zero agent code changes.

**How it works:** The gateway reads OpenAPI specs from S3, generates MCP tools (format: `{target}___{operationId}`), and maps tool calls to HTTP requests. When an agent calls a tool, the gateway validates the JWT, fetches credentials, makes the HTTP request, and returns the response.

The triple underscore separates target from operation, making it easy to route to the correct backend."

---

### Question 4: "How does the memory system work?"

**Strong answer:**

"We use Bedrock Memory with three strategies:

**1. User Preferences** (User Preference Strategy)
- Namespace: `/sre/users/{user_id}/preferences`
- Stores: Escalation contacts, notification preferences, workflow settings
- Scope: User-specific, session-independent
- Retention: 90 days

**2. Infrastructure Knowledge** (Semantic Strategy)
- Namespace: `/sre/infrastructure/{agent_id}/{session_id}`
- Stores: Service baselines, dependencies, patterns
- Scope: Agent-specific, session-aware
- Retention: 30 days
- Can search across sessions by omitting session_id

**3. Investigation Summaries** (Summary Strategy)
- Namespace: `/sre/investigations/{user_id}/{session_id}`
- Stores: Incident summaries, timelines, key findings
- Scope: User-specific, session-aware
- Retention: 60 days

**Workflow:**
- Before planning: Supervisor retrieves all three types using semantic search
- During execution: Agents can save/retrieve memories using tools
- After completion: Hooks save investigation summary and infrastructure knowledge

**Why actor_id differs:** Preferences use user_id (user-scoped), infrastructure uses agent_id (each agent learns different things), investigations use user_id (user-initiated)."

---

### Question 5: "What would you do differently in production?"

**Strong answer:**

"Several changes for production:

**1. Real backends:** Replace JSON files with actual K8s API, Elasticsearch, Prometheus, and a runbook database.

**2. Authentication:** Implement proper user authentication (not just client credentials), add RBAC for multi-tenant access, and use refresh tokens for long-running sessions.

**3. Observability:** Add distributed tracing (X-Ray), structured logging with correlation IDs, metrics for agent performance, and alerting for failures.

**4. Scaling:** Implement parallel agent execution, add caching for frequently accessed data, use streaming responses for better UX, and optimize memory retrieval queries.

**5. Security:** Run in VPC (not public), implement rate limiting per user, add input validation and sanitization, and rotate credentials automatically.

**6. Reliability:** Add retry logic with exponential backoff, implement circuit breakers for backend calls, add health checks for all components, and use blue/green deployments.

**7. Cost optimization:** Use spot instances for non-critical workloads, implement request batching, add result caching, and monitor per-user costs."

---

### Question 6: "How would you scale this to handle 100 concurrent investigations?"

**Strong answer:**

"Current bottlenecks and solutions:

**1. Sequential agent execution:**
- Problem: Each investigation takes 20-40 seconds
- Solution: Implement parallel agent execution in LangGraph
- Impact: 2-3x faster (10-15 seconds per investigation)

**2. LLM API rate limits:**
- Problem: Bedrock has per-account rate limits
- Solution: Implement request queuing, use multiple accounts/regions, or switch to self-hosted models
- Impact: Handle 100+ concurrent requests

**3. Memory retrieval:**
- Problem: Semantic search can be slow at scale
- Solution: Add caching layer (Redis), pre-compute embeddings, or use approximate nearest neighbor search
- Impact: 5-10x faster retrieval

**4. Backend capacity:**
- Problem: Demo backends are single-process
- Solution: Use real production systems (K8s API, Elasticsearch, Prometheus) which are designed for scale
- Impact: Handle thousands of requests/second

**5. AgentCore Runtime:**
- Problem: Cold starts for first request
- Solution: Keep warm instances, use provisioned concurrency, or implement request batching
- Impact: Consistent sub-second startup

**Architecture changes:**
- Add load balancer for backends
- Use message queue (SQS) for async investigations
- Implement result caching (ElastiCache)
- Add CDN for static content (reports)"

---

### Question 7: "What happens if the gateway goes down mid-investigation?"

**Strong answer:**

"Current behavior (no resilience):
- Agent's tool call fails with connection error
- Investigation stops mid-execution
- User sees error message
- No automatic retry

**What should happen (production):**

**1. Immediate:**
- Agent catches connection error
- Retries with exponential backoff (3 attempts)
- If all retries fail, marks investigation as 'failed'
- Saves partial results to memory

**2. Recovery:**
- User can resume investigation with same session_id
- Supervisor checks memory for partial results
- Continues from last successful step
- Avoids re-running completed agents

**3. Prevention:**
- Gateway should be highly available (multi-AZ)
- Use health checks and auto-recovery
- Implement circuit breaker pattern
- Add fallback to cached results

**Implementation:**
```python
@retry(max_attempts=3, backoff=exponential)
async def call_tool_with_retry(tool_name, **kwargs):
    try:
        return await tool.ainvoke(kwargs)
    except ConnectionError:
        logger.warning(f'Gateway unreachable, retrying...')
        raise  # Retry decorator handles this
    except Exception as e:
        logger.error(f'Tool call failed: {e}')
        return {'error': str(e), 'partial': True}
```

**State management:**
- Save state after each agent completes
- Use checkpointing in LangGraph
- Enable investigation resume from any point"

---

### Question 8: "How do you handle the 1-hour token expiry in production?"

**Strong answer:**

"Three-layer solution:

**1. Automatic refresh (preferred):**
```python
class TokenManager:
    def __init__(self):
        self.token = None
        self.expiry = None
    
    def get_token(self):
        if self.expiry and time.time() > self.expiry - 300:
            # Refresh 5 minutes before expiry
            self.token = self.refresh_token()
        return self.token
    
    def refresh_token(self):
        # Use Cognito refresh token
        response = cognito_client.initiate_auth(
            AuthFlow='REFRESH_TOKEN_AUTH',
            AuthParameters={'REFRESH_TOKEN': self.refresh_token}
        )
        self.token = response['AccessToken']
        self.expiry = time.time() + 3600
        return self.token
```

**2. Extend token lifetime:**
- Change Cognito settings to 4-24 hours
- Trade-off: Longer-lived tokens are less secure
- Acceptable for internal tools with proper RBAC

**3. Session-based approach:**
- Use Cognito refresh tokens (valid for 30 days)
- Automatically refresh access token in background
- Transparent to agent code

**For long-running investigations:**
- Store refresh token in secure storage
- Background thread refreshes access token
- Agent always uses fresh token
- No interruption to investigation

**Monitoring:**
- Alert when token refresh fails
- Log token refresh events
- Track token usage patterns
- Detect anomalous refresh rates"

---

### Question 9: "Explain the IAM permissions needed and why"

**Strong answer:**

"Three IAM components:

**1. User/Developer IAM permissions:**
```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock-agentcore:*",
    "s3:PutObject",
    "ecr:*",
    "iam:PassRole"
  ]
}
```
- `bedrock:InvokeModel`: Call LLMs for agent reasoning
- `bedrock-agentcore:*`: Manage gateways, runtimes, memory
- `s3:PutObject`: Upload OpenAPI specs
- `ecr:*`: Push container images
- `iam:PassRole`: Pass execution role to AgentCore

**2. AgentCore execution role (BedrockAgentCoreRole):**

Trust policy:
```json
{
  "Principal": {"Service": "bedrock-agentcore.amazonaws.com"},
  "Condition": {"StringEquals": {"aws:SourceAccount": "310485116687"}}
}
```

Permissions:
- `bedrock:*`: Call Bedrock APIs
- `s3:GetObject`: Read OpenAPI specs from S3
- `logs:*`: Write CloudWatch logs
- `ecr:*`: Pull container images
- `secretsmanager:GetSecretValue`: Access credential provider

**3. Credential Provider access:**
- Gateway role needs `bedrock-agentcore:GetCredential`
- Scoped to specific provider ARN
- Enables fetching backend API keys

**Why each is needed:**
- User permissions: Deploy and manage system
- Execution role: Runtime operations
- Credential provider: Secure credential access

**Least privilege:**
- Scope S3 to specific bucket
- Scope ECR to specific repository
- Scope logs to specific log group
- Use resource-based policies where possible"

---

### Question 10: "This is demo data — how would you connect it to real infrastructure?"

**Strong answer:**

"Three integration approaches:

**1. Direct API integration (simplest):**
- Replace FastAPI backends with API clients
- K8s: Use `kubernetes` Python client
- Logs: Use Elasticsearch client
- Metrics: Use Prometheus client
- Runbooks: Use database ORM

Example:
```python
# Replace backend/servers/k8s_server.py
from kubernetes import client, config

config.load_kube_config()
v1 = client.CoreV1Api()

@app.get('/pods/{namespace}/{pod_name}')
async def get_pod_status(namespace: str, pod_name: str):
    pod = v1.read_namespaced_pod(pod_name, namespace)
    return {
        'status': pod.status.phase,
        'restarts': pod.status.container_statuses[0].restart_count,
        ...
    }
```

**2. Proxy pattern (recommended):**
- Keep gateway and MCP layer
- Update OpenAPI specs to point to real APIs
- Add authentication adapters
- Benefits: No agent code changes, easier testing

**3. Hybrid approach (production):**
- Use real APIs for live data
- Keep demo data for testing/development
- Environment-based switching
- Allows safe experimentation

**Authentication changes:**
- K8s: Service account tokens
- Elasticsearch: API keys or basic auth
- Prometheus: Bearer tokens
- Runbooks DB: Database credentials

**Update credential provider:**
```python
# For K8s service account
create_bearer_token_credential_provider(
    provider_name='k8s-service-account',
    token=service_account_token
)

# For Elasticsearch
create_basic_auth_credential_provider(
    provider_name='elasticsearch-auth',
    username='elastic',
    password=es_password
)
```

**OpenAPI spec changes:**
- Update server URLs to real endpoints
- Update authentication schemes
- Add rate limiting headers
- Update response schemas if needed

**Testing strategy:**
- Unit tests with mock data
- Integration tests with staging environment
- Canary deployments to production
- Gradual rollout per agent"

---

### Question 11: "What's the difference between the Gateway and the Runtime?"

**Strong answer:**

"Two separate components with different purposes:

**AgentCore Gateway:**
- **Purpose:** MCP protocol gateway for tool calls
- **Function:** Translates MCP tool calls to HTTP requests
- **Input:** MCP tool call from agent
- **Output:** HTTP response from backend
- **Key features:**
  - OpenAPI spec → tool discovery
  - JWT validation
  - Credential provider integration
  - Request/response transformation

**AgentCore Runtime:**
- **Purpose:** Container execution environment for agents
- **Function:** Runs agent code in managed containers
- **Input:** User prompt via `/invocations` endpoint
- **Output:** Final investigation report
- **Key features:**
  - Automatic scaling
  - IAM credential injection
  - CloudWatch logging
  - Health checks

**How they work together:**
1. User invokes Runtime with prompt
2. Runtime starts container, calls `/invocations`
3. Agent code executes, calls MCP tools
4. MCP client sends requests to Gateway
5. Gateway translates to HTTP, calls backends
6. Responses flow back: Backend → Gateway → Agent → Runtime → User

**Analogy:**
- Gateway = API Gateway (routes requests)
- Runtime = Lambda/ECS (executes code)

**Can you use one without the other?**
- Gateway without Runtime: Yes (agent runs locally)
- Runtime without Gateway: No (agent needs tools)

**In production:**
- Gateway: Highly available, multi-AZ
- Runtime: Auto-scaling, multiple instances
- Both: Monitored, logged, alerted"

---

### Question 12: "How would you monitor this in production?"

**Strong answer:**

"Four monitoring layers:

**1. Application metrics:**
- Investigation duration (p50, p95, p99)
- Agent execution time per type
- Tool call latency
- Memory retrieval time
- Success/failure rates
- User satisfaction scores

**2. Infrastructure metrics:**
- Gateway request rate, latency, errors
- Runtime CPU, memory, container count
- Backend response times
- Memory service latency
- LLM API latency and token usage

**3. Business metrics:**
- Investigations per user per day
- Most common investigation types
- Agent utilization (which agents are used most)
- Cost per investigation
- Time to resolution

**4. Logs and traces:**
- Structured logging with correlation IDs
- Distributed tracing (X-Ray)
- Error logs with stack traces
- Audit logs for security

**Implementation:**

**CloudWatch dashboards:**
```python
# Custom metrics
cloudwatch.put_metric_data(
    Namespace='SREAgent',
    MetricData=[{
        'MetricName': 'InvestigationDuration',
        'Value': duration_seconds,
        'Unit': 'Seconds',
        'Dimensions': [
            {'Name': 'UserId', 'Value': user_id},
            {'Name': 'AgentType', 'Value': agent_type}
        ]
    }]
)
```

**Alerting:**
- Investigation failure rate > 5%
- Average duration > 60 seconds
- Gateway error rate > 1%
- Memory retrieval failures
- Token expiry warnings

**Dashboards:**
- Real-time investigation status
- Agent performance comparison
- Cost breakdown by user/agent
- Error rate trends
- Capacity planning metrics

**Observability tools:**
- CloudWatch for metrics and logs
- X-Ray for distributed tracing
- Grafana for custom dashboards
- PagerDuty for alerting
- Datadog/New Relic for APM"

---

## PART 3: DEMO PREPARATION

### 2-Minute Opening Statement

"Hi, I'm here to demo the SRE Multi-Agent System I built using AWS Bedrock AgentCore.

This system helps SRE teams investigate production issues by orchestrating multiple specialized AI agents. It has three key innovations:

First, it uses LangGraph for explicit multi-agent orchestration. A Supervisor agent creates investigation plans and routes to four specialist agents: Kubernetes, Logs, Metrics, and Runbooks. Each agent uses the ReAct pattern to reason about the problem and call tools.

Second, it implements MCP (Model Context Protocol) through AgentCore Gateway. This abstracts backend APIs into tools that agents can call without knowing authentication details or URLs. We can swap backends without changing agent code.

Third, it has a sophisticated memory system with three strategies: user preferences for personalization, infrastructure knowledge for each agent, and investigation summaries for learning from past incidents.

The demo shows a complete investigation flow: from user query, through memory retrieval, investigation planning, agent execution, and final report generation. Let me show you."

---

### 3-Minute Architecture Walkthrough Script

"Let me walk through the architecture using this diagram.

**[Point to Agent Layer]**
At the top, we have the Agent Layer built with LangGraph. The Supervisor creates investigation plans by retrieving relevant memories, then routes to specialist agents. Each agent has filtered tools - for example, the Kubernetes agent only sees K8s-related tools.

**[Point to Gateway Layer]**
In the middle is the AgentCore Gateway implementing MCP protocol. It reads OpenAPI specs from S3 to discover tools, validates JWT tokens from Cognito, and fetches backend credentials from a Credential Provider. When an agent calls a tool like 'k8s-api___get_pod_status', the gateway translates it to an HTTP request.

**[Point to Backend Layer]**
At the bottom are four FastAPI backends serving demo data. In production, these would be real systems like Kubernetes API, Elasticsearch, and Prometheus.

**[Point to Memory System]**
The Memory System runs alongside, storing three types: user preferences (session-independent), infrastructure knowledge (agent-scoped), and investigation summaries (user-scoped). Memory is retrieved before planning and saved after completion.

**[Trace request flow]**
A request flows like this: User query → Supervisor retrieves memory → Creates plan → Routes to agents → Agents call MCP tools → Gateway translates to HTTP → Backends respond → Supervisor aggregates → Saves to memory → Generates report.

The key insight is three layers of separation: Agent layer for reasoning, Gateway layer for protocol translation, Backend layer for data access. This makes the system modular, testable, and production-ready."

---

### 3 Strong Demo Queries

**Query 1: Simple Investigation**
```
"Check the status of the api-server pod in the default namespace"
```

**Expected outcome:**
- Supervisor creates simple plan (1-2 steps)
- Routes to Kubernetes agent only
- Agent calls `k8s-api___get_pod_status`
- Returns pod status with details
- Duration: 10-15 seconds

**What to highlight:**
- Fast execution for simple queries
- Single-agent routing
- Clear, structured response

**Query 2: Multi-Agent Investigation**
```
"The api-server pod is restarting frequently. Investigate the root cause."
```

**Expected outcome:**
- Supervisor creates complex plan (3-4 steps)
- Routes to Kubernetes → Logs → Metrics agents
- Kubernetes finds OOMKilled status
- Logs finds OutOfMemoryError
- Metrics confirms memory limit reached
- Supervisor aggregates into root cause analysis
- Duration: 25-35 seconds

**What to highlight:**
- Multi-agent collaboration
- Sequential execution following plan
- Memory context used in planning
- Comprehensive final report

**Query 3: Memory-Informed Investigation**
```
"We saw high CPU usage yesterday. Is it happening again?"
```

**Expected outcome:**
- Supervisor retrieves past investigation from memory
- Creates plan based on previous findings
- Routes to Metrics agent
- Compares current metrics to baseline
- References previous investigation in response
- Duration: 15-20 seconds

**What to highlight:**
- Memory retrieval before planning
- Learning from past investigations
- Personalized response
- Faster resolution due to context

---

## Summary

**Failure modes to know:**
1. JWT token expired (regenerate token)
2. Gateway targets not READY (wait or check logs)
3. Backend servers not running (start servers)
4. Wrong container architecture (build ARM64)
5. IAM trust policy misconfigured (fix trust policy)

**Hard questions to prepare:**
1. Architecture walkthrough
2. Why LangGraph over Bedrock Agents
3. What is MCP and why use it
4. How memory system works
5. Production changes needed
6. Scaling to 100 concurrent investigations
7. Gateway failure handling
8. Token expiry handling
9. IAM permissions explained
10. Connecting to real infrastructure
11. Gateway vs Runtime differences
12. Production monitoring strategy

**Demo preparation:**
- 2-minute opening statement
- 3-minute architecture walkthrough
- 3 strong demo queries with expected outcomes
