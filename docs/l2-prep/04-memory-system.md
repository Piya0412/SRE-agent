# Memory System — Three Strategies and Persistent Context

## What is Bedrock Memory?

**Bedrock Memory** (officially: Amazon Bedrock AgentCore Memory) is a managed memory service for AI agents. It's NOT a database you manage — it's a fully managed service that handles:
- Storage and retrieval of agent memories
- Semantic search across memories
- Automatic summarization
- Namespace-based organization
- Event expiry and retention

**Think of it as:** A specialized vector database + summarization engine, optimized for agent memory patterns.

---

## The Memory ID: sre_agent_memory-W7MyNnE0HE

### What It Represents

**Format:** `{memory_name}-{random_suffix}`

**Example:** `sre_agent_memory-W7MyNnE0HE`

**Components:**
- `sre_agent_memory` — Base name (configured in code)
- `W7MyNnE0HE` — AWS-generated unique suffix

**Where it's created:**

**File:** `sre_agent/memory/client.py`

```python
class SREMemoryClient:
    def __init__(self, memory_name: str = "sre_agent_memory", ...):
        self.memory_name = memory_name
        self._initialize_memories()
```

**Creation:**
```python
base_memory = self.client.create_memory(
    name=self.memory_name,
    description="SRE Agent long-term memory system",
    event_expiry_days=max_retention
)
self.memory_id = base_memory["id"]  # e.g., "sre_agent_memory-W7MyNnE0HE"
```

**Persistence:**
- Written to `.memory_id` file in project root
- Used by helper scripts (`scripts/manage_memories.py`)
- Survives agent restarts

**Lookup on restart:**
```python
def _find_existing_memory(self) -> Optional[Dict[str, Any]]:
    memories = self.client.list_memories(max_results=100)
    for memory in memories:
        if memory["id"].startswith(f"{self.memory_name}-"):
            return memory
    return None
```

---

## The 3 Memory Strategies and Their Namespaces

### Strategy 1: User Preferences

**Type:** User Preference Strategy

**Purpose:** Store user-specific settings that persist across all sessions.

**Namespace:** `/sre/users/{user_id}/preferences`

**Example namespace:** `/sre/users/Alice/preferences`

**What gets stored:**
- Escalation contacts
- Notification preferences
- Reporting format preferences
- Communication style preferences
- Workflow automation settings

**Example memory:**
```json
{
  "user_id": "Alice",
  "preference_type": "escalation",
  "preference_value": {
    "primary_contact": "alice@example.com",
    "escalation_threshold": "critical",
    "escalation_delay_minutes": 15
  },
  "context": "User specified during incident investigation",
  "timestamp": "2025-01-22T14:30:00Z"
}
```

**Retrieval query:**
```python
memories = client.retrieve_memories(
    memory_id="sre_agent_memory-W7MyNnE0HE",
    namespace="/sre/users/Alice/preferences",
    query="user settings communication escalation notification reporting workflow preferences",
    top_k=10
)
```

**Key characteristics:**
- **Session-independent:** No `{sessionId}` in namespace
- **User-scoped:** Each user has their own preferences
- **Long retention:** 90 days (configurable)
- **Exact match retrieval:** Preferences are retrieved by user_id, not semantic search

### Strategy 2: Infrastructure Knowledge

**Type:** Semantic Strategy

**Purpose:** Store technical knowledge about infrastructure, services, and patterns discovered during investigations.

**Namespace:** `/sre/infrastructure/{actor_id}/{session_id}`

**Example namespace:** `/sre/infrastructure/kubernetes-agent/interactive-20250122143052`

**What gets stored:**
- Service dependencies
- Performance baselines
- Configuration patterns
- Known issues and workarounds
- Resource usage patterns

**Example memory:**
```json
{
  "service_name": "api-server",
  "knowledge_type": "baseline",
  "knowledge_data": {
    "normal_memory_usage": "400-500Mi",
    "normal_cpu_usage": "200-300m",
    "typical_restart_count": 0,
    "healthy_response_time": "50-100ms"
  },
  "confidence": 0.9,
  "context": "Observed during routine health check",
  "timestamp": "2025-01-22T14:30:00Z"
}
```

**Retrieval query (session-specific):**
```python
memories = client.retrieve_memories(
    memory_id="sre_agent_memory-W7MyNnE0HE",
    namespace="/sre/infrastructure/kubernetes-agent/interactive-20250122143052",
    query="api-server memory cpu performance",
    top_k=50
)
```

