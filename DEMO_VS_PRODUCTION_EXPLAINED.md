# Demo vs Production: Understanding the SRE Agent Project

## What You Asked

> "How do real production systems do this? What is mentioned in this project's README?"

Great question! Let me explain what's DEMO/FAKE in this project vs what would be REAL in production.

---

## The Key Disclaimer from README

The README explicitly states:

> **Important Note**: The data in [`backend/data`](backend/data) is synthetically generated, and the backend directory contains stub servers that showcase how a real SRE agent backend could work. In a production environment, these implementations would need to be replaced with real implementations that connect to actual systems, use vector databases, and integrate with other data sources.

**Translation:** The 4 backend servers are just EXAMPLES showing the architecture. They serve FAKE data. In production, you'd replace them with REAL systems.

---

## What's DEMO (Fake) in This Project

### 1. Backend API Servers (All 4 Are Fake!)

```
┌─────────────────────────────────────────────────────────────────┐
│ DEMO BACKEND SERVERS (What You Have Now)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ K8s API Server (Port 8011)                              │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ • Reads from: backend/data/k8s_data/pods.json           │    │
│ │ • Returns: FAKE pod data (not real Kubernetes)          │    │
│ │ • Purpose: Show how agent would query K8s               │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Logs API Server (Port 8012)                             │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ • Reads from: backend/data/logs_data/logs.json          │    │
│ │ • Returns: FAKE log entries (not real logs)             │    │
│ │ • Purpose: Show how agent would search logs             │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Metrics API Server (Port 8013)                          │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ • Reads from: backend/data/metrics_data/metrics.json    │    │
│ │ • Returns: FAKE metrics (not real monitoring data)      │    │
│ │ • Purpose: Show how agent would analyze metrics         │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Runbooks API Server (Port 8014)                         │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ • Reads from: backend/data/runbooks_data/runbooks.json  │    │
│ │ • Returns: FAKE runbooks (not real procedures)          │    │
│ │ • Purpose: Show how agent would retrieve runbooks       │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ALL DATA IS FAKE! Just for demonstration!                      │
└─────────────────────────────────────────────────────────────────┘
```

**What's in `backend/data/`:**
- `k8s_data/` - Fake Kubernetes pods, deployments, events
- `logs_data/` - Fake application logs with synthetic errors
- `metrics_data/` - Fake CPU, memory, performance metrics
- `runbooks_data/` - Fake troubleshooting procedures

**Why it's fake:**
- No real Kubernetes cluster
- No real log aggregation system
- No real monitoring system
- Just JSON files with made-up data

---

## What's REAL in This Project

### 1. The SRE Agent (Your AI Code)

```
┌─────────────────────────────────────────────────────────────────┐
│ REAL: SRE AGENT CODE                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ✅ Multi-agent orchestration (Supervisor + 4 specialists)       │
│ ✅ LangGraph workflow management                                │
│ ✅ Memory integration (remembers user preferences)              │
│ ✅ Report generation (creates markdown reports)                 │
│ ✅ MCP protocol integration (talks to Gateway)                  │
│                                                                 │
│ This is REAL production-ready code!                             │
│ You can use this agent with REAL backend systems!               │
└─────────────────────────────────────────────────────────────────┘
```

**What's real:**
- The agent logic (how it investigates issues)
- The multi-agent collaboration
- The memory system integration
- The report generation
- The MCP protocol communication

**Why it's real:**
- This code works with ANY backend that provides the right APIs
- You just need to replace the fake backend with real systems

---

### 2. AWS Services (All Real!)

```
┌─────────────────────────────────────────────────────────────────┐
│ REAL: AWS SERVICES                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ✅ AgentCore Gateway (real AWS service)                         │
│ ✅ AgentCore Memory (real AWS service)                          │
│ ✅ AgentCore Runtime (real AWS service)                         │
│ ✅ Amazon Cognito (real authentication)                         │
│ ✅ Amazon Bedrock (real AI models)                              │
│                                                                 │
│ These are production AWS services!                              │
└─────────────────────────────────────────────────────────────────┘
```

