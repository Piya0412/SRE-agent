# The Full Request Flow — CLI to Response

## Overview

This document traces a complete request through the SRE Agent system, from CLI invocation to final report generation. Every component, file, and function is referenced from the actual codebase.

---

## Entry Point: cli.py → multi_agent_langgraph.py

**File:** `sre_agent/cli.py`

The journey starts when you run:
```bash
python -m sre_agent.cli
```

The `main()` function in `cli.py` is minimal — it imports and runs `multi_agent_langgraph.py`:

```python
from .multi_agent_langgraph import main as multi_agent_main
asyncio.run(multi_agent_main())
```

**File:** `sre_agent/multi_agent_langgraph.py`

The `main()` function handles:
- Argument parsing (interactive vs single prompt mode)
- User ID extraction from `USER_ID` env var (defaults to `SREConstants.agents.default_user_id`)
- Session ID generation: `f"{mode}-{datetime.now().strftime('%Y%m%d%H%M%S')}"`
- Calls `create_multi_agent_system()` to initialize everything

---

## The 3 Critical Initializations (Before Any LLM Call)

### 1. MCP Connection — Loading 21 Tools

**Function:** `create_mcp_client()` in `multi_agent_langgraph.py`

```python
def create_mcp_client() -> MultiServerMCPClient:
    gateway_uri, access_token, _ = _read_gateway_config()
    client = MultiServerMCPClient({
        "gateway": {
            "url": f"{gateway_uri}/mcp",
            "transport": "streamable_http",
            "headers": {"Authorization": f"Bearer {access_token}"}
        }
    })
    return client
```

**What happens:**
- Reads `sre_agent/config/agent_config.yaml` for gateway URI
- Reads `GATEWAY_ACCESS_TOKEN` from environment (JWT token, 1-hour expiry)
- Creates MCP client pointing to `{gateway_uri}/mcp`
- Calls `client.get_tools()` with 30-second timeout (`SREConstants.timeouts.mcp_tools_timeout_seconds`)
- Returns 21 tools with names like `k8s-api___get_pod_status`, `logs-api___search_logs`, etc.

**Tool naming convention:** `{target-name}___{operation-id}`
- Triple underscore separates target from operation
- Example: `metrics-api___get_response_times` → target: `metrics-api`, operation: `get_response_times`

### 2. Memory Client — Bedrock Memory Initialization

**File:** `sre_agent/memory/client.py`

**Class:** `SREMemoryClient.__init__()`

```python
self.client = MemoryClient(region_name=region)
self.memory_name = "sre_agent_memory"
self._initialize_memories()
```

**What `_initialize_memories()` does:**
1. Checks for existing memory by name prefix: `sre_agent_memory-*`
2. If found, uses existing memory ID (e.g., `sre_agent_memory-W7MyNnE0HE`)
3. If not found, creates new memory with `create_memory()`
4. Adds 3 strategies if they don't exist:
   - **user_preferences** (User Preference Strategy)
     - Namespace: `/sre/users/{actorId}/preferences`
   - **infrastructure_knowledge** (Semantic Strategy)
     - Namespace: `/sre/infrastructure/{actorId}/{sessionId}`
   - **investigation_summaries** (Summary Strategy)
     - Namespace: `/sre/investigations/{actorId}/{sessionId}`

**Memory ID written to:** `.memory_id` file in project root

### 3. LangGraph Graph Construction

**File:** `sre_agent/graph_builder.py`

**Function:** `build_multi_agent_graph()`

Creates a `StateGraph` with 7 nodes:
1. **prepare** — Initializes state with current query
2. **supervisor** — Routes to agents, creates investigation plans
3. **kubernetes_agent** — Handles K8s queries
4. **logs_agent** — Handles log analysis
5. **metrics_agent** — Handles performance metrics
6. **runbooks_agent** — Handles operational procedures
7. **aggregate** — Combines results into final response

**Edges:**
- `prepare` → `supervisor`
- `supervisor` → (conditional) → one of 4 agents or `aggregate`
- Each agent → `supervisor` (loop back for next step)
- `aggregate` → `END`

**Entry point:** `workflow.set_entry_point("prepare")`

---

## How the Supervisor Receives the Query