**Retrieval query (cross-session):**
```python
memories = client.retrieve_memories(
    memory_id="sre_agent_memory-W7MyNnE0HE",
    namespace="/sre/infrastructure/kubernetes-agent",  # No session_id
    query="api-server memory cpu performance",
    top_k=50
)
```

**Key characteristics:**
- **Agent-scoped:** Each agent (kubernetes, logs, metrics, runbooks) has its own knowledge
- **Session-aware:** Can retrieve from current session or across all sessions
- **Semantic search:** Uses vector similarity for retrieval
- **Medium retention:** 30 days (configurable)

### Strategy 3: Investigation Summaries

**Type:** Summary Strategy

**Purpose:** Store high-level summaries of past investigations for learning and pattern recognition.

**Namespace:** `/sre/investigations/{user_id}/{session_id}`

**Example namespace:** `/sre/investigations/Alice/interactive-20250122143052`

**What gets stored:**
- Incident summaries
- Investigation timelines
- Actions taken
- Resolution status
- Key findings

**Example memory:**
```json
{
  "incident_id": "inc-20250122-001",
  "query": "API server pod restarting frequently",
  "timeline": [
    {"time": "14:30", "event": "Investigation started"},
    {"time": "14:32", "event": "Kubernetes agent identified OOMKilled status"},
    {"time": "14:35", "event": "Logs agent found OutOfMemoryError"},
    {"time": "14:38", "event": "Metrics agent confirmed memory limit reached"}
  ],
  "actions_taken": [
    "Checked pod status",
    "Analyzed application logs",
    "Reviewed resource usage metrics"
  ],
  "resolution_status": "completed",
  "key_findings": [
    "Pod memory limit (512Mi) is too low",
    "Application heap size not configured",
    "No memory monitoring alerts configured"
  ],
  "context": "Production incident during peak traffic",
  "timestamp": "2025-01-22T14:40:00Z"
}
```

**Retrieval query (session-specific):**
```python
memories = client.retrieve_memories(
    memory_id="sre_agent_memory-W7MyNnE0HE",
    namespace="/sre/investigations/Alice/interactive-20250122143052",
    query="pod restarting memory issues",
    top_k=5
)
```

**Retrieval query (cross-session):**
```python
memories = client.retrieve_memories(
    memory_id="sre_agent_memory-W7MyNnE0HE",
    namespace="/sre/investigations/Alice",  # No session_id
    query="pod restarting memory issues",
    top_k=5
)
```

**Key characteristics:**
- **User-scoped:** Each user's investigations are separate
- **Session-aware:** Can retrieve from current session or across all sessions
- **Summarized:** Uses Summary Strategy for automatic summarization
- **Long retention:** 60 days (configurable)

---

## How Events Are Written (create_event)

**File:** `sre_agent/memory/client.py`

**Method:** `SREMemoryClient.save_event()`

```python
def save_event(
    self,
    memory_type: str,
    actor_id: str,
    event_data: Dict[str, Any],
    session_id: Optional[str] = None
) -> bool:
    # Convert event data to message format
    messages = [
        (str(event_data), "ASSISTANT")
    ]
    
    # For preferences, use default session_id since API requires it
    actual_session_id = session_id if session_id else "preferences-default"
    
    result = self.client.create_event(
        memory_id=self.memory_id,
        actor_id=actor_id,
        session_id=actual_session_id,
        messages=messages
    )
    
    return True
```

**Parameters:**

**memory_type:**
- Values: `"preferences"`, `"infrastructure"`, `"investigations"`
- Determines which namespace to use

**actor_id:**
- For preferences: user_id (e.g., `"Alice"`)
- For infrastructure: agent_id (e.g., `"kubernetes-agent"`)
- For investigations: user_id (e.g., `"Alice"`)

**event_data:**
- Dict containing the actual memory content
- Serialized to JSON string
- Stored as ASSISTANT message

**session_id:**
- Required for infrastructure and investigations
- Optional for preferences (uses default)

**Example calls:**

**Save preference:**
```python
client.save_event(
    memory_type="preferences",
    actor_id="Alice",
    event_data={
        "preference_type": "escalation",
        "preference_value": {"contact": "alice@example.com"}
    }
)
```

**Save infrastructure knowledge:**
```python
client.save_event(
    memory_type="infrastructure",
    actor_id="kubernetes-agent",
    event_data={
        "service_name": "api-server",
        "knowledge_type": "baseline",
        "knowledge_data": {"normal_memory": "400-500Mi"}
    },
    session_id="interactive-20250122143052"
)
```

