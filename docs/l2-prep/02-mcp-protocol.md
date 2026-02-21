# MCP Protocol — What It Is and Why It's Used

## What is MCP (Model Context Protocol)?

MCP is a standardized protocol created by Anthropic for LLMs to interact with external tools and data sources. Think of it as "OpenAPI for AI agents."

**Core concept:** Instead of agents calling APIs directly, they call tools through MCP, and an MCP server/gateway translates those calls to actual API requests.

**Analogy:** MCP is to AI agents what GraphQL is to web clients — a unified interface that abstracts away backend complexity.

---

## Why MCP Instead of Direct API Calls?

### 1. Tool Abstraction

**Without MCP:**
```python
# Agent needs to know exact API details
response = requests.get(
    "http://127.0.0.1:8001/pods/default/api-server",
    headers={"X-API-KEY": "1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b"}
)
```

**With MCP:**
```python
# Agent just calls a tool
result = k8s_api___get_pod_status(namespace="default", pod_name="api-server")
```

**Benefits:**
- Agent doesn't need to know URLs, headers, or authentication
- Tool interface is stable even if backend changes
- Same tool can work with different backends (dev, staging, prod)

### 2. Auth Separation

**Security principle:** Agents should never have direct access to credentials.

**MCP flow:**
1. Agent calls tool with business parameters only
2. Gateway validates agent's JWT token
3. Gateway fetches backend credentials from Credential Provider
4. Gateway makes authenticated request to backend
5. Gateway returns sanitized response to agent

**What agents never see:**
- Backend URLs
- API keys
- Database credentials
- Internal network topology

### 3. Replaceability

**Scenario:** You want to replace the demo K8s backend with a real Kubernetes cluster.

**Without MCP:**
- Rewrite agent code to use Kubernetes Python client
- Update authentication logic
- Change data parsing
- Redeploy agents

**With MCP:**
- Update OpenAPI spec to point to real K8s API
- Upload new spec to S3
- Update gateway target
- **Agents require zero changes**

---

## How the AgentCore Gateway Implements MCP

### Gateway Configuration

**File:** `gateway/config.yaml`

```yaml
account_id: '310485116687'
client_id: 7pvnt90jh7gdnhe4al23vn389d
gateway_name: sre-gateway
region: us-east-1
endpoint_url: https://bedrock-agentcore-control.us-east-1.amazonaws.com
provider_arn: arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider
s3_bucket: sre-agent-specs-1771225925
s3_path_prefix: devops-multiagent-demo
```

**Key components:**

1. **Gateway Name:** `sre-gateway`
   - Unique identifier for this gateway instance
   - Used in ARN: `arn:aws:bedrock-agentcore:us-east-1:310485116687:gateway/sre-gateway-{id}`

2. **Endpoint URL:** `https://bedrock-agentcore-control.us-east-1.amazonaws.com`
   - AWS service endpoint for AgentCore control plane
   - Handles gateway creation, target management, credential provider setup

3. **Provider ARN:** Points to the credential provider
   - Type: API Key Credential Provider
   - Stores backend API key securely
   - Gateway fetches this at runtime for each request

4. **S3 Bucket:** `sre-agent-specs-1771225925`
   - Stores OpenAPI specs for each backend
   - Gateway reads these to discover available tools

### Gateway Environment Variables

**File:** `gateway/.env`

```bash
# Cognito Configuration
COGNITO_USER_POOL_ID=us-east-1_CPukh9Ilm
COGNITO_CLIENT_ID=7pvnt90jh7gdnhe4al23vn389d
COGNITO_CLIENT_SECRET=3mihl92u677n0dkste567qmjuo2gbhsr98ls2b542fc7ifrodst
COGNITO_REGION=us-east-1
COGNITO_DOMAIN=https://sre-agent-1771399755.auth.us-east-1.amazoncognito.com

# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=310485116687

# Backend Configuration
BACKEND_DOMAIN=127.0.0.1
BACKEND_API_KEY=1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
```

**What each variable does:**

**COGNITO_USER_POOL_ID:**
- Identifies the Cognito User Pool for JWT validation
- Gateway uses this to fetch JWKS (JSON Web Key Set) for signature verification
- Format: `{region}_{random-id}`

**COGNITO_CLIENT_ID:**
- The OAuth 2.0 client ID
- Gateway checks JWT's `aud` (audience) or `client_id` claim matches this
- Prevents tokens from other applications being used

**COGNITO_CLIENT_SECRET:**
- Used for token generation (not by gateway itself)
- Required by `generate_token.py` to get access tokens
- Never exposed to agents

**COGNITO_DOMAIN:**
- The Cognito hosted UI domain
- Discovery URL: `{COGNITO_DOMAIN}/.well-known/jwks.json`
- Gateway fetches public keys from here to validate JWT signatures