**File:** `sre_agent/supervisor.py`

**Class:** `SupervisorAgent`

**Method:** `route(state: AgentState)`

**Initial state structure:**
```python
initial_state: AgentState = {
    "messages": [HumanMessage(content=user_prompt)],
    "next": "supervisor",
    "agent_results": {},
    "current_query": user_prompt,
    "metadata": {},
    "requires_collaboration": False,
    "agents_invoked": [],
    "final_response": None,
    "auto_approve_plan": True,  # In runtime mode
    "session_id": session_id,
    "user_id": user_id,
}
```

---

## Memory Retrieval FIRST (Before Planning)

**Method:** `SupervisorAgent.create_investigation_plan(state)`

**Step 1: Retrieve memory context**

```python
memory_context = self.memory_hooks.on_investigation_start(
    query=current_query,
    user_id=user_id,
    actor_id=actor_id,
    session_id=session_id,
    incident_id=incident_id
)
```

**What `on_investigation_start()` does:**
1. Retrieves user preferences:
   - Query: `"user settings communication escalation notification reporting workflow preferences"`
   - Namespace: `/sre/users/{user_id}/preferences`
   - Max results: 10
2. Retrieves infrastructure knowledge for each agent:
   - Query: current_query (semantic search)
   - Namespace: `/sre/infrastructure/{agent_id}` (cross-session)
   - Max results: 50 per agent
3. Retrieves past investigations:
   - Query: current_query (semantic search)
   - Namespace: `/sre/investigations/{user_id}` (cross-session)
   - Max results: 5

**Memory context structure:**
```python
{
    "user_preferences": [...],  # List of UserPreference objects
    "infrastructure_by_agent": {
        "kubernetes-agent": [...],
        "logs-agent": [...],
        ...
    },
    "past_investigations": [...]
}
```

---

## Creating the Investigation Plan

**Step 2: Generate plan with memory context**

The supervisor uses a planning agent (ReAct agent with memory tools) to create a structured plan:

**Prompt structure:**
```
{supervisor_system_prompt}

User's query: {current_query}

Relevant User Preferences:
{json.dumps(memory_context['user_preferences'])}

Relevant Infrastructure Knowledge (organized by agent):
{json.dumps(memory_context['infrastructure_by_agent'])}

Similar Past Investigations:
{json.dumps(memory_context['past_investigations'])}

{planning_instructions}
```

**Output:** `InvestigationPlan` (Pydantic model)
```python
class InvestigationPlan(BaseModel):
    steps: List[str]  # 3-5 investigation steps
    agents_sequence: List[str]  # e.g., ["kubernetes_agent", "logs_agent"]
    complexity: Literal["simple", "complex"]
    auto_execute: bool
    reasoning: str
```

**Plan approval logic:**
- If `complexity == "complex"` and `auto_approve_plan == False`: Present plan to user
- Otherwise: Auto-execute

---

## How Each Specialist Agent Receives Context

**File:** `sre_agent/agent_nodes.py`

**Example:** `create_kubernetes_agent()`

Each agent is a LangChain ReAct agent created with:
```python
agent = create_react_agent(
    llm,
    tools=filtered_tools,  # Only tools matching agent's domain
    state_modifier=system_prompt
)
```

**Filtered tools example for Kubernetes Agent:**
- `k8s-api___get_pod_status`
- `k8s-api___list_pods`
- `k8s-api___get_deployment_status`
- `k8s-api___list_nodes`
- `k8s-api___get_resource_usage`
- `get_current_time` (local tool)
- `retrieve_memory` (memory tool)

**System prompt includes:**
- Agent identity: `"You are the Kubernetes Infrastructure Agent"`
- Actor ID: `"kubernetes-agent"` (from `SREConstants.agents.agents["kubernetes"]`)
- Available tools list
- Current investigation step from plan
- Memory context (infrastructure knowledge specific to this agent)

---

## How MCP Gateway Translates Tool Calls

**When agent calls:** `k8s-api___get_pod_status(namespace="default", pod_name="api-server")`

**Step 1: LangChain MCP Adapter**
- Converts LangChain tool call to MCP protocol format
- Adds JWT token to Authorization header

**Step 2: Gateway receives request**

