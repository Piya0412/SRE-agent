# LangGraph Internals — Graph Structure and Routing

## What is LangGraph and Why Use It?

**LangGraph** is a library for building stateful, multi-actor applications with LLMs. It's built on top of LangChain and provides explicit control flow through directed graphs.

**Think of it as:** A state machine for AI agents, where each node is an agent or decision point, and edges define how control flows between them.

**Why not raw Bedrock Agents?**
- Bedrock Agents are black-box orchestration
- No visibility into routing decisions
- Limited control over agent collaboration
- Harder to debug and test

**Why not just LangChain?**
- LangChain is great for single-agent flows
- Multi-agent coordination requires explicit state management
- LangGraph provides graph-based orchestration out of the box

---

## Nodes vs Edges in This System

### Nodes: The 7 Components

**File:** `sre_agent/graph_builder.py`

```python
workflow = StateGraph(AgentState)

# Add nodes
workflow.add_node("prepare", _prepare_initial_state)
workflow.add_node("supervisor", supervisor.route)
workflow.add_node("kubernetes_agent", kubernetes_agent)
workflow.add_node("logs_agent", logs_agent)
workflow.add_node("metrics_agent", metrics_agent)
workflow.add_node("runbooks_agent", runbooks_agent)
workflow.add_node("aggregate", supervisor.aggregate_responses)
```

**Node types:**

1. **prepare** (Function node)
   - Type: Async function
   - Purpose: Initialize state with current query
   - Input: `AgentState` with messages
   - Output: Updated state with `current_query`, `agent_results`, etc.

2. **supervisor** (Method node)
   - Type: `SupervisorAgent.route()` method
   - Purpose: Decide which agent to invoke next
   - Input: Current state
   - Output: `{"next": agent_name, "metadata": {...}}`

3. **kubernetes_agent** (ReAct agent node)
   - Type: LangChain ReAct agent
   - Purpose: Handle Kubernetes-related queries
   - Input: State with current query and context
   - Output: `{"agent_results": {"kubernetes_agent": result}}`

4. **logs_agent** (ReAct agent node)
   - Type: LangChain ReAct agent
   - Purpose: Handle log analysis queries
   - Input: State with current query and context
   - Output: `{"agent_results": {"logs_agent": result}}`

5. **metrics_agent** (ReAct agent node)
   - Type: LangChain ReAct agent
   - Purpose: Handle performance metrics queries
   - Input: State with current query and context
   - Output: `{"agent_results": {"metrics_agent": result}}`

6. **runbooks_agent** (ReAct agent node)
   - Type: LangChain ReAct agent
   - Purpose: Handle operational procedures queries
   - Input: State with current query and context
   - Output: `{"agent_results": {"runbooks_agent": result}}`

7. **aggregate** (Method node)
   - Type: `SupervisorAgent.aggregate_responses()` method
   - Purpose: Combine all agent results into final response
   - Input: State with all `agent_results`
   - Output: `{"final_response": formatted_response}`

### Edges: The Connections

**Static edges** (always follow this path):
```python
workflow.add_edge("prepare", "supervisor")
workflow.add_edge("kubernetes_agent", "supervisor")
workflow.add_edge("logs_agent", "supervisor")
workflow.add_edge("metrics_agent", "supervisor")
workflow.add_edge("runbooks_agent", "supervisor")
workflow.add_edge("aggregate", END)
```

**Conditional edges** (routing logic):
```python
workflow.add_conditional_edges(
    "supervisor",
    _route_supervisor,
    {
        "kubernetes_agent": "kubernetes_agent",
        "logs_agent": "logs_agent",
        "metrics_agent": "metrics_agent",
        "runbooks_agent": "runbooks_agent",
        "aggregate": "aggregate"
    }
)
```

**Routing function:**
```python
def _route_supervisor(state: AgentState) -> str:
    next_agent = state.get("next", "FINISH")
    
    if next_agent == "FINISH":
        return "aggregate"
    
    # Map to actual node names
    agent_map = {
        "kubernetes": "kubernetes_agent",
        "logs": "logs_agent",
        "metrics": "metrics_agent",
        "runbooks": "runbooks_agent"
    }
    
    return agent_map.get(next_agent, "aggregate")
```

---

## How graph_builder.py Constructs the Graph

### Step 1: Create Supervisor

**File:** `sre_agent/graph_builder.py`

```python
supervisor = SupervisorAgent(
    llm_provider=llm_provider,
    force_delete_memory=force_delete_memory,
    **llm_kwargs
)
```