**Save investigation summary:**
```python
client.save_event(
    memory_type="investigations",
    actor_id="Alice",
    event_data={
        "incident_id": "inc-001",
        "query": "Pod restarting",
        "key_findings": ["Memory limit too low"]
    },
    session_id="interactive-20250122143052"
)
```

---

## How Events Are Read (retrieve with semantic search)

**File:** `sre_agent/memory/client.py`

**Method:** `SREMemoryClient.retrieve_memories()`

```python
def retrieve_memories(
    self,
    memory_type: str,
    actor_id: str,
    query: str,
    max_results: int = 10,
    session_id: Optional[str] = None
) -> List[Dict[str, Any]]:
    # Get appropriate namespace
    namespace = self._get_namespace(memory_type, actor_id, session_id)
    
    result = self.client.retrieve_memories(
        memory_id=self.memory_id,
        namespace=namespace,
        query=query,
        top_k=max_results
    )
    
    return result
```

**Namespace construction:**

```python
def _get_namespace(
    self,
    memory_type: str,
    actor_id: str,
    session_id: Optional[str] = None
) -> str:
    if memory_type == "preferences":
        return f"/sre/users/{actor_id}/preferences"
    
    elif memory_type == "infrastructure":
        if session_id is None:
            # Cross-session search
            return f"/sre/infrastructure/{actor_id}"
        else:
            # Session-specific search
            return f"/sre/infrastructure/{actor_id}/{session_id}"
    
    elif memory_type == "investigations":
        if session_id is None:
            # Cross-session search
            return f"/sre/investigations/{actor_id}"
        else:
            # Session-specific search
            return f"/sre/investigations/{actor_id}/{session_id}"
```

**Example retrieval:**

```python
# Retrieve user preferences
prefs = client.retrieve_memories(
    memory_type="preferences",
    actor_id="Alice",
    query="escalation notification settings",
    max_results=10
)

# Retrieve infrastructure knowledge (cross-session)
knowledge = client.retrieve_memories(
    memory_type="infrastructure",
    actor_id="kubernetes-agent",
    query="api-server memory cpu baseline",
    max_results=50,
    session_id=None  # Search across all sessions
)

# Retrieve past investigations (current session only)
investigations = client.retrieve_memories(
    memory_type="investigations",
    actor_id="Alice",
    query="pod restarting memory issues",
    max_results=5,
    session_id="interactive-20250122143052"
)
```

---

## Why actor_id Differs Between Strategies

### Preferences: actor_id = user_id

**Reason:** Preferences are user-specific, not agent-specific.

**Example:**
- User "Alice" prefers email escalation
- User "Bob" prefers Slack escalation
- Each user has their own preferences

**Namespace:** `/sre/users/Alice/preferences`

**actor_id:** `"Alice"` (user_id)

### Infrastructure: actor_id = agent_id

**Reason:** Each agent learns about different aspects of infrastructure.

**Example:**
- Kubernetes agent learns about pod patterns
- Logs agent learns about error patterns
- Metrics agent learns about performance baselines
- Each agent has specialized knowledge

**Namespace:** `/sre/infrastructure/kubernetes-agent/{session_id}`

**actor_id:** `"kubernetes-agent"` (agent_id)

### Investigations: actor_id = user_id

**Reason:** Investigations are user-initiated and user-scoped.

**Example:**
- Alice investigates API server issues
- Bob investigates database issues
- Each user has their own investigation history

**Namespace:** `/sre/investigations/Alice/{session_id}`

**actor_id:** `"Alice"` (user_id)

---

## The Hooks System: Automatic Memory Capture

**File:** `sre_agent/memory/hooks.py`

**Class:** `MemoryHookProvider`

### Hook 1: on_investigation_start

**Triggered by:** `SupervisorAgent.create_investigation_plan()`

**Purpose:** Retrieve relevant memories before planning

**What it does:**
1. Retrieve user preferences
2. Retrieve infrastructure knowledge for each agent
3. Retrieve past investigations

