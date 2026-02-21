# Auth Chain — Every Hop from User to Backend

## The Full Auth Chain

```
IAM User → Bedrock → Cognito → JWT → Gateway → Credential Provider → Backend API Key
```

Each hop validates credentials and passes context to the next layer. Let's trace through each step.

---

## Hop 1: IAM User → Bedrock

### IAM User Credentials

**Who:** The AWS IAM user running the agent (you, the developer)

**Credentials:**
- Access Key ID: `AKIA...`
- Secret Access Key: `...`
- Configured in `~/.aws/credentials` or environment variables

**What they're used for:**
- Calling Bedrock API (LLM inference)
- Calling AgentCore API (gateway management, memory operations)
- Calling S3 API (uploading OpenAPI specs)

**Permissions required:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock-agentcore:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Validation:**
- AWS SigV4 signature verification
- IAM policy evaluation
- Rate limiting and quotas

---

## Hop 2: Bedrock → Cognito (JWT Generation)

### Cognito User Pool Setup

**File:** `gateway/.env`

```bash
COGNITO_USER_POOL_ID=us-east-1_CPukh9Ilm
COGNITO_CLIENT_ID=7pvnt90jh7gdnhe4al23vn389d
COGNITO_CLIENT_SECRET=3mihl92u677n0dkste567qmjuo2gbhsr98ls2b542fc7ifrodst
COGNITO_REGION=us-east-1
COGNITO_DOMAIN=https://sre-agent-1771399755.auth.us-east-1.amazoncognito.com
```

**What each component is:**

**COGNITO_USER_POOL_ID:**
- Format: `{region}_{random-id}`
- Example: `us-east-1_CPukh9Ilm`
- Identifies the user pool containing agent users
- Used by gateway to validate JWT tokens

**COGNITO_CLIENT_ID:**
- Format: 26-character alphanumeric string
- Example: `7pvnt90jh7gdnhe4al23vn389d`
- OAuth 2.0 client ID for the agent application
- Included in JWT as `aud` (audience) or `client_id` claim

**COGNITO_CLIENT_SECRET:**
- Format: 52-character alphanumeric string
- Example: `3mihl92u677n0dkste567qmjuo2gbhsr98ls2b542fc7ifrodst`
- Used to authenticate the client when requesting tokens
- Never exposed to end users or agents

**COGNITO_DOMAIN:**
- Format: `https://{domain-prefix}.auth.{region}.amazoncognito.com`
- Example: `https://sre-agent-1771399755.auth.us-east-1.amazoncognito.com`
- Hosted UI domain for Cognito
- Discovery URL: `{domain}/.well-known/jwks.json`

### How JWT Token Is Generated

**File:** `gateway/generate_token.py`

```python
def generate_token():
    # Prepare authentication request
    auth_url = f"{COGNITO_DOMAIN}/oauth2/token"
    
    # Client credentials grant
    data = {
        "grant_type": "client_credentials",
        "client_id": COGNITO_CLIENT_ID,
        "client_secret": COGNITO_CLIENT_SECRET
    }
    
    # Request token
    response = requests.post(
        auth_url,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    
    token_data = response.json()
    access_token = token_data["access_token"]
    
    # Save to file
    with open(".access_token", "w") as f:
        f.write(access_token)
    
    return access_token
```

