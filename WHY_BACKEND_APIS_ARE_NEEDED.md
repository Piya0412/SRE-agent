# Why Backend APIs Are Needed for SRE Agent

## Overview

The SRE (Site Reliability Engineering) Multi-Agent System requires backend APIs to provide real-time infrastructure data to AI agents. These APIs serve as the data layer that agents query to investigate issues, analyze metrics, and provide operational insights.

---

## Architecture Context

```
┌─────────────────┐
│   User Query    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  SRE AI Agent   │ ◄── Uses AWS Bedrock (Claude/Nova)
│   (LangGraph)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AgentCore       │ ◄── MCP Protocol Gateway
│   Gateway       │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│         Backend APIs (FastAPI)          │
├─────────────┬─────────────┬─────────────┤
│  K8s API    │  Logs API   │ Metrics API │ Runbooks API
│  Port 8011  │  Port 8012  │  Port 8013  │ Port 8014
└─────────────┴─────────────┴─────────────┘
         │
         ▼
┌─────────────────┐
│   Mock Data     │ ◄── Simulated infrastructure data
│   (JSON files)  │
└─────────────────┘
```

---

## Why Backend APIs Are Essential

### 1. **Data Source for AI Agents**

AI agents need real-time infrastructure data to:
- Investigate incidents (e.g., "Why is the database pod crashing?")
- Analyze performance trends
- Provide troubleshooting recommendations
- Execute operational runbooks

**Without backend APIs:** Agents would have no data to analyze and couldn't provide meaningful insights.

### 2. **Separation of Concerns**

```
Agent Layer (AI Logic)  ←→  API Layer (Data Access)  ←→  Data Layer (Storage)
```

- **Agent Layer:** Focuses on reasoning, decision-making, and orchestration
- **API Layer:** Handles data retrieval, authentication, and formatting
- **Data Layer:** Stores infrastructure metrics, logs, and configurations

This separation allows:
- Independent scaling of each layer
- Easier testing and debugging
- Flexibility to swap data sources (mock → real Kubernetes cluster)

### 3. **AgentCore Gateway Integration**

AWS Bedrock AgentCore Gateway uses the **Model Context Protocol (MCP)** to:
1. Expose backend APIs as "tools" to AI agents
2. Handle authentication and authorization
3. Manage API rate limiting and quotas
4. Provide observability and logging

**The Gateway needs OpenAPI specifications** (which we uploaded to S3) to understand:
- What endpoints are available
- What parameters each endpoint accepts
- What data format to expect in responses

### 4. **Multi-Agent Orchestration**

Your SRE system has **5 specialized agents**:

| Agent | Purpose | Backend API Used |
|-------|---------|------------------|
| **Supervisor Agent** | Routes queries to specialists | All APIs |
| **Kubernetes Agent** | Pod status, deployments, events | K8s API (8011) |
| **Logs Agent** | Error log analysis, search | Logs API (8012) |
| **Metrics Agent** | Performance, resource usage | Metrics API (8013) |
| **Runbooks Agent** | Troubleshooting guides | Runbooks API (8014) |

Each agent calls specific backend APIs to gather domain-specific data.

---

## Real-World Example: Incident Investigation

**User Query:** "The web application is slow. What's wrong?"

**Agent Workflow:**

1. **Supervisor Agent** receives the query
2. Routes to **Metrics Agent** → Calls `GET /performance_metrics` (Port 8013)
   - Discovers: Response time increased from 200ms to 2000ms
3. Routes to **Kubernetes Agent** → Calls `GET /pods/status` (Port 8011)
   - Discovers: `database-pod` is in `CrashLoopBackOff` state
4. Routes to **Logs Agent** → Calls `GET /error_logs` (Port 8012)
   - Discovers: "Connection refused to database:5432"
5. Routes to **Runbooks Agent** → Calls `GET /troubleshooting_guide` (Port 8014)
   - Retrieves: "Database Connection Failure Runbook"

**Final Response:** "The web app is slow because the database pod is crashing. Follow the database recovery runbook to restart the pod and check connection settings."

**Without backend APIs:** The agent would have no data to analyze and couldn't provide this diagnosis.

---

## Why Mock Data for Development?

For your **L2 interview preparation**, you're using **mock backend APIs** with synthetic data because:

### ✅ Advantages:
1. **No Real Infrastructure Required:** Don't need an actual Kubernetes cluster
2. **Predictable Testing:** Mock data is consistent and reproducible
3. **Fast Iteration:** No waiting for real metrics to accumulate
4. **Cost-Effective:** No AWS infrastructure costs during development
5. **Controlled Scenarios:** Can simulate specific failure conditions

### Production Transition:
In production, you would replace mock APIs with:
- Real Kubernetes API calls (`kubectl` equivalent)
- CloudWatch Logs integration
- Prometheus/Grafana metrics
- PagerDuty/Jira runbook systems

The **agent code remains unchanged** because it only interacts with the API interface.

---

## Current Status (Day 1 Complete)

✅ **4 Backend APIs Running:**
- K8s API: `http://127.0.0.1:8011` (Healthy)
- Logs API: `http://127.0.0.1:8012` (Healthy)
- Metrics API: `http://127.0.0.1:8013` (Healthy)
- Runbooks API: `http://127.0.0.1:8014` (Healthy)

✅ **OpenAPI Specs Generated:**
- All 4 YAML files created in `backend/openapi_specs/`
- Uploaded to S3: `sre-agent-specs-1771225925`

✅ **Authentication Working:**
- Using `BACKEND_API_KEY` environment variable
- All endpoints require `X-API-Key` header

✅ **Mock Data Available:**
- Kubernetes pods (5 pods with various states)
- Application logs (error patterns, counts)
- Performance metrics (response times, error rates)
- Operational runbooks (troubleshooting guides)

---

## Next Steps (Day 2)

1. **Configure AgentCore Gateway:**
   - Point gateway to backend API endpoints
   - Load OpenAPI specs from S3
   - Generate 24-hour access token

2. **Test Agent Integration:**
   - Send test query: "List all pods in production namespace"
   - Verify agent calls K8s API correctly
   - Check response formatting

3. **Multi-Agent Orchestration:**
   - Test supervisor routing logic
   - Verify agent collaboration
   - Generate investigation report

---

## Key Takeaway

**Backend APIs are the "eyes and ears" of your SRE agents.** Without them, agents are blind to infrastructure state and cannot provide meaningful assistance. The APIs bridge the gap between AI reasoning (agents) and real-world data (infrastructure metrics, logs, events).

For your L2 interview, being able to explain this architecture demonstrates:
- Understanding of multi-tier system design
- Knowledge of API-driven architectures
- Grasp of AI agent tool integration
- Practical SRE operational workflows

---

**Document Created:** February 16, 2026  
**Status:** Day 1 Complete - Backend APIs Operational  
**Next Milestone:** Day 2 - AgentCore Gateway Integration