**BACKEND_API_KEY:**
- The actual API key for backend servers
- Stored in Credential Provider
- Gateway fetches this for each backend request
- Format: 64-character hex string (SHA-256 hash)

---

## Tool Naming Convention: Triple Underscore

**Format:** `{target-name}___{operation-id}`

**Examples:**
- `k8s-api___get_pod_status`
- `logs-api___search_logs`
- `metrics-api___get_response_times`
- `runbooks-api___get_troubleshooting_guide`

**Why triple underscore?**

1. **Namespace separation:** Clearly distinguishes target from operation
2. **No conflicts:** Triple underscore is rare in natural naming
3. **Easy parsing:** `tool_name.split("___")` gives `[target, operation]`
4. **MCP convention:** Follows MCP protocol recommendations

**How it's generated:**

**File:** `backend/openapi_specs/k8s_api.yaml`

```yaml
paths:
  /pods/{namespace}/{pod_name}:
    get:
      operationId: get_pod_status  # This becomes the operation part
      ...
```

**Gateway target name:** `k8s-api` (from S3 upload)

**Final tool name:** `k8s-api___get_pod_status`

---

## The OpenAPI Spec → S3 → Gateway Target Flow

### Step 1: Generate OpenAPI Specs

**File:** `backend/openapi_specs/generate_specs.sh`

```bash
#!/bin/bash
# Generates OpenAPI specs from template files
for template in *.yaml.template; do
    envsubst < "$template" > "${template%.template}"
done
```

**Templates include:**
- `k8s_api.yaml.template`
- `logs_api.yaml.template`
- `metrics_api.yaml.template`
- `runbooks_api.yaml.template`

**Variables substituted:**
- `${BACKEND_DOMAIN}` → `127.0.0.1` (or ngrok URL)
- `${K8S_PORT}` → `8001`
- `${LOGS_PORT}` → `8002`
- etc.

### Step 2: Upload to S3

**Command:**
```bash
aws s3 cp backend/openapi_specs/k8s_api.yaml \
    s3://sre-agent-specs-1771225925/devops-multiagent-demo/k8s_api.yaml
```

**S3 structure:**
```
s3://sre-agent-specs-1771225925/
└── devops-multiagent-demo/
    ├── k8s_api.yaml
    ├── logs_api.yaml
    ├── metrics_api.yaml
    └── runbooks_api.yaml
```

### Step 3: Create Gateway Target

**File:** `gateway/main.py`

**Function:** `create_s3_target()`

```python
def create_s3_target(
    client: Any,
    gateway_id: str,
    s3_uri: str,
    provider_arn: str,
    target_name_prefix: str = "open",
    description: str = "S3 target for OpenAPI schema"
) -> Dict[str, Any]:
    s3_target_config = {
        "mcp": {
            "openApiSchema": {
                "s3": {"uri": s3_uri}
            }
        }
    }
    
    credential_config = {
        "credentialProviderType": "API_KEY",
        "credentialProvider": {
            "apiKeyCredentialProvider": {
                "providerArn": provider_arn,
                "credentialLocation": "HEADER",
                "credentialParameterName": "X-API-KEY"
            }
        }
    }
    
    response = client.create_gateway_target(
        gatewayIdentifier=gateway_id,
        name=target_name_prefix,
        description=description,
        targetConfiguration=s3_target_config,
        credentialProviderConfigurations=[credential_config]
    )
    return response
```

**What happens:**
1. Gateway reads OpenAPI spec from S3
2. Parses all `operationId` values
3. Creates MCP tools: `{target_name}___{operationId}`
4. Stores mapping: tool name → HTTP endpoint + method
5. Associates credential provider for authentication

### Step 4: Gateway Target Status

**Check target status:**
```bash
python gateway/check_gateway_targets.py
```

**Output:**
```
Gateway Targets:
  • k8s-api (ID: target-abc123)
    Description: Kubernetes API operations
    Status: READY
  • logs-api (ID: target-def456)
    Description: Logs API operations
    Status: READY
  ...
```

**Status values:**
- `CREATING` — Gateway is processing the OpenAPI spec
- `READY` — Tools are available for use
- `FAILED` — Spec parsing failed (check CloudWatch logs)

---

## What "Gateway Targets" Are

**Definition:** A gateway target is a mapping between:
1. An OpenAPI specification (defines available operations)
2. A backend service (where requests are sent)
3. A credential provider (how to authenticate)

**Target components:**

**Target Name:** `k8s-api`
- Used in tool naming: `k8s-api___get_pod_status`
- Must be unique within a gateway
- Naming convention: lowercase with hyphens

**Target Configuration:**
```json
{
  "mcp": {
    "openApiSchema": {
      "s3": {
        "uri": "s3://sre-agent-specs-1771225925/devops-multiagent-demo/k8s_api.yaml"
      }
    }
  }
}
```