**What this does:**
- Creates LLM instance (Bedrock or Anthropic)
- Initializes memory client (if enabled)
- Loads system prompts from `config/prompts/`
- Creates memory tools for planning

### Step 2: Create Agent Nodes

**Example:** Kubernetes Agent

```python
kubernetes_agent = create_kubernetes_agent(
    tools,
    agent_metadata=SREConstants.agents.agents["kubernetes"],
    llm_provider=llm_provider,
    **llm_kwargs
)
```

**File:** `sre_agent/agent_nodes.py`

```python
def create_kubernetes_agent(
    tools: List[BaseTool],
    agent_metadata: AgentMetadata,
    llm_provider: str = "bedrock",
    **llm_kwargs
) -> Runnable:
    # Filter tools for this agent
    filtered_tools = [
        tool for tool in tools
        if tool.name.startswith("k8s-api___") or
           tool.name in ["get_current_time", "retrieve_memory"]
    ]
    
    # Load system prompt
    system_prompt = prompt_loader.load_agent_prompt(
        agent_type="kubernetes",
        actor_id=agent_metadata.actor_id,
        display_name=agent_metadata.display_name
    )
    
    # Create ReAct agent
    agent = create_react_agent(
        llm,
        tools=filtered_tools,
        state_modifier=system_prompt
    )
    
    return agent
```

**Agent metadata from constants:**
```python
SREConstants.agents.agents["kubernetes"] = AgentMetadata(
    actor_id="kubernetes-agent",
    display_name="Kubernetes Infrastructure Agent",
    description="Manages Kubernetes cluster operations and monitoring",
    agent_type="kubernetes"
)
```

### Step 3: Add Nodes to Graph

```python
workflow.add_node("prepare", _prepare_initial_state)
workflow.add_node("supervisor", supervisor.route)
workflow.add_node("kubernetes_agent", kubernetes_agent)
# ... other agents
workflow.add_node("aggregate", supervisor.aggregate_responses)
```

### Step 4: Define Edges

**Static edges:**
```python
workflow.set_entry_point("prepare")
workflow.add_edge("prepare", "supervisor")
workflow.add_edge("kubernetes_agent", "supervisor")
# ... other agents back to supervisor
workflow.add_edge("aggregate", END)
```

**Conditional edges:**
```python
workflow.add_conditional_edges(
    "supervisor",
    _route_supervisor,
    {
        "kubernetes_agent": "kubernetes_agent",
        "logs_agent": "logs_agent",
        "metrics_agent": "metrics_agent",
        "runbooks_agent": "runbooks_agent",
        "aggregate": "aggregate"
    }
)
```

### Step 5: Compile Graph

```python
compiled_graph = workflow.compile()
```

**What compilation does:**
- Validates graph structure (no orphaned nodes, cycles are intentional)
- Creates execution engine
- Sets up state management
- Prepares for streaming execution

---

## The Supervisor's Routing Logic

### First Call: Create Investigation Plan

**File:** `sre_agent/supervisor.py`

**Method:** `SupervisorAgent.route(state: AgentState)`

```python
async def route(self, state: AgentState) -> Dict[str, Any]:
    agents_invoked = state.get("agents_invoked", [])
    existing_plan = state.get("metadata", {}).get("investigation_plan")
    
    if not existing_plan:
        # First time - create investigation plan
        plan = await self.create_investigation_plan(state)
        
        if not plan.auto_execute and not state.get("auto_approve_plan", False):
            # Complex plan - present to user for approval
            return {
                "next": "FINISH",
                "metadata": {
                    "investigation_plan": plan.model_dump(),
                    "plan_pending_approval": True
                }
            }
        else:
            # Simple plan - start execution
            next_agent = plan.agents_sequence[0]
            return {
                "next": next_agent,
                "metadata": {
                    "investigation_plan": plan.model_dump(),
                    "plan_step": 0
                }
            }
```

**Investigation plan structure:**
```python
class InvestigationPlan(BaseModel):
    steps: List[str]  # ["Check pod status", "Analyze logs", "Review metrics"]
    agents_sequence: List[str]  # ["kubernetes_agent", "logs_agent", "metrics_agent"]
    complexity: Literal["simple", "complex"]
    auto_execute: bool
    reasoning: str
```

### Subsequent Calls: Follow the Plan

```python
else:
    # Continue executing existing plan
    plan = InvestigationPlan(**existing_plan)
    current_step = state.get("metadata", {}).get("plan_step", 0)
    next_step = current_step + 1
    
    if next_step >= len(plan.agents_sequence):
        # Plan complete
        return {
            "next": "FINISH",
            "metadata": {
                "routing_reasoning": "Investigation plan completed"
            }
        }
    else:
        # Continue with next agent in plan
        next_agent = plan.agents_sequence[next_step]
        return {
            "next": next_agent,
            "metadata": {
                "plan_step": next_step
            }
        }
```