**Code:**
```python
def on_investigation_start(
    self,
    query: str,
    user_id: str,
    actor_id: str,
    session_id: str,
    incident_id: Optional[str] = None
) -> Dict[str, Any]:
    # Retrieve user preferences
    user_prefs = self._retrieve_user_preferences(user_id)
    
    # Retrieve infrastructure knowledge for each agent
    infrastructure_by_agent = {}
    for agent_name in ["kubernetes-agent", "logs-agent", "metrics-agent", "runbooks-agent"]:
        knowledge = self._retrieve_infrastructure_knowledge(
            agent_id=agent_name,
            query=query,
            session_id=None  # Cross-session
        )
        infrastructure_by_agent[agent_name] = knowledge
    
    # Retrieve past investigations
    past_investigations = self._retrieve_investigation_summaries(
        user_id=user_id,
        query=query,
        session_id=None  # Cross-session
    )
    
    return {
        "user_preferences": user_prefs,
        "infrastructure_by_agent": infrastructure_by_agent,
        "past_investigations": past_investigations
    }
```

### Hook 2: on_investigation_complete

**Triggered by:** `SupervisorAgent.aggregate_responses()`

**Purpose:** Save investigation results to memory

**What it does:**
1. Save investigation summary
2. Save infrastructure knowledge from each agent
3. Save any new user preferences detected

**Code:**
```python
def on_investigation_complete(
    self,
    query: str,
    agent_results: Dict[str, Any],
    final_response: str,
    user_id: str,
    session_id: str,
    incident_id: str
) -> bool:
    # Save investigation summary
    summary = InvestigationSummary(
        incident_id=incident_id,
        query=query,
        actions_taken=extract_actions(agent_results),
        key_findings=extract_findings(final_response),
        resolution_status="completed"
    )
    self._save_investigation_summary(
        user_id=user_id,
        incident_id=incident_id,
        summary=summary,
        session_id=session_id
    )
    
    # Save infrastructure knowledge from each agent
    for agent_name, result in agent_results.items():
        knowledge = extract_knowledge(result)
        self._save_infrastructure_knowledge(
            agent_id=agent_name,
            knowledge=knowledge,
            session_id=session_id
        )
    
    return True
```

### Hook 3: on_agent_response

**Triggered by:** After each agent completes

**Purpose:** Capture agent-specific knowledge in real-time

**What it does:**
- Extracts technical details from agent response
- Saves to infrastructure knowledge namespace
- Associates with current session

---

## How Memory Context Is Injected Into Supervisor's Planning Prompt

**File:** `sre_agent/supervisor.py`

**Method:** `SupervisorAgent.create_investigation_plan()`

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

**Step 2: Format for prompt**
```python
memory_context_text = ""

if memory_context.get("user_preferences"):
    memory_context_text += f"\nRelevant User Preferences:\n{json.dumps(memory_context['user_preferences'], indent=2)}\n"

if memory_context.get("infrastructure_by_agent"):
    memory_context_text += "\nRelevant Infrastructure Knowledge (organized by agent):\n"
    for agent_id, memories in memory_context["infrastructure_by_agent"].items():
        memory_context_text += f"\n  From {agent_id} ({len(memories)} items):\n"
        memory_context_text += f"{json.dumps(memories, indent=4)}\n"

if memory_context.get("past_investigations"):
    memory_context_text += f"\nSimilar Past Investigations:\n{json.dumps(memory_context['past_investigations'], indent=2)}\n"
```

**Step 3: Include in planning prompt**
```python
planning_prompt = f"""{self.system_prompt}

User's query: {current_query}

{memory_context_text}

{planning_instructions}"""
```

**Example formatted context:**
```
User's query: API server pod is restarting

Relevant User Preferences:
[
  {
    "preference_type": "escalation",
    "preference_value": {
      "contact": "alice@example.com",
      "threshold": "critical"
    }
  }
]

Relevant Infrastructure Knowledge (organized by agent):

  From kubernetes-agent (3 items):
    [
      {
        "service_name": "api-server",
        "knowledge_type": "baseline",
        "knowledge_data": {
          "normal_memory": "400-500Mi"
        }
      }
    ]

Similar Past Investigations:
[
  {
    "query": "API server high memory usage",
    "key_findings": ["Memory limit too low", "Heap size not configured"]
  }
]

Create an investigation plan...
```

---

## What "Semantic Search" Means in This Context

**Traditional search (keyword matching):**
```
Query: "pod restarting"
Matches: Documents containing exact words "pod" AND "restarting"
```

**Semantic search (meaning-based):**
```
Query: "pod restarting"
Matches: Documents about:
- Container crashes
- OOMKilled errors
- CrashLoopBackOff status
- Application failures
- Resource limit issues
```

**How it works:**

1. **Embedding generation:**
   - Query is converted to vector: `[0.23, -0.45, 0.67, ...]` (1536 dimensions)
   - Each memory is converted to vector when stored