**What's real:**
- Your Gateway is a real AWS Gateway
- Your Memory is a real AWS Memory service
- Authentication via Cognito is real
- AI models (Claude/Nova) are real

---

## How Real Production Systems Work

### Production Backend Architecture

In a REAL production environment, you would replace the 4 fake backend servers with connections to ACTUAL systems:

```
┌─────────────────────────────────────────────────────────────────┐
│ PRODUCTION BACKEND (What Real Companies Use)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ K8s API → REAL KUBERNETES CLUSTER                       │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ Instead of: backend/data/k8s_data/pods.json             │    │
│ │ Use: kubectl API or Kubernetes Python client            │    │
│ │                                                         │    │
│ │ Example:                                                │    │
│ │   from kubernetes import client, config                 │    │
│ │   config.load_kube_config()                             │    │
│ │   v1 = client.CoreV1Api()                               │    │
│ │   pods = v1.list_namespaced_pod("production")           │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Logs API → REAL LOG AGGREGATION SYSTEM                  │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ Instead of: backend/data/logs_data/logs.json            │    │
│ │ Use: Elasticsearch, Splunk, CloudWatch Logs, etc.       │    │
│ │                                                         │    │
│ │ Example:                                                │    │
│ │   from elasticsearch import Elasticsearch               │    │
│ │   es = Elasticsearch(['https://logs.company.com'])      │    │
│ │   results = es.search(index="app-logs", query={...})    │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Metrics API → REAL MONITORING SYSTEM                    │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ Instead of: backend/data/metrics_data/metrics.json      │    │
│ │ Use: Prometheus, Datadog, CloudWatch Metrics, etc.      │    │
│ │                                                         │    │
│ │ Example:                                                │    │
│ │   from prometheus_api_client import PrometheusConnect   │    │
│ │   prom = PrometheusConnect(url="https://prom.co.com")   │    │
│ │   metrics = prom.custom_query(query="cpu_usage{...}")   │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ Runbooks API → REAL KNOWLEDGE BASE                      │    │
│ │ ─────────────────────────────────────────────────────── │    │
│ │ Instead of: backend/data/runbooks_data/runbooks.json    │    │
│ │ Use: Confluence, Notion, internal wiki, vector DB       │    │
│ │                                                         │    │
│ │ Example:                                                │    │
│ │   from atlassian import Confluence                      │    │
│ │   confluence = Confluence(url="https://wiki.co.com")    │    │
│ │   page = confluence.get_page_by_title("Runbooks")       │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Architecture is Plug-and-Play

The README says:

> "This demo serves as an illustration of the architecture, where the backend components are designed to be plug-and-play replaceable."

**What this means:**

```
┌─────────────────────────────────────────────────────────────────┐
│ THE ARCHITECTURE STAYS THE SAME                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Agent → Gateway → Backend APIs                                  │
│                                                                 │
│ You just REPLACE the backend APIs!                              │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ DEMO:                                                   │    │
│ │ Agent → Gateway → Fake K8s API (reads JSON file)       │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ PRODUCTION:                                             │    │
│ │ Agent → Gateway → Real K8s API (calls kubectl)          │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ The agent code doesn't change!                                  │
│ The Gateway configuration doesn't change!                       │
│ Only the backend implementation changes!                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Real-World Example: How Netflix Would Use This

Let's say Netflix wanted to use this SRE Agent:

### What They'd Keep (From This Project)

✅ **The SRE Agent code** - Multi-agent system, memory integration, report generation
✅ **AgentCore Gateway** - AWS service for MCP protocol
✅ **AgentCore Memory** - AWS service for remembering user preferences
✅ **AgentCore Runtime** - AWS service for running the agent
✅ **The architecture** - Agent → Gateway → Backend APIs

### What They'd Replace (Backend APIs)

❌ **Fake K8s API** → ✅ **Real Netflix Kubernetes clusters**
- Connect to their actual K8s clusters (thousands of pods)
- Use their internal K8s API or kubectl

❌ **Fake Logs API** → ✅ **Real Netflix log system**
- Connect to their Elasticsearch or Splunk
- Search billions of real log entries