---

## What "Structured Output" Means in the Planning Step

**Traditional LLM output:**
```
I think we should first check the Kubernetes pod status, then look at the logs, 
and finally review the metrics. This will give us a complete picture.
```

**Problem:** Hard to parse, inconsistent format, requires regex or prompt engineering.

**Structured output:**
```json
{
  "steps": [
    "Check Kubernetes pod status",
    "Analyze application logs",
    "Review performance metrics"
  ],
  "agents_sequence": ["kubernetes_agent", "logs_agent", "metrics_agent"],
  "complexity": "simple",
  "auto_execute": true,
  "reasoning": "Standard investigation flow for pod issues"
}
```

**How it's implemented:**

**File:** `sre_agent/supervisor.py`

```python
structured_llm = self.llm.with_structured_output(InvestigationPlan)
plan = await structured_llm.ainvoke([
    SystemMessage(content=planning_prompt),
    HumanMessage(content=current_query)
])
```

**What `with_structured_output()` does:**
- Adds JSON schema to LLM prompt
- Instructs LLM to output valid JSON matching the schema
- Parses response and validates against Pydantic model
- Raises error if output doesn't match schema

**Benefits:**
- Type-safe: Guaranteed to have all required fields
- Validated: Pydantic checks types and constraints
- Parseable: No regex or string manipulation needed
- Reliable: Fails fast if LLM output is malformed

---

## Sequential vs Parallel Agent Execution

### Current Implementation: Sequential

**Execution flow:**
```
supervisor → kubernetes_agent → supervisor → logs_agent → supervisor → metrics_agent → supervisor → aggregate
```

**Code:**
```python
# In supervisor.route()
next_agent = plan.agents_sequence[next_step]
return {"next": next_agent}  # Only one agent at a time
```

**Timing:**
- Kubernetes agent: 5-10 seconds
- Logs agent: 5-10 seconds
- Metrics agent: 5-10 seconds
- **Total: 15-30 seconds**

### Potential Parallel Implementation

**Execution flow:**
```
supervisor → [kubernetes_agent, logs_agent, metrics_agent] (parallel) → supervisor → aggregate
```

**Code (hypothetical):**
```python
# In supervisor.route()
next_agents = plan.agents_sequence[next_step:next_step+3]
return {"next": next_agents}  # Multiple agents

# In graph_builder.py
workflow.add_conditional_edges(
    "supervisor",
    _route_supervisor_parallel,
    {
        "parallel_execution": ["kubernetes_agent", "logs_agent", "metrics_agent"],
        "aggregate": "aggregate"
    }
)
```

**Timing:**
- All agents execute simultaneously: max(5-10, 5-10, 5-10) = 5-10 seconds
- **Total: 5-10 seconds (2-3x faster)**

**Why not implemented:**
- Agents may need results from previous agents
- Sequential execution is easier to debug
- Memory context is clearer with sequential flow
- Demo prioritizes clarity over performance

---

## How State Flows Through the Graph

### AgentState Structure

**File:** `sre_agent/agent_state.py`

```python
class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], add_messages]
    next: str
    agent_results: Dict[str, Any]
    current_query: str
    metadata: Dict[str, Any]
    requires_collaboration: bool
    agents_invoked: List[str]
    final_response: Optional[str]
    auto_approve_plan: bool
    session_id: str
    user_id: str
    actor_id: Optional[str]
    incident_id: Optional[str]
    memory_context: Optional[Dict[str, Any]]
```

**Key fields:**

**messages:**
- Type: List of LangChain messages (HumanMessage, AIMessage, SystemMessage)
- Purpose: Conversation history
- Updated by: Each agent adds its messages

**next:**
- Type: String
- Purpose: Which node to execute next
- Values: `"kubernetes_agent"`, `"logs_agent"`, `"FINISH"`, etc.
- Updated by: Supervisor's routing logic

**agent_results:**
- Type: Dict mapping agent name to result
- Purpose: Store outputs from each agent
- Example: `{"kubernetes_agent": "Pod is running", "logs_agent": "No errors found"}`
- Updated by: Each agent adds its result

**current_query:**
- Type: String
- Purpose: The user's original question
- Example: `"Why is the API server pod restarting?"`
- Updated by: Prepare node (extracted from messages)