**Credential Provider Configuration:**
```json
{
  "credentialProviderType": "API_KEY",
  "credentialProvider": {
    "apiKeyCredentialProvider": {
      "providerArn": "arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider",
      "credentialLocation": "HEADER",
      "credentialParameterName": "X-API-KEY"
    }
  }
}
```

**How targets map to backends:**

The OpenAPI spec contains the server URL:
```yaml
servers:
  - url: http://127.0.0.1:8001
    description: Kubernetes API Server
```

When a tool is called:
1. Gateway looks up target by name (from tool name prefix)
2. Reads server URL from OpenAPI spec
3. Fetches credentials from provider
4. Makes HTTP request to `{server_url}{path}`

---

## The Credential Provider: Secure API Key Storage

### What is a Credential Provider?

A credential provider is an AWS-managed secret store specifically for AgentCore. It's like AWS Secrets Manager, but optimized for agent-to-backend authentication.

**Provider ARN:**
```
arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider
```

**ARN breakdown:**
- Service: `bedrock-agentcore`
- Region: `us-east-1`
- Account: `310485116687`
- Resource type: `token-vault/default/apikeycredentialprovider`
- Resource name: `sre-agent-api-key-credential-provider`

### How API Keys Are Stored

**File:** `gateway/create_credentials_provider.py`

```python
def create_api_key_credential_provider(
    client,
    provider_name: str,
    api_key: str,
    description: str = "API Key Credential Provider"
):
    response = client.create_credential_provider(
        name=provider_name,
        description=description,
        credentialProviderType="API_KEY",
        credentialProviderConfiguration={
            "apiKeyCredentialProvider": {
                "apiKey": api_key
            }
        }
    )
    return response
```

**What gets stored:**
- Provider name: `sre-agent-api-key-credential-provider`
- API key value: `1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b`
- Encryption: AWS-managed (KMS)

### How Gateway Fetches Credentials

**At runtime, for each tool call:**

1. Gateway receives tool call: `k8s-api___get_pod_status(...)`
2. Gateway looks up target: `k8s-api`
3. Gateway reads credential provider ARN from target config
4. Gateway calls credential provider API: `GetCredential(providerArn)`
5. Credential provider returns: `{"apiKey": "1a2db5e..."}`
6. Gateway adds header: `X-API-KEY: 1a2db5e...`
7. Gateway makes HTTP request to backend

**Why this matters:**
- API key is never in agent code
- API key is never in gateway configuration files
- API key is fetched fresh for each request
- API key can be rotated without redeploying agents

---

## The 1-Hour JWT Token Expiry

### Why It Exists

**Security principle:** Short-lived tokens limit the blast radius of token theft.

**Cognito default:** 1 hour (3600 seconds)

**Configurable:** Can be changed in Cognito User Pool settings (5 minutes to 24 hours)

### What Breaks When It Expires

**Symptom:** After 1 hour of agent runtime:
```
Error: 401 Unauthorized
Message: Token has expired
```

**What happens:**
1. Agent calls MCP tool
2. MCP client sends JWT in Authorization header
3. Gateway validates JWT signature (succeeds)
4. Gateway checks `exp` claim: `1706025600` (Unix timestamp)
5. Current time: `1706029200` (1 hour later)
6. Gateway rejects: `exp < current_time`
7. Returns 401 to agent

**Impact:**
- All subsequent tool calls fail
- Agent cannot complete investigation
- User sees error message

### How to Handle in Production

**Option 1: Token refresh (recommended)**
```python
def refresh_token_if_needed(token: str) -> str:
    payload = jwt.decode(token, options={"verify_signature": False})
    exp = payload.get("exp", 0)
    if time.time() > exp - 300:  # Refresh 5 minutes before expiry
        return get_new_token()
    return token
```

**Option 2: Extend token lifetime**
- Cognito User Pool → App client settings → Token expiration
- Set to 24 hours for long-running investigations
- Trade-off: Increased security risk

**Option 3: Session-based authentication**
- Use Cognito refresh tokens
- Automatically refresh access token in background
- Requires implementing token refresh flow

**Current implementation:** No automatic refresh (demo limitation)

---

## How an Agent Calls a Tool vs How It Becomes an HTTP Request

### Agent's Perspective

**Code:** (conceptual — actual code is in LangChain internals)
```python
# Agent decides to call a tool
result = k8s_api___get_pod_status(
    namespace="default",
    pod_name="api-server"
)
```

**What the agent knows:**
- Tool name: `k8s_api___get_pod_status`
- Tool description: "Get the status of a specific pod"
- Parameters: `namespace` (string), `pod_name` (string)
- Return type: JSON object