❌ **Fake Metrics API** → ✅ **Real Netflix monitoring**
- Connect to their Prometheus or custom metrics system
- Query real CPU, memory, network metrics

❌ **Fake Runbooks API** → ✅ **Real Netflix knowledge base**
- Connect to their Confluence or internal wiki
- Retrieve real troubleshooting procedures

### The Result

```
┌─────────────────────────────────────────────────────────────────┐
│ NETFLIX'S PRODUCTION SRE AGENT                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ SRE Engineer: "Why is the streaming service slow?"              │
│                                                                 │
│ Agent investigates:                                             │
│ ├── Queries REAL Netflix K8s clusters                           │
│ ├── Searches REAL Netflix logs (billions of entries)            │
│ ├── Analyzes REAL Netflix metrics (thousands of servers)        │
│ └── Retrieves REAL Netflix runbooks                             │
│                                                                 │
│ Agent returns:                                                  │
│ "Found 47 pods in CrashLoopBackOff in us-west-2                 │
│  Root cause: Database connection pool exhausted                 │
│  Recommended action: Scale database replicas (Runbook #1234)"   │
│                                                                 │
│ ALL DATA IS REAL! Not fake JSON files!                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## How to Replace Demo Backend with Real Systems

### Step 1: Identify Your Real Systems

What do you actually use in your company?

- **Kubernetes**: EKS, GKE, on-prem K8s?
- **Logs**: Elasticsearch, Splunk, CloudWatch Logs, Datadog?
- **Metrics**: Prometheus, Datadog, CloudWatch Metrics, New Relic?
- **Runbooks**: Confluence, Notion, internal wiki, Google Docs?

---

### Step 2: Rewrite Backend Servers

Replace the fake backend servers with real API calls:

**Example: Replace Fake K8s API with Real K8s**

```python
# OLD (Demo): backend/servers/k8s_server.py
@app.get("/pods/status")
async def get_pod_status(namespace: str):
    # Read from fake JSON file
    with open("backend/data/k8s_data/pods.json") as f:
        fake_data = json.load(f)
    return fake_data

# NEW (Production): backend/servers/k8s_server.py
from kubernetes import client, config

@app.get("/pods/status")
async def get_pod_status(namespace: str):
    # Connect to REAL Kubernetes cluster
    config.load_kube_config()  # or load_incluster_config() if running in K8s
    v1 = client.CoreV1Api()
    
    # Get REAL pods from REAL cluster
    pods = v1.list_namespaced_pod(namespace)
    
    # Convert to same format as demo
    return {
        "pods": [
            {
                "name": pod.metadata.name,
                "namespace": pod.metadata.namespace,
                "status": pod.status.phase,
                "containers": [c.name for c in pod.spec.containers]
            }
            for pod in pods.items
        ]
    }
```

**Example: Replace Fake Logs API with Real Elasticsearch**

```python
# OLD (Demo): backend/servers/logs_server.py
@app.post("/search")
async def search_logs(query: str):
    # Read from fake JSON file
    with open("backend/data/logs_data/logs.json") as f:
        fake_logs = json.load(f)
    return fake_logs

# NEW (Production): backend/servers/logs_server.py
from elasticsearch import Elasticsearch

@app.post("/search")
async def search_logs(query: str):
    # Connect to REAL Elasticsearch
    es = Elasticsearch(['https://logs.company.com:9200'])
    
    # Search REAL logs
    results = es.search(
        index="application-logs-*",
        body={
            "query": {
                "query_string": {
                    "query": query
                }
            },
            "size": 100
        }
    )
    
    # Convert to same format as demo
    return {
        "logs": [
            {
                "timestamp": hit["_source"]["@timestamp"],
                "level": hit["_source"]["level"],
                "message": hit["_source"]["message"],
                "service": hit["_source"]["service"]
            }
            for hit in results["hits"]["hits"]
        ]
    }