**metadata:**
- Type: Dict
- Purpose: Store investigation plan, routing reasoning, etc.
- Example: `{"investigation_plan": {...}, "plan_step": 1}`
- Updated by: Supervisor and agents

**agents_invoked:**
- Type: List of strings
- Purpose: Track which agents have been called
- Example: `["kubernetes_agent", "logs_agent"]`
- Updated by: Each agent appends its name

**memory_context:**
- Type: Dict
- Purpose: Store retrieved memories (preferences, infrastructure, investigations)
- Example: `{"user_preferences": [...], "infrastructure_by_agent": {...}}`
- Updated by: Supervisor during planning

### State Updates at Each Node

**1. prepare node:**
```python
{
    "current_query": "Why is the API server pod restarting?",
    "agent_results": {},
    "agents_invoked": [],
    "metadata": {}
}
```

**2. supervisor node (first call):**
```python
{
    "next": "kubernetes_agent",
    "metadata": {
        "investigation_plan": {
            "steps": ["Check pod status", "Analyze logs"],
            "agents_sequence": ["kubernetes_agent", "logs_agent"],
            ...
        },
        "plan_step": 0
    },
    "memory_context": {
        "user_preferences": [...],
        "infrastructure_by_agent": {...}
    }
}
```

**3. kubernetes_agent node:**
```python
{
    "agent_results": {
        "kubernetes_agent": "Pod api-server is in CrashLoopBackOff state. Last restart: 2 minutes ago. Exit code: 137 (OOMKilled)."
    },
    "agents_invoked": ["kubernetes_agent"]
}
```

**4. supervisor node (second call):**
```python
{
    "next": "logs_agent",
    "metadata": {
        "plan_step": 1,
        "routing_reasoning": "Executing plan step 2: Analyze logs"
    }
}
```

**5. logs_agent node:**
```python
{
    "agent_results": {
        "kubernetes_agent": "...",
        "logs_agent": "Found error: 'java.lang.OutOfMemoryError: Java heap space' at 14:32:15"
    },
    "agents_invoked": ["kubernetes_agent", "logs_agent"]
}
```

**6. supervisor node (third call):**
```python
{
    "next": "FINISH",
    "metadata": {
        "routing_reasoning": "Investigation plan completed"
    }
}
```

**7. aggregate node:**
```python
{
    "final_response": "## Investigation Results\n\n**Root Cause:** The API server pod is experiencing out-of-memory errors...\n\n**Recommendations:**\n1. Increase memory limit to 2Gi\n2. Review heap size configuration..."
}
```

---

## The ReAct Pattern Each Specialist Agent Uses

**ReAct = Reason + Act + Observe**

### What is ReAct?

A prompting pattern where the agent:
1. **Reasons** about what to do next
2. **Acts** by calling a tool
3. **Observes** the result
4. Repeats until task is complete

### Example: Kubernetes Agent Investigating Pod Restarts

**Iteration 1:**

**Reason:**
```
I need to check the status of the API server pod to understand why it's restarting.
I'll use the get_pod_status tool to get detailed information.
```

**Act:**
```python
k8s_api___get_pod_status(namespace="default", pod_name="api-server")
```

**Observe:**
```json
{
  "status": "CrashLoopBackOff",
  "restarts": 5,
  "last_restart": "2 minutes ago",
  "exit_code": 137,
  "reason": "OOMKilled"
}
```

**Iteration 2:**

**Reason:**
```
The pod is being killed due to out-of-memory (exit code 137). I should check the 
resource limits to see if they're too low.
```

**Act:**
```python
k8s_api___get_resource_usage(namespace="default", pod_name="api-server")
```

**Observe:**
```json
{
  "memory_limit": "512Mi",
  "memory_usage": "510Mi",
  "cpu_limit": "500m",
  "cpu_usage": "450m"
}
```

**Iteration 3:**

**Reason:**
```
The pod is using 510Mi out of 512Mi memory limit, which explains the OOMKilled status.
I have enough information to provide a diagnosis. I'll formulate my response.
```

**Act:**
```
FINISH
```

**Final Response:**
```
The API server pod is restarting due to out-of-memory errors. The pod has a memory 
limit of 512Mi and is consistently hitting this limit (510Mi usage), causing the 
kernel to kill the process (exit code 137 - OOMKilled).

Recommendation: Increase the memory limit to at least 1Gi to provide adequate headroom.
```

### How ReAct is Implemented

**File:** `sre_agent/agent_nodes.py`

```python
from langgraph.prebuilt import create_react_agent

agent = create_react_agent(
    llm,
    tools=filtered_tools,
    state_modifier=system_prompt
)
```