**What the agent doesn't know:**
- Backend URL
- HTTP method (GET/POST/etc.)
- Authentication mechanism
- API key value

### LangChain MCP Adapter's Translation

**File:** `langchain_mcp_adapters` (external library)

**Step 1: Convert to MCP format**
```json
{
  "method": "tools/call",
  "params": {
    "name": "k8s-api___get_pod_status",
    "arguments": {
      "namespace": "default",
      "pod_name": "api-server"
    }
  }
}
```

**Step 2: Add authentication**
```http
POST {gateway_uri}/mcp
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{MCP request body}
```

### Gateway's Translation to HTTP

**Step 1: Parse tool name**
```python
target_name, operation_id = "k8s-api___get_pod_status".split("___")
# target_name = "k8s-api"
# operation_id = "get_pod_status"
```

**Step 2: Look up target**
```python
target = get_target(gateway_id, target_name)
openapi_spec = load_from_s3(target.s3_uri)
```

**Step 3: Find operation in OpenAPI spec**
```yaml
paths:
  /pods/{namespace}/{pod_name}:
    get:
      operationId: get_pod_status
      parameters:
        - name: namespace
          in: path
        - name: pod_name
          in: path
```

**Step 4: Build HTTP request**
```python
method = "GET"
path = "/pods/{namespace}/{pod_name}".format(
    namespace="default",
    pod_name="api-server"
)
url = f"{server_url}{path}"  # http://127.0.0.1:8001/pods/default/api-server
```

**Step 5: Fetch credentials**
```python
credentials = credential_provider.get_credential(provider_arn)
api_key = credentials["apiKey"]
```

**Step 6: Make HTTP request**
```python
response = requests.get(
    url,
    headers={"X-API-KEY": api_key}
)
```

**Step 7: Return to agent**
```json
{
  "result": {
    "status": "Running",
    "restarts": 0,
    "cpu_usage": "45%",
    "memory_usage": "1.2Gi"
  }
}
```

---

## Why Replacing a Backend Only Requires Updating the OpenAPI Spec

### Scenario: Replace Demo Backend with Real Kubernetes

**Current setup:**
- Backend: `backend/servers/k8s_server.py` (FastAPI, reads JSON files)
- URL: `http://127.0.0.1:8001`
- Auth: API key

**New setup:**
- Backend: Real Kubernetes API
- URL: `https://kubernetes.default.svc.cluster.local`
- Auth: Service account token

### What Changes

**1. Update OpenAPI spec**

**File:** `backend/openapi_specs/k8s_api.yaml`

**Before:**
```yaml
servers:
  - url: http://127.0.0.1:8001
    description: Demo Kubernetes API

paths:
  /pods/{namespace}/{pod_name}:
    get:
      operationId: get_pod_status
      ...
```

**After:**
```yaml
servers:
  - url: https://kubernetes.default.svc.cluster.local/api/v1
    description: Real Kubernetes API

paths:
  /namespaces/{namespace}/pods/{pod_name}:
    get:
      operationId: get_pod_status
      ...
```

**2. Update credential provider**

**Before:** API key provider

**After:** Bearer token provider
```python
client.create_credential_provider(
    name="k8s-service-account-provider",
    credentialProviderType="BEARER_TOKEN",
    credentialProviderConfiguration={
        "bearerTokenCredentialProvider": {
            "token": service_account_token
        }
    }
)
```

**3. Upload new spec to S3**
```bash
aws s3 cp k8s_api.yaml s3://sre-agent-specs-1771225925/devops-multiagent-demo/k8s_api.yaml
```

**4. Update gateway target**
```bash
python gateway/add_gateway_targets.py \
    --gateway-id sre-gateway-xyz \
    --target-name k8s-api \
    --s3-uri s3://sre-agent-specs-1771225925/devops-multiagent-demo/k8s_api.yaml \
    --provider-arn arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/bearertokencredentialprovider/k8s-service-account-provider
```

### What Doesn't Change

**Agent code:** Zero changes
- Still calls `k8s_api___get_pod_status(namespace, pod_name)`
- Still receives same response structure
- Doesn't know or care that backend changed

**LangGraph configuration:** Zero changes
- Same graph structure
- Same agent nodes
- Same routing logic

**Memory system:** Zero changes
- Same memory strategies
- Same namespaces
- Same retrieval logic

**This is the power of MCP:** Complete backend abstraction.

---

## Summary: MCP Value Proposition

**For agents:**
- Simple, stable tool interface
- No credential management
- Backend-agnostic code

**For operators:**
- Centralized authentication
- Easy backend replacement
- Audit trail of all tool calls

**For security:**
- Credentials never exposed to agents
- Short-lived JWT tokens
- Fine-grained access control

**For scalability:**
- Gateway handles rate limiting
- Credential provider handles secret rotation
- Backends can scale independently