**File:** `gateway/main.py` (conceptually — actual gateway is AWS-managed)

**Gateway validates:**
1. JWT token signature (using Cognito discovery URL)
2. Token expiry (1 hour from generation)
3. Allowed clients (matches `COGNITO_CLIENT_ID`)

**Step 3: Gateway routes to target**

Gateway has targets configured (from S3 OpenAPI specs):
- `k8s-api` → `http://127.0.0.1:8001` (via ngrok)
- `logs-api` → `http://127.0.0.1:8002`
- `metrics-api` → `http://127.0.0.1:8003`
- `runbooks-api` → `http://127.0.0.1:8004`

**Step 4: Credential Provider fetches API key**

Gateway calls Credential Provider:
- Provider ARN: `arn:aws:bedrock-agentcore:us-east-1:310485116687:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider`
- Returns: `BACKEND_API_KEY` from `.env` file

**Step 5: Gateway makes HTTP request**

```http
GET http://127.0.0.1:8001/pods/default/api-server
X-API-KEY: 1a2db5e23451bdc3e9b42b265aa7278449a7e0171989eee91b4d9c8607aa0f7b
```

**Step 6: Backend server responds**

**File:** `backend/servers/k8s_server.py`

```python
@app.get("/pods/{namespace}/{pod_name}")
async def get_pod_status(namespace: str, pod_name: str):
    # Reads from backend/data/k8s_data/pods.json
    return {"status": "Running", "restarts": 0, ...}
```

---

## Response Travel Back Up

**Backend → Gateway:**
```json
{
  "status": "Running",
  "restarts": 0,
  "cpu_usage": "45%",
  "memory_usage": "1.2Gi"
}
```

**Gateway → MCP Client:**
- Wraps in MCP protocol format
- Returns to LangChain MCP Adapter

**MCP Adapter → Agent:**
- Converts to LangChain tool result
- Agent's ReAct loop processes result

**Agent → Supervisor:**
- Agent adds result to `agent_results[agent_name]`
- Returns control to supervisor

**Supervisor routing:**
- Checks investigation plan
- If more steps remain: Routes to next agent
- If plan complete: Routes to `aggregate`

---

## Memory Hooks That Fire at the End

**File:** `sre_agent/memory/hooks.py`

**Method:** `MemoryHookProvider.on_investigation_complete()`

**Triggered by:** `SupervisorAgent.aggregate_responses()`

**Three memory saves happen:**

### 1. Investigation Summary
```python
summary = InvestigationSummary(
    incident_id=incident_id,
    query=query,
    timeline=[...],
    actions_taken=[...],
    resolution_status="completed",
    key_findings=[...]
)
client.save_event(
    memory_type="investigations",
    actor_id=user_id,  # User's ID
    event_data=summary.model_dump(),
    session_id=session_id
)
```
**Namespace:** `/sre/investigations/{user_id}/{session_id}`

### 2. Infrastructure Knowledge (per agent)
```python
for agent_name, result in agent_results.items():
    knowledge = InfrastructureKnowledge(
        service_name=extract_service_name(result),
        knowledge_type="investigation",
        knowledge_data=result,
        confidence=0.8
    )
    client.save_event(
        memory_type="infrastructure",
        actor_id=agent_actor_id,  # e.g., "kubernetes-agent"
        event_data=knowledge.model_dump(),
        session_id=session_id
    )
```
**Namespace:** `/sre/infrastructure/{agent_actor_id}/{session_id}`

### 3. User Preferences (if detected)
```python
# Only if new preferences detected in conversation
preference = UserPreference(
    user_id=user_id,
    preference_type="escalation",
    preference_value={"contact": "alice@example.com"}
)
client.save_event(
    memory_type="preferences",
    actor_id=user_id,
    event_data=preference.model_dump()
)
```
**Namespace:** `/sre/users/{user_id}/preferences`

---

## Final Report Saved to reports/ Directory

**Function:** `_save_final_response_to_markdown()` in `multi_agent_langgraph.py`

**Filename format:**
```
{clean_query}_user_id_{user_id}_{timestamp}.md
```

**Example:**
```
high_cpu_usage_in_api_server_user_id_Alice_20250122_143052.md
```