**What `create_react_agent()` does:**
1. Creates a prompt template with ReAct structure
2. Adds tool descriptions to prompt
3. Implements the Reason-Act-Observe loop
4. Handles tool calling and result parsing
5. Manages conversation history

**System prompt structure:**
```
You are the Kubernetes Infrastructure Agent.

Your role: Manage Kubernetes cluster operations and monitoring.

Available tools:
- k8s_api___get_pod_status: Get the status of a specific pod
- k8s_api___list_pods: List all pods in a namespace
- k8s_api___get_resource_usage: Get resource usage for a pod
- get_current_time: Get current timestamp
- retrieve_memory: Retrieve information from long-term memory

Instructions:
1. Analyze the user's query
2. Reason about what information you need
3. Use tools to gather information
4. Synthesize findings into a clear response

Current investigation step: Check pod status and identify restart cause
```

---

## When the Graph Terminates

### Termination Conditions

**1. Supervisor routes to FINISH:**
```python
return {"next": "FINISH"}
```

**2. Aggregate node completes:**
```python
workflow.add_edge("aggregate", END)
```

**3. Graph recursion limit reached:**
```python
# Default: 25 iterations
# Configurable in graph compilation
compiled_graph = workflow.compile(recursion_limit=50)
```

**4. Error occurs:**
```python
try:
    async for event in graph.astream(initial_state):
        ...
except GraphRecursionError:
    logger.error("Graph exceeded recursion limit")
except Exception as e:
    logger.error(f"Graph execution failed: {e}")
```

### What Signals End of Investigation

**From supervisor's perspective:**

```python
# In supervisor.route()
if next_step >= len(plan.agents_sequence):
    # All agents in plan have been invoked
    return {"next": "FINISH"}
```

**From graph's perspective:**

```python
# In _route_supervisor()
if next_agent == "FINISH":
    return "aggregate"  # Route to final aggregation

# In graph_builder.py
workflow.add_edge("aggregate", END)  # Aggregate always ends
```

**Execution flow:**
```
supervisor (returns "FINISH") 
  → _route_supervisor (returns "aggregate") 
  → aggregate node (produces final_response) 
  → END
```

---

## Why LangGraph Over Alternatives

### vs. Raw Bedrock Agents

**Bedrock Agents:**
- Black-box orchestration
- Limited visibility into decisions
- Hard to debug
- Opaque state management

**LangGraph:**
- Explicit graph structure
- Full visibility into routing
- Easy to debug (can inspect state at each node)
- Transparent state management

### vs. LangChain Alone

**LangChain:**
- Great for single-agent flows
- Sequential execution by default
- State management is manual

**LangGraph:**
- Built for multi-agent coordination
- Graph-based routing
- Built-in state management
- Streaming execution

### vs. Custom Orchestration

**Custom code:**
```python
def orchestrate(query):
    k8s_result = kubernetes_agent(query)
    logs_result = logs_agent(query, k8s_result)
    metrics_result = metrics_agent(query)
    return aggregate(k8s_result, logs_result, metrics_result)
```

**Problems:**
- Hard-coded flow
- No dynamic routing
- Difficult to add new agents
- State management is manual

**LangGraph:**
- Dynamic routing based on query
- Easy to add new agents (just add node and edges)
- State management is automatic
- Supports complex flows (loops, conditionals, parallel execution)

### Key Advantages

**1. Explicit Control Flow**
- You define exactly how agents interact
- No hidden orchestration logic
- Easy to understand and modify

**2. Debuggability**
- Can inspect state at each node
- Can log routing decisions
- Can replay executions

**3. State Management**
- Automatic state passing between nodes
- Type-safe state with TypedDict
- State updates are explicit

**4. Flexibility**
- Easy to add new agents
- Easy to change routing logic
- Supports complex patterns (loops, conditionals, parallel)

**5. Streaming**
- Can stream results as they're produced
- User sees progress in real-time
- Better UX for long-running investigations

---

## Summary: LangGraph Architecture

**Graph structure:**
```
prepare → supervisor → [agents] → supervisor → aggregate → END
                ↑          ↓
                └──────────┘
                  (loop)
```

**Key components:**
- 7 nodes (prepare, supervisor, 4 agents, aggregate)
- Static edges (always follow)
- Conditional edges (routing logic)
- State (AgentState TypedDict)

**Execution model:**
- Sequential agent invocation
- ReAct pattern for each agent
- Supervisor-driven routing
- Memory-informed planning

**Why it works:**
- Explicit control flow
- Type-safe state management
- Easy to debug and extend
- Supports complex multi-agent patterns