**Token structure (JWT):**
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "abc123..."
  },
  "payload": {
    "sub": "7pvnt90jh7gdnhe4al23vn389d",
    "token_use": "access",
    "scope": "sre-gateway/invoke",
    "auth_time": 1706025600,
    "iss": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_CPukh9Ilm",
    "exp": 1706029200,
    "iat": 1706025600,
    "client_id": "7pvnt90jh7gdnhe4al23vn389d"
  },
  "signature": "..."
}
```

**Key claims:**

**sub (subject):**
- The client ID (for client credentials grant)
- Identifies who the token was issued to

**iss (issuer):**
- The Cognito User Pool URL
- Used by gateway to fetch public keys for verification

**exp (expiration):**
- Unix timestamp when token expires
- Default: 1 hour (3600 seconds) from `iat`

**iat (issued at):**
- Unix timestamp when token was issued

**client_id:**
- The OAuth client ID
- Gateway validates this matches allowed clients

---

## Hop 3: JWT Token Validation by Gateway

### Why Token Expires in 1 Hour

**Cognito default:** 1 hour (3600 seconds)

**Security reasoning:**
1. **Limit blast radius:** If token is stolen, it's only valid for 1 hour
2. **Force re-authentication:** Ensures user/client is still authorized
3. **Enable revocation:** Can revoke access by not issuing new tokens
4. **Compliance:** Many security standards require short-lived tokens

**Configurable:** Can be changed in Cognito User Pool settings
- Minimum: 5 minutes
- Maximum: 24 hours
- Recommended: 1-4 hours for production

**Trade-offs:**
- Shorter expiry: More secure, but more token refreshes
- Longer expiry: More convenient, but higher security risk

### How Gateway Validates JWT

**Step 1: Extract token from request**
```http
POST /mcp
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Step 2: Decode header (without verification)**
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "abc123..."
}
```

**Step 3: Fetch public key from Cognito**
```python
jwks_url = f"{COGNITO_DOMAIN}/.well-known/jwks.json"
jwks = requests.get(jwks_url).json()

# Find key matching kid from token header
public_key = find_key(jwks["keys"], kid="abc123...")
```

**Step 4: Verify signature**
```python
import jwt

decoded = jwt.decode(
    token,
    public_key,
    algorithms=["RS256"],
    audience=COGNITO_CLIENT_ID,
    issuer=f"https://cognito-idp.us-east-1.amazonaws.com/{COGNITO_USER_POOL_ID}"
)
```

**Step 5: Check expiration**
```python
current_time = time.time()
if decoded["exp"] < current_time:
    raise TokenExpiredError("Token has expired")
```

**Step 6: Validate claims**
```python
if decoded["client_id"] != COGNITO_CLIENT_ID:
    raise InvalidTokenError("Invalid client_id")

if decoded["token_use"] != "access":
    raise InvalidTokenError("Invalid token_use")
```

**If all checks pass:** Gateway proceeds to process the request

**If any check fails:** Gateway returns 401 Unauthorized

---

## Hop 4: Gateway → Credential Provider

### The Credential Provider: What It Is

**Definition:** A secure storage service for backend credentials, managed by AWS AgentCore.

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

**What it stores:**
- Backend API key: `1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b`
- Encryption: AWS-managed (KMS)
- Access control: IAM-based

### Where Backend API Key Is Stored

**File:** `gateway/.env`

```bash
BACKEND_API_KEY=1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
```

**How it's uploaded to Credential Provider:**

**File:** `gateway/create_credentials_provider.py`

```python
def create_api_key_credential_provider(
    client,
    provider_name: str,
    api_key: str
):
    response = client.create_credential_provider(
        name=provider_name,
        description="API Key Credential Provider for SRE Agent backends",
        credentialProviderType="API_KEY",
        credentialProviderConfiguration={
            "apiKeyCredentialProvider": {
                "apiKey": api_key
            }
        }
    )
    return response

# Usage
api_key = os.getenv("BACKEND_API_KEY")
create_api_key_credential_provider(
    client,
    provider_name="sre-agent-api-key-credential-provider",
    api_key=api_key
)
```

**Security benefits:**
- API key never in agent code
- API key never in gateway configuration
- API key encrypted at rest
- API key access logged

### How Gateway Fetches Credentials at Runtime

**For each tool call:**

**Step 1: Gateway receives tool call**
```json
{
  "method": "tools/call",
  "params": {
    "name": "k8s-api___get_pod_status",
    "arguments": {"namespace": "default", "pod_name": "api-server"}
  }
}
```

**Step 2: Gateway looks up target**
```python
target_name = "k8s-api"  # From tool name prefix
target = get_target(gateway_id, target_name)
provider_arn = target.credential_provider_configurations[0].provider_arn
```

**Step 3: Gateway calls Credential Provider**
```python
credentials = credential_provider_client.get_credential(
    providerArn=provider_arn
)
api_key = credentials["apiKey"]
```

**Step 4: Gateway adds credential to request**
```python
headers = {
    "X-API-KEY": api_key,
    "Content-Type": "application/json"
}
```

**Step 5: Gateway makes HTTP request**
```http
GET http://127.0.0.1:8001/pods/default/api-server
X-API-KEY: 1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
```

---

## Hop 5: Backend API Key Validation

### Backend Server Validation

**File:** `backend/servers/k8s_server.py`

```python
from fastapi import FastAPI, Header, HTTPException