**Content structure:**
```markdown
# SRE Investigation Report

**Generated:** 2025-01-22 14:30:52

**Query:** High CPU usage in api-server pod

---

{final_response from aggregate node}

---
*Report generated by SRE Multi-Agent Assistant*
```

**Archiving:** Old reports (not from today) are moved to date-based folders:
- `reports/2025-01-21/`
- `reports/2025-01-20/`

---

## Text-Based Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ USER INVOKES CLI                                                │
│ python -m sre_agent.cli --prompt "Check pod status"            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ INITIALIZATION (3 steps)                                        │
│ 1. MCP Client connects to Gateway (loads 21 tools)             │
│ 2. Memory Client initializes (3 strategies)                    │
│ 3. LangGraph builds graph (7 nodes)                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ PREPARE NODE                                                    │
│ - Extracts query from HumanMessage                             │
│ - Initializes agent_results, agents_invoked                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ SUPERVISOR NODE (First Call)                                   │
│ 1. Retrieve memory context (preferences, infrastructure, past) │
│ 2. Create investigation plan with memory context               │
│ 3. Route to first agent in plan                                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ SPECIALIST AGENT (e.g., Kubernetes Agent)                      │
│ 1. Receives filtered tools (k8s-api___ prefix)                │
│ 2. ReAct loop: Reason → Act → Observe                         │
│ 3. Calls MCP tool: k8s-api___get_pod_status                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ MCP GATEWAY                                                     │
│ 1. Validates JWT token (Cognito)                               │
│ 2. Looks up target: k8s-api → http://127.0.0.1:8001          │
│ 3. Fetches API key from Credential Provider                    │
│ 4. Makes HTTP request with X-API-KEY header                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ BACKEND SERVER (k8s_server.py)                                 │
│ 1. Validates API key                                            │
│ 2. Reads from backend/data/k8s_data/pods.json                  │
│ 3. Returns JSON response                                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ RESPONSE TRAVELS BACK                                           │
│ Backend → Gateway → MCP Client → Agent                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ AGENT COMPLETES                                                 │
│ - Adds result to agent_results["kubernetes_agent"]            │
│ - Returns to supervisor                                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ SUPERVISOR NODE (Loop)                                          │
│ - Checks plan: more steps?                                      │
│ - If yes: Route to next agent                                   │
│ - If no: Route to aggregate                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ AGGREGATE NODE                                                  │
│ 1. Combines all agent_results                                   │
│ 2. Formats final response (output_formatter.py)                │
│ 3. Triggers memory hooks (save investigation, infrastructure)  │
│ 4. Returns final_response                                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ SAVE REPORT                                                     │
│ - Filename: {query}_user_id_{user_id}_{timestamp}.md          │
│ - Location: reports/                                            │
│ - Archives old reports to date folders                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Insight: 3 Layers of Separation

1. **Agent Layer** (LangGraph + LangChain)
   - Orchestration, reasoning, tool calling
   - Files: `multi_agent_langgraph.py`, `supervisor.py`, `agent_nodes.py`

2. **Gateway Layer** (AWS AgentCore Gateway)
   - Protocol translation (MCP → HTTP)
   - Authentication (JWT validation)
   - Authorization (Credential Provider)
   - Tool discovery (OpenAPI specs from S3)

3. **Backend Layer** (FastAPI servers)
   - Data access (JSON files)
   - Business logic (minimal in demo)
   - Files: `backend/servers/*.py`

**Why this matters:**
- Agents never know backend URLs or API keys
- Backends can be replaced without changing agent code
- Gateway handles all security and routing
- Each layer can scale independently

---

## Performance Characteristics

**Typical request timing:**
- MCP tool loading: 2-5 seconds (first time)
- Memory retrieval: 0.5-1 second per query
- Investigation planning: 3-5 seconds
- Per-agent execution: 5-10 seconds
- Aggregation: 2-3 seconds
- **Total: 20-40 seconds for a 2-agent investigation**

**Bottlenecks:**
- LLM inference (Bedrock/Anthropic API calls)
- MCP Gateway round-trip latency
- Memory semantic search

**Optimization opportunities:**
- Cache MCP tools (already implemented)
- Parallel agent execution (not yet implemented)
- Streaming responses (not yet implemented)