```

---

### Step 3: Keep Everything Else the Same

**What DOESN'T change:**

✅ Agent code (sre_agent/)
✅ Gateway configuration
✅ Memory integration
✅ OpenAPI specs (just update URLs if needed)
✅ Authentication (Cognito)
✅ Deployment process

**What DOES change:**

❌ Backend server implementations (connect to real systems)
❌ Data sources (real APIs instead of JSON files)
❌ Possibly add caching, rate limiting, error handling

---

## Summary: Demo vs Production

### Demo (What You Have Now)

```
┌─────────────────────────────────────────────────────────────────┐
│ DEMO SETUP                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Purpose: Show how the architecture works                        │
│                                                                 │
│ Backend APIs:                                                   │
│ ├── K8s API: Reads backend/data/k8s_data/pods.json             │
│ ├── Logs API: Reads backend/data/logs_data/logs.json           │
│ ├── Metrics API: Reads backend/data/metrics_data/metrics.json  │
│ └── Runbooks API: Reads backend/data/runbooks_data/runbooks.json│
│                                                                 │
│ Data: ALL FAKE (synthetically generated)                        │
│                                                                 │
│ Use case: Learning, testing, demonstration                      │
└─────────────────────────────────────────────────────────────────┘
```

### Production (What Real Companies Use)

```
┌─────────────────────────────────────────────────────────────────┐
│ PRODUCTION SETUP                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Purpose: Investigate REAL infrastructure issues                 │
│                                                                 │
│ Backend APIs:                                                   │
│ ├── K8s API: Calls kubectl or Kubernetes Python client         │
│ ├── Logs API: Queries Elasticsearch, Splunk, CloudWatch        │
│ ├── Metrics API: Queries Prometheus, Datadog, CloudWatch       │
│ └── Runbooks API: Retrieves from Confluence, Notion, wiki      │
│                                                                 │
│ Data: ALL REAL (from actual production systems)                 │
│                                                                 │
│ Use case: Real SRE investigations, incident response            │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Key Insight

**From the README:**

> "The backend directory contains stub servers that showcase how a real SRE agent backend could work. In a production environment, these implementations would need to be replaced with real implementations that connect to actual systems."

**Translation:**

- The 4 backend servers are EXAMPLES
- They show the INTERFACE (what APIs the agent expects)
- They serve FAKE data (for demonstration)
- In production, you REPLACE them with real systems
- The agent code DOESN'T CHANGE
- The architecture STAYS THE SAME

**It's like a car demo:**
- Demo: Wooden steering wheel, fake engine, sits in showroom
- Production: Real steering wheel, real engine, drives on roads
- But the DESIGN is the same! Just replace fake parts with real parts!

---

## Your Next Steps

Based on your goal to deploy to production:

### Phase 1: Fix Current Demo (Get It Working)

1. Deploy backend to EC2 with domain + SSL (Option 1 from HOW_TO_FIX_CREDENTIAL_ISSUE.md)
2. Test agent locally: `uv run sre-agent --prompt "List pods"`
3. Verify agent can call Gateway → Gateway can call Backend

**Result:** Demo working end-to-end with FAKE data

---

### Phase 2: Deploy Agent to AgentCore Runtime

1. Build Docker image: `./deployment/build_and_deploy.sh`
2. Deploy to AgentCore Runtime
3. Test via API: `python deployment/invoke_agent_runtime.py`

**Result:** Agent running in AWS, still using FAKE backend data

---

### Phase 3: Replace Backend with Real Systems (Future)

1. Identify your real systems (K8s, logs, metrics, runbooks)
2. Rewrite backend servers to connect to real systems
3. Test with real data
4. Deploy to production

**Result:** Production SRE agent investigating REAL infrastructure!

---

## Final Answer to Your Question

**You asked:** "How do real production systems do this?"

**Answer:**

Real production systems use the SAME architecture (Agent → Gateway → Backend APIs), but they replace the 4 fake backend servers with connections to REAL systems:

- **Real Kubernetes clusters** (not fake JSON files)
- **Real log aggregation** (Elasticsearch, Splunk, etc.)
- **Real monitoring systems** (Prometheus, Datadog, etc.)
- **Real knowledge bases** (Confluence, wikis, etc.)

The agent code stays the same. The architecture stays the same. Only the backend implementation changes from "read JSON file" to "call real API".

**This project is a DEMO** showing you the architecture. In production, you'd keep the agent and replace the backend with real systems.