app = FastAPI()

EXPECTED_API_KEY = os.getenv("BACKEND_API_KEY")

@app.get("/pods/{namespace}/{pod_name}")
async def get_pod_status(
    namespace: str,
    pod_name: str,
    x_api_key: str = Header(...)
):
    # Validate API key
    if x_api_key != EXPECTED_API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    
    # Process request
    pod_data = load_pod_data(namespace, pod_name)
    return pod_data
```

**Validation steps:**
1. Extract `X-API-KEY` header
2. Compare with expected API key (constant-time comparison)
3. If match: Process request
4. If no match: Return 401 Unauthorized

---

## IAM Role: BedrockAgentCoreRole

### Trust Policy

**File:** Trust policy for `BedrockAgentCoreRole`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock-agentcore.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "310485116687"
        }
      }
    }
  ]
}
```

**What this means:**
- The `bedrock-agentcore.amazonaws.com` service can assume this role
- Only for resources in account `310485116687`
- This allows AgentCore Gateway to act on your behalf

**Why this trust matters:**
- Gateway needs to access S3 (for OpenAPI specs)
- Gateway needs to access Credential Provider (for API keys)
- Gateway needs to write CloudWatch logs
- Without this trust, gateway cannot function

### The 3 IAM Policies

**Policy 1: AmazonBedrockFullAccess**

**Purpose:** Allow gateway to call Bedrock APIs

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Why needed:**
- Gateway may need to call Bedrock for internal operations
- Required for AgentCore service integration

**Policy 2: ECRAccessPolicy**

**Purpose:** Allow AgentCore Runtime to pull container images

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

**Why needed:**
- AgentCore Runtime runs your agent code in a container
- Container image is stored in ECR
- Runtime needs to pull image to execute

**Policy 3: CloudWatchLogsPolicy**

**Purpose:** Allow gateway to write logs

**Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:310485116687:log-group:/aws/bedrock-agentcore/*"
    }
  ]
}
```

**Why needed:**
- Gateway logs all requests and responses
- Logs are essential for debugging
- CloudWatch Logs is the standard AWS logging service

---

## How Container in AgentCore Runtime Gets AWS Credentials

### IAM Role, Not Keys in Environment

**Wrong approach (insecure):**
```dockerfile
ENV AWS_ACCESS_KEY_ID=AKIA...
ENV AWS_SECRET_ACCESS_KEY=...
```

**Correct approach (secure):**
```python
# No credentials in code or environment
# AWS SDK automatically uses IAM role
import boto3

client = boto3.client("bedrock-runtime")
# Credentials are automatically fetched from instance metadata
```

**How it works:**

**Step 1: AgentCore Runtime assumes role**
```
AgentCore Runtime → STS AssumeRole → BedrockAgentCoreRole
```

**Step 2: STS returns temporary credentials**
```json
{
  "AccessKeyId": "ASIA...",
  "SecretAccessKey": "...",
  "SessionToken": "...",
  "Expiration": "2025-01-22T15:30:00Z"
}
```

**Step 3: Runtime injects credentials into container**
```bash
# Environment variables set by runtime
AWS_ACCESS_KEY_ID=ASIA...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
```

**Step 4: AWS SDK in container uses credentials**
```python
# boto3 automatically reads from environment
client = boto3.client("bedrock-runtime")
# No explicit credentials needed
```

**Benefits:**
- No long-term credentials in code
- Credentials rotate automatically (1 hour expiry)
- Credentials are scoped to role permissions
- Audit trail in CloudTrail

---

## What Breaks at Each Hop If Auth Fails

### Hop 1: IAM User → Bedrock

**Error:**
```
botocore.exceptions.NoCredentialsError: Unable to locate credentials
```

**Cause:**
- No AWS credentials configured
- `~/.aws/credentials` file missing
- Environment variables not set

**Fix:**
```bash
aws configure
# Or
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

### Hop 2: Bedrock → Cognito

**Error:**
```
400 Bad Request: invalid_client
```

**Cause:**
- Wrong `COGNITO_CLIENT_ID` or `COGNITO_CLIENT_SECRET`
- Client doesn't exist in User Pool

**Fix:**
- Verify client ID in Cognito console
- Regenerate client secret if needed

### Hop 3: JWT Validation

**Error:**
```
401 Unauthorized: Token has expired
```

**Cause:**
- Token is older than 1 hour
- System clock is wrong

**Fix:**
```bash
# Regenerate token
python gateway/generate_token.py

# Or check system time
date
```

**Error:**
```
401 Unauthorized: Invalid signature
```

**Cause:**
- Token was tampered with
- Wrong public key used for verification

**Fix:**
- Regenerate token
- Verify Cognito domain is correct

### Hop 4: Gateway → Credential Provider

**Error:**
```
403 Forbidden: Access Denied
```

**Cause:**
- Gateway role doesn't have permission to access Credential Provider
- Credential Provider doesn't exist

**Fix:**
- Add IAM policy to gateway role
- Verify provider ARN is correct

### Hop 5: Backend API Key

**Error:**
```
401 Unauthorized: Invalid API key
```

**Cause:**
- Wrong API key in Credential Provider
- Backend expects different API key

**Fix:**
```bash
# Verify API key matches
echo $BACKEND_API_KEY
# Update Credential Provider if needed
```

---

## The Misleading "Failed to obtain execution role credentials" Error

### What the Error Says

```
Error: Failed to obtain execution role credentials
```

### What It Actually Means

This error is misleading. It doesn't mean the execution role is wrong. It usually means one of:

**1. Gateway targets are not READY**
```bash
# Check target status
python gateway/check_gateway_targets.py

# If status is CREATING, wait
# If status is FAILED, check CloudWatch logs
```

**2. JWT token has expired**
```bash
# Regenerate token
python gateway/generate_token.py

# Update environment variable
export GATEWAY_ACCESS_TOKEN=$(cat gateway/.access_token)
```

**3. Gateway URL is wrong**
```bash
# Verify gateway URL
cat sre_agent/config/agent_config.yaml

# Should match gateway URL from creation
```

**4. MCP client can't connect to gateway**
```bash
# Test gateway connectivity
curl -H "Authorization: Bearer $(cat gateway/.access_token)" \
     https://{gateway-url}/mcp
```

### Real Causes (Not Execution Role)

**Execution role is usually fine if:**
- Gateway was created successfully
- Targets were added successfully
- You can list gateways and targets

**Real issues are usually:**
- Network connectivity
- Token expiration
- Target status
- Gateway configuration

---

## Summary: Auth Chain Flow

```
1. IAM User (AWS credentials)
   ↓ [SigV4 signature]
2. Bedrock API (validates IAM)
   ↓ [Client credentials grant]
3. Cognito (issues JWT)
   ↓ [JWT token, 1-hour expiry]
4. Gateway (validates JWT)
   ↓ [Fetches from Credential Provider]
5. Credential Provider (returns API key)
   ↓ [X-API-KEY header]
6. Backend (validates API key)
   ↓ [Returns data]
7. Response travels back up the chain
```

**Key security principles:**
- Each layer validates independently
- Credentials are never passed through multiple layers
- Short-lived tokens (JWT: 1 hour, IAM role: 1 hour)
- Audit trail at each layer (CloudTrail, CloudWatch Logs)