2. **Similarity calculation:**
   - Cosine similarity between query vector and memory vectors
   - Score from 0 (unrelated) to 1 (identical)

3. **Ranking:**
   - Memories sorted by similarity score
   - Top K results returned

**Example:**

**Query:** "Why is my pod crashing?"

**Retrieved memories (by similarity):**
1. Score 0.92: "Pod api-server experiencing OOMKilled errors"
2. Score 0.87: "Container restart loop due to memory limit"
3. Score 0.81: "Application crash with exit code 137"
4. Score 0.75: "Resource constraints causing pod failures"

**Why you can query by meaning:**
- "pod crashing" matches "container restart"
- "memory issues" matches "OOMKilled"
- "performance problems" matches "high CPU usage"

---

## Memory Persistence Across Sessions

### What Survives a Restart

**Persisted:**
- All memories in Bedrock Memory service
- Memory ID (in `.memory_id` file)
- Memory strategies configuration

**Not persisted:**
- In-memory caches
- Current session state
- Active LLM conversations

### How Memories Are Loaded on Restart

**Step 1: Find existing memory**
```python
existing_memory = self._find_existing_memory()
if existing_memory:
    self.memory_id = existing_memory["id"]
```

**Step 2: Verify strategies exist**
```python
existing_strategies = existing_memory.get("strategies", [])
if len(existing_strategies) >= 3:
    # Memory is fully configured
    return
```

**Step 3: Add missing strategies if needed**
```python
if "user_preferences" not in existing_names:
    self.client.add_user_preference_strategy_and_wait(...)
```

### Cross-Session Memory Retrieval

**Scenario:** User asks about an issue they investigated yesterday.

**Query:** "What did we find about the API server yesterday?"

**Retrieval:**
```python
# Retrieve from all sessions (no session_id specified)
past_investigations = client.retrieve_memories(
    memory_type="investigations",
    actor_id="Alice",
    query="API server issues",
    session_id=None  # Cross-session search
)
```

**Result:** Memories from yesterday's session are retrieved and included in context.

---

## The 4 Memory Tools Agents Can Use

**File:** `sre_agent/memory/tools.py`

### Tool 1: save_preference

**Purpose:** Save user preferences

**Parameters:**
- `preference` (str): The preference to save
- `categories` (List[str]): Categories (escalation, notification, workflow, style)

**Example:**
```python
save_preference(
    preference="Escalate critical issues to alice@example.com after 15 minutes",
    categories=["escalation", "notification"]
)
```

### Tool 2: save_infrastructure

**Purpose:** Save infrastructure knowledge

**Parameters:**
- `service_name` (str): Name of the service
- `knowledge` (str): The knowledge to save
- `knowledge_type` (str): Type (dependency, pattern, config, baseline)

**Example:**
```python
save_infrastructure(
    service_name="api-server",
    knowledge="Normal memory usage is 400-500Mi, CPU usage is 200-300m",
    knowledge_type="baseline"
)
```

### Tool 3: save_investigation

**Purpose:** Save investigation findings

**Parameters:**
- `finding` (str): The finding to save
- `category` (str): Category (root_cause, recommendation, observation)

**Example:**
```python
save_investigation(
    finding="Pod memory limit (512Mi) is too low for current workload",
    category="root_cause"
)
```

### Tool 4: retrieve_memory

**Purpose:** Retrieve memories by query

**Parameters:**
- `memory_type` (str): Type (preferences, infrastructure, investigations)
- `query` (str): Search query
- `actor_id` (str): Actor ID (user or agent)
- `max_results` (int): Maximum results to return
- `session_id` (Optional[str]): Session ID (None for cross-session)

**Example:**
```python
retrieve_memory(
    memory_type="infrastructure",
    query="api-server memory baseline",
    actor_id="kubernetes-agent",
    max_results=10,
    session_id=None  # Search all sessions
)
```

---

## Summary: Memory System Architecture

**3 Strategies:**
1. User Preferences (user-scoped, session-independent)
2. Infrastructure Knowledge (agent-scoped, session-aware)
3. Investigation Summaries (user-scoped, session-aware)

**2 Operations:**
1. Write: `create_event()` with actor_id and session_id
2. Read: `retrieve_memories()` with namespace and semantic query

**3 Hooks:**
1. on_investigation_start (retrieve context)
2. on_investigation_complete (save results)
3. on_agent_response (capture knowledge)

**Key Benefits:**
- Persistent learning across sessions
- Personalized responses based on user preferences
- Context-aware planning using past investigations
- Agent-specific knowledge accumulation
