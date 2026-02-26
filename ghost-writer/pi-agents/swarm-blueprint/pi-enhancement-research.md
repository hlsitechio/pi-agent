# Pi Agent Enhancement Research
> Research Date: 2026-02-23
> Target: Pi-Mono AI Agent Toolkit (badlogic/pi-mono)
> Purpose: Identify features and enhancements for Pi Agent Swarm (32+ specialized agents)

## Executive Summary

Pi-mono is a comprehensive AI agent toolkit with robust extension APIs, RPC mode, SDK embedding, and sophisticated event systems. The architecture supports our swarm vision but requires custom orchestration—Pi intentionally avoids built-in swarm features, preferring agents spawn themselves via bash when needed.

**Key Opportunity**: Pi's extension API + RPC mode + event system = perfect foundation for external orchestration layer.

---

## 1. Extension API Features (Under-Leveraged)

### What We Found

**Comprehensive Event System** (20+ lifecycle hooks):
- **Session lifecycle**: `session_start`, `session_before_switch`, `session_switch`, `session_before_fork`, `session_fork`, `session_before_compact`, `session_compact`, `session_before_tree`, `session_tree`, `session_shutdown`
- **Agent execution**: `before_agent_start`, `agent_start`, `agent_end`, `turn_start`, `turn_end`
- **Message streaming**: `message_start`, `message_update`, `message_end`
- **Tool execution**: `tool_execution_start`, `tool_execution_update`, `tool_execution_end`, `tool_call`, `tool_result`
- **User interaction**: `input`, `user_bash`, `model_select`, `context`

**Recent Additions (v0.52.10-v0.54.2)**:
- Extension event forwarding for message and tool execution lifecycles
- `terminal_input` event for raw input interception (2026 update)
- `ctx.reload()` for runtime resets and hot-reloading
- `pi.getAllTools()` exposes tool parameters (names, types, descriptions)
- Scoped storage abstraction with locked read/merge/write for settings

### Actionable for Swarm

1. **Inter-Agent Communication via Events**
   - Extensions can listen to ALL agent events
   - Create "swarm-coordinator" extension that monitors `tool_execution_*` events
   - Track which agents are active, what they're doing, coordinate work
   - Use `session_before_fork` to spawn specialized agents

2. **Context Injection**
   - `context` event rewrites messages before LLM sees them
   - `before_agent_start` injects context/modifies prompts
   - Each agent extension can inject role-specific context
   - Swarm coordinator injects global state awareness

3. **Tool Interception**
   - `tool_call` event can block/modify tool invocations
   - Create safety rails for swarm operations
   - Route tool calls to specialized agents
   - Example: Security agent intercepts bash tools, validates commands

4. **Message Streaming**
   - `message_update` provides real-time streaming deltas
   - Build cross-agent progress dashboard
   - Aggregate outputs from multiple agents
   - Stream to external monitoring systems

---

## 2. RPC Mode for Programmatic Control

### Full Protocol Support

**Control Methods**:
- **Prompting**: `prompt`, `steer`, `follow_up`, `abort`
- **State**: `get_state`, `get_messages`
- **Model**: `set_model`, `cycle_model`, `get_available_models`
- **Thinking**: `set_thinking_level`, `cycle_thinking_level`
- **Queue**: `set_steering_mode`, `set_follow_up_mode`
- **Compaction**: `compact`, `set_auto_compaction`
- **Retry**: `set_auto_retry`, `abort_retry`
- **Bash**: `bash`, `abort_bash`
- **Session**: `get_session_stats`, `export_html`, `switch_session`, `fork`, `get_fork_messages`, `set_session_name`

**Event Streaming**:
All agent events stream to stdout as JSON lines, enabling real-time monitoring from external orchestrators.

**Extension UI Protocol**:
Extensions can request UI interactions via stdout, client responds via stdin:
- `select`, `confirm`, `input`, `editor`, `notify`, `setStatus`, `setWidget`, `setTitle`, `set_editor_text`

### Actionable for Swarm

1. **External Orchestrator**
   ```bash
   # Spawn 32 agents in RPC mode
   for i in {1..32}; do
     pi --mode rpc --no-session > agent-$i.log 2>&1 &
   done
   ```
   - Orchestrator sends JSON commands via stdin
   - Receives events on stdout
   - Full programmatic control over entire swarm

2. **Work Distribution**
   - Orchestrator receives task
   - Routes to appropriate agent via `prompt` command
   - Monitors via event stream
   - Aggregates results via `get_messages`

3. **Dynamic Model Assignment**
   - Use `set_model` to assign different models per agent
   - Fast agents: DeepSeek, Qwen
   - Reasoning agents: Gemini 2.0 Flash Thinking
   - Security agents: Claude Sonnet
   - Router agent: GPT-4.1

4. **Session Management**
   - `fork` creates branching sessions for parallel work
   - `switch_session` moves between agent contexts
   - `get_session_stats` tracks resource usage per agent

---

## 3. Extension Inter-Communication

### Current State

Pi does NOT have built-in extension-to-extension messaging. Communication happens through:

**Shared Event System**:
- All extensions listen to same event bus
- Can coordinate via event patterns
- Example: Agent A emits `tool_execution_end`, Agent B listens and acts

**Session Persistence**:
- `pi.appendEntry(customType, data)` stores state
- Other extensions can read session entries
- Survives session restarts
- Custom renderers can display cross-agent data

**Tool Registration**:
- Extensions can override built-in tools
- Create "proxy tools" that route to other agents
- Example: `security_scan` tool routes to security agent

**UI Coordination**:
- Multiple extensions manage widgets/status
- `ctx.ui.setWidget()`, `ctx.ui.setStatus()`
- Shared status bar for swarm coordination

### Actionable for Swarm

1. **Event-Based Coordination**
   ```typescript
   // Security agent listens for bash calls
   pi.on("tool_call", async (event, ctx) => {
     if (event.tool === "bash") {
       const safe = await validateCommand(event.params);
       if (!safe) event.block(); // Prevent execution
     }
   });
   ```

2. **Shared State via Session**
   ```typescript
   // Coordinator writes swarm state
   pi.appendEntry("swarm_state", {
     active_agents: 32,
     tasks_completed: 150,
     current_phase: "enumeration"
   });

   // Other extensions read it
   const entries = ctx.sessionManager.getCurrentSession().entries;
   const swarmState = entries.filter(e => e.type === "swarm_state").pop();
   ```

3. **Tool Routing Pattern**
   ```typescript
   pi.registerTool({
     name: "security_scan",
     execute: async (id, params, signal, update, ctx) => {
       // Route to security agent subprocess
       const result = await callAgent("security", params);
       return result;
     }
   });
   ```

---

## 4. Built-in vs Custom Tools

### Built-in Tools (Default 4)

1. **read**: File reading with line ranges
2. **write**: File writing
3. **edit**: In-place text replacement
4. **bash**: Shell command execution

**Extensions can**:
- Override these defaults
- Add new tools via `pi.registerTool()`
- Control which tools are active via `pi.setActiveTools()`
- Tool state persists across sessions

### Custom Tool Registration

```typescript
pi.registerTool({
  name: "greet",
  label: "Greeting",
  description: "Generate a greeting",
  parameters: Type.Object({
    name: Type.String({ description: "Name to greet" }),
  }),
  async execute(toolCallId, params, signal, onUpdate, ctx) {
    return {
      content: [{ type: "text", text: `Hello, ${params.name}!` }],
      details: {},
    };
  },
});
```

**Features**:
- TypeBox schema validation
- Async execution with signal handling
- Progress updates via `onUpdate` callback
- Full context access (cwd, session, model, etc.)
- Tools can execute remotely or locally
- Output truncation handled automatically

### Actionable for Swarm

1. **Agent-Specific Tool Suites**
   - Security agent: `nuclei_scan`, `nmap_scan`, `shodan_lookup`
   - Intel agent: `whois_lookup`, `dns_enum`, `subdomain_scan`
   - HTTP agent: `http_probe`, `screenshot`, `spider`
   - Each agent loads only its tools

2. **Tool Coordination**
   - Create "meta-tools" that coordinate multiple agents
   - Example: `full_recon` tool spawns 5 agents, aggregates results

3. **Dynamic Tool Loading**
   ```typescript
   // Load tools based on target type
   if (targetType === "web") {
     pi.setActiveTools(["read", "bash", "http_probe", "screenshot"]);
   } else if (targetType === "network") {
     pi.setActiveTools(["read", "bash", "nmap_scan", "dns_enum"]);
   }
   ```

---

## 5. Model Switching Mid-Conversation

### Full Support

**Methods**:
- `/model` command in interactive mode
- `Ctrl+L` keyboard shortcut
- `set_model` RPC command: `{"type": "set_model", "provider": "anthropic", "modelId": "claude-sonnet-4-20250514"}`
- `cycle_model` RPC command: Advance to next model
- `ctx.modelRegistry` API in extensions

**Model Selection**:
- Per-provider model lists (tool-capable models)
- `/scoped-models` enables/disables models for cycling
- Supports 10+ providers: Anthropic, OpenAI, Azure, Google, Mistral, Groq, xAI, etc.
- Subscription services: Claude Pro/Max, ChatGPT Plus, GitHub Copilot, Gemini

**Thinking Levels**:
- `set_thinking_level`: off, minimal, low, medium, high, xhigh
- `xhigh` limited to OpenAI codex-max models
- Per-agent thinking configuration

### Actionable for Swarm

1. **Role-Based Model Assignment**
   ```json
   {
     "router": "gpt-4.1",
     "security": "claude-sonnet-4",
     "intel": "deepseek-chat",
     "http": "qwen-max",
     "recon": "gemini-2.0-flash-thinking-exp"
   }
   ```
   - Fast/cheap models for simple agents
   - Reasoning models for complex analysis
   - Specialized models for specific domains

2. **Dynamic Model Switching**
   - Agent starts with fast model
   - Detects complex task
   - Switches to reasoning model mid-conversation
   - Returns to fast model after

3. **Cost Optimization**
   - Track cost per agent via `get_session_stats`
   - Downgrade models for repetitive tasks
   - Upgrade only when necessary

---

## 6. Recent Features (v0.52.x - v0.54.2)

### Notable Additions (2026)

**Skill Auto-Discovery (v0.54.0)**:
- Automatic discovery from `.agents/skills/` directories
- Project-local + global skills
- CWD and ancestor path scanning

**Runtime Reload (v0.52.9)**:
- `ctx.reload()` triggers full runtime reset
- Hot-reload configurations
- Agent restarts without process restart

**Editor Enhancements (v0.52.8)**:
- Emacs-style kill ring (ctrl+k/ctrl+y/alt+y)
- Undo support (ctrl+z)
- `pasteToEditor()` for programmatic content insertion

**Extension Event Forwarding (v0.52.10)**:
- Message and tool execution lifecycle events
- `message_start`, `message_end`, `tool_execution_start`, etc.

**Tool Parameter Exposure (v0.52.9)**:
- `pi.getAllTools()` returns detailed parameters
- Enables richer extension integrations

**Settings Management (v0.53.0)**:
- Scoped storage abstraction
- Locked read/merge/write persistence
- Global and project settings

**Terminal Input Interception (2026)**:
- `terminal_input` event for raw input interception
- Extensions can consume/transform input before TUI

### Actionable for Swarm

1. **Hot-Reload Swarm Config**
   - Change agent assignments
   - Call `ctx.reload()` across all agents
   - No process restart needed

2. **Programmatic Editor Control**
   - Insert findings into agent sessions
   - Build collaborative editing workflows

3. **Skill Discovery**
   - Each agent has `.agents/skills/` directory
   - Skills auto-load based on agent role
   - Share skills via project directory

---

## 7. Streaming Response Support

### Full Streaming

**Message Streaming**:
- `message_start`, `message_update`, `message_end` events
- Real-time token deltas via `message_update`
- Incremental rendering in TUI
- JSON streaming in RPC mode

**Tool Streaming**:
- `tool_execution_start`, `tool_execution_update`, `tool_execution_end`
- Progress updates via `onUpdate` callback in tool execution
- Incremental syntax highlighting for write tools

**Transport Options**:
- SSE (Server-Sent Events)
- WebSocket
- Auto-selection via `/settings` command

### Actionable for Swarm

1. **Real-Time Swarm Dashboard**
   - Subscribe to `message_update` from all 32 agents
   - Aggregate streaming output
   - Display in unified TUI
   - Example: 32-panel tmux layout, each agent streaming

2. **Progress Tracking**
   - Monitor `tool_execution_update` events
   - Show % completion for long-running scans
   - Cancel slow agents if needed

3. **Response Aggregation**
   - Stream findings as they arrive
   - Don't wait for all agents to finish
   - Present results incrementally

---

## 8. SDK for Building Custom Tools

### Extension API

**TypeScript-First**:
- Extensions are `.ts` files (jiti compiles on-the-fly)
- npm dependencies via `package.json`
- TypeBox for schema validation
- Full TypeScript types via `@mariozechner/pi-coding-agent`

**Tool Registration Pattern**:
```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "custom_tool",
    description: "What this tool does",
    parameters: Type.Object({
      param1: Type.String(),
      param2: Type.Number(),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      // Implementation
      onUpdate({ type: "text", text: "Progress..." });

      return {
        content: [{ type: "text", text: "Result" }],
        details: { metadata: "here" },
      };
    },
  });
}
```

**Extension Context (`ctx`)**:
- `ctx.ui`: User interaction (notify, confirm, input, select, custom TUI)
- `ctx.cwd`: Working directory
- `ctx.sessionManager`: Session API access
- `ctx.modelRegistry`, `ctx.model`: Model management
- `ctx.isIdle()`, `ctx.abort()`: Execution control
- `ctx.getContextUsage()`: Token tracking
- `ctx.compact()`: Force compaction
- `ctx.getSystemPrompt()`: System prompt access

### Actionable for Swarm

1. **Swarm-Specific Tools**
   ```typescript
   pi.registerTool({
     name: "distribute_task",
     description: "Distribute task to swarm agents",
     parameters: Type.Object({
       task: Type.String(),
       agent_count: Type.Number(),
       priority: Type.Enum({ high: 1, medium: 2, low: 3 }),
     }),
     async execute(id, params, signal, update, ctx) {
       // Spawn agents, distribute work, aggregate results
     },
   });
   ```

2. **Security Tools Suite**
   ```typescript
   // nuclei_scan, nmap_scan, shodan_lookup, etc.
   // Each tool wraps external command
   // Returns structured results
   ```

3. **Custom Renderers**
   ```typescript
   pi.registerMessageRenderer("swarm_status", (entry, ctx) => {
     return {
       component: SwarmStatusWidget,
       keybindings: [{ key: "r", action: "refresh" }],
     };
   });
   ```

---

## 9. Example Extensions to Learn From

### Official Examples

**Location**: `packages/coding-agent/examples/extensions/`

**tools.ts**:
- Tool enable/disable management
- Interactive selector UI
- State persistence via `pi.appendEntry()`
- Listens to `session_start`, `session_tree`, `session_fork`

**Key Patterns**:
- SettingsList component for configuration
- `pi.setActiveTools()` for dynamic tool control
- Extension state survives session reloads

### Community Extensions (awesome-pi-agent)

**Security & Control**:
- Sensitive data redaction (API keys, tokens, passwords)
- Bash command blocking
- Permission systems (off/low/medium/high)
- Git approval workflows

**Monitoring & Analytics**:
- Cost tracking dashboards
- Tool call auditing (SQLite logging)
- API spending analysis

**Productivity**:
- Git checkpoint systems (conversation branching)
- LSP integration with auto-diagnostics
- SSH remote execution
- File browsers

**UI/UX**:
- Powerline status bars with git
- Desktop notifications (Telegram, OSC 777, audio)
- Interactive TUI components (calendars, document viewers)

**Skills**:
- Web search (Brave Search, Jina APIs)
- Browser automation (Chrome DevTools Protocol)
- Google Workspace (Calendar, Drive, Gmail)
- Speech-to-text transcription
- Video transcript fetching

### Actionable for Swarm

1. **Adopt Security Patterns**
   - Implement command approval for bash tools
   - Add redaction for sensitive data
   - Permission levels per agent

2. **Cost Tracking**
   - Track spending per agent
   - Identify expensive operations
   - Optimize model selection

3. **LSP Integration**
   - Add diagnostics to code-focused agents
   - Auto-fix common errors
   - Workspace-wide symbol search

---

## 10. Multi-Agent / Orchestration Features

### Pi's Philosophy

**Quote from docs**: "Pi ships with powerful defaults but skips features like sub agents and plan mode. Instead, if you need pi to spawn itself, just ask it to run itself via bash. You could even have it spawn itself inside a tmux session for full observability and the ability to interact with that sub-agent directly."

**Translation**: Pi intentionally does NOT have built-in orchestration. The approach is:
1. Agent spawns itself via bash: `pi --mode rpc`
2. Parent agent monitors subprocess
3. Communication via stdin/stdout JSON
4. Full observability via tmux/logs

### Oh-My-Pi (Community Fork)

**Advanced Multi-Agent Features**:
- **Subagent orchestration**: `agent://<id>` resources, isolated git worktrees
- **User-level and project-level agents**: Custom agent definitions
- **Concurrency-limited batch execution**: Progress tracking
- **Role-based routing**: default, smol, slow, plan, commit
- **Configurable discovery**: Auto-resolve role defaults
- **LSP integration**: 40+ languages, auto-discovery, workspace diagnostics

**Architecture**:
- Agent harness enhancements
- Tool execution management
- Context management
- MCP connectivity
- Subagent orchestration layer

### Actionable for Swarm

1. **Adopt Subprocess Pattern**
   ```bash
   # Coordinator spawns 32 agents
   for role in router security intel http recon discovery api mobile; do
     for i in {1..4}; do
       tmux new-window -n "$role-$i" "pi --mode rpc --session-dir ./sessions/$role-$i"
     done
   done
   ```

2. **Git Worktree Isolation**
   - Each agent gets isolated worktree
   - No file conflicts
   - Independent git operations
   - Coordinator merges results

3. **Role-Based Model Assignment**
   - Define roles in config
   - Each role has default model
   - Override per-task if needed

4. **Agent Resource Pattern**
   - Access subagent output via `agent://<id>`
   - Read logs, status, results
   - Build dependency graphs

5. **Consider Oh-My-Pi Fork**
   - Evaluate for production swarm
   - Already has orchestration layer
   - LSP integration valuable for code agents

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

**Goal**: Get basic swarm coordination working

1. **Create Swarm Coordinator Extension**
   - Listens to all agent events
   - Tracks active agents
   - Routes tasks to specialists
   - Aggregates results

2. **Implement RPC Orchestrator**
   - Spawn 32 agents in RPC mode
   - JSON protocol for commands
   - Event stream monitoring
   - Task distribution queue

3. **Define Agent Roles**
   - Router, Security, Intel, HTTP, Recon, Discovery, API, Mobile
   - 4 instances per role = 32 agents
   - Assign default models per role

4. **Build Agent Registry**
   - Track agent status (idle/busy/error)
   - Capability mapping
   - Load balancing

### Phase 2: Tools & Skills (Week 3-4)

**Goal**: Equip agents with specialized tools

1. **Security Agent Tools**
   - `nuclei_scan`, `nmap_scan`, `shodan_lookup`
   - Wrap d3bugr MCP tools
   - Return structured JSON

2. **Intel Agent Tools**
   - `whois_lookup`, `dns_enum`, `subdomain_scan`
   - `harvest` integration
   - Passive recon focus

3. **HTTP Agent Tools**
   - `http_probe`, `screenshot`, `spider`
   - `cdp_scan` integration
   - Technology detection

4. **Create Skill Library**
   - `.agents/skills/` directory per agent
   - Auto-discovery on startup
   - Share common skills

### Phase 3: Communication (Week 5-6)

**Goal**: Enable inter-agent communication

1. **Event-Based Coordination**
   - Agents publish findings via custom events
   - Coordinator listens and routes
   - Example: Security agent finds vuln → Router prioritizes

2. **Shared State via Session**
   - `swarm_state` entry type
   - All agents read/write
   - Coordinated via locks

3. **Tool Routing Pattern**
   - Meta-tools that spawn subagents
   - Example: `full_recon` → spawns 8 agents
   - Aggregate results

### Phase 4: Optimization (Week 7-8)

**Goal**: Make swarm efficient and cost-effective

1. **Dynamic Model Switching**
   - Start with fast/cheap models
   - Upgrade for complex tasks
   - Track cost per agent

2. **Load Balancing**
   - Distribute tasks evenly
   - Prioritize idle agents
   - Handle failures gracefully

3. **Result Streaming**
   - Real-time dashboard
   - 32-panel tmux layout
   - Aggregate findings as they arrive

4. **Monitoring & Metrics**
   - Cost tracking per agent
   - Tool usage statistics
   - Performance benchmarks

### Phase 5: Advanced Features (Week 9-10)

**Goal**: Build production-ready swarm

1. **Git Worktree Isolation**
   - Each agent gets isolated worktree
   - Independent operations
   - Coordinator merges

2. **Agent Resource Access**
   - `agent://<id>` URIs
   - Read subagent output
   - Build dependency graphs

3. **LSP Integration**
   - Code-focused agents get LSP
   - Auto-diagnostics
   - Workspace symbol search

4. **Hot-Reload Config**
   - Change agent assignments
   - `ctx.reload()` across swarm
   - No restart needed

---

## Critical Findings

### What Pi Does Well

1. **Extensibility**: TypeScript extensions with full API access
2. **RPC Mode**: Complete programmatic control via JSON protocol
3. **Event System**: 20+ lifecycle hooks for coordination
4. **Model Flexibility**: Switch models mid-conversation, per-agent
5. **Tool System**: Easy custom tool registration, dynamic loading
6. **SDK**: Embed in any application, full control
7. **Streaming**: Real-time updates for responsive UIs

### What Pi Lacks (Intentionally)

1. **Built-in Orchestration**: Must build external coordinator
2. **Native Multi-Agent**: Spawn via bash, not built-in
3. **Agent-to-Agent Messaging**: Must use events or session state
4. **Centralized Dashboard**: Must build custom TUI

### What We Must Build

1. **Swarm Coordinator Extension**: Central orchestration logic
2. **RPC Orchestrator**: Process manager for 32 agents
3. **Agent Registry**: Track status, capabilities, load
4. **Task Queue**: Distribute work intelligently
5. **Result Aggregator**: Combine outputs from multiple agents
6. **Monitoring Dashboard**: Real-time swarm status
7. **Cost Tracker**: Per-agent spending analysis

### What We Can Leverage

1. **Community Extensions**: awesome-pi-agent has security, monitoring, LSP tools
2. **Oh-My-Pi Fork**: Already has subagent orchestration, consider adopting
3. **Official Examples**: tools.ts shows state persistence, event handling patterns
4. **RPC Protocol**: Complete specification in docs/rpc.md
5. **SDK**: Embed Pi in custom orchestrator instead of subprocess spawning

---

## Recommended Architecture

### Option A: External Orchestrator (Pure Pi-Mono)

```
┌─────────────────────────────────────┐
│  Swarm Orchestrator (TypeScript)    │
│  - Task queue                        │
│  - Agent registry                    │
│  - Result aggregation                │
│  - Monitoring dashboard              │
└─────────────────────────────────────┘
              │
              │ RPC Protocol (stdin/stdout)
              │
    ┌─────────┴─────────┬─────────────────────┬─────────────────┐
    │                   │                     │                 │
┌───▼───┐         ┌─────▼─────┐       ┌──────▼──────┐   ┌─────▼─────┐
│ Agent │         │  Agent    │       │   Agent     │   │  Agent    │
│   1   │   ...   │    16     │  ...  │     31      │   │    32     │
│ RPC   │         │   RPC     │       │    RPC      │   │   RPC     │
└───────┘         └───────────┘       └─────────────┘   └───────────┘
```

**Pros**:
- Full control over orchestration
- Stays close to Pi's philosophy
- Easy to debug (each agent is subprocess)

**Cons**:
- Must build everything custom
- More complexity upfront

### Option B: Oh-My-Pi Fork (Pre-Built Orchestration)

```
┌─────────────────────────────────────┐
│  Oh-My-Pi Agent Harness             │
│  - Built-in subagent orchestration  │
│  - Role-based routing                │
│  - Git worktree isolation            │
│  - LSP integration                   │
└─────────────────────────────────────┘
              │
    ┌─────────┴─────────┬─────────────────────┬─────────────────┐
    │                   │                     │                 │
┌───▼───┐         ┌─────▼─────┐       ┌──────▼──────┐   ┌─────▼─────┐
│ Agent │         │  Agent    │       │   Agent     │   │  Agent    │
│   1   │   ...   │    16     │  ...  │     31      │   │    32     │
│ Role  │         │   Role    │       │    Role     │   │   Role    │
└───────┘         └───────────┘       └─────────────┘   └───────────┘
```

**Pros**:
- Orchestration layer already built
- LSP integration for code agents
- Role-based routing proven

**Cons**:
- Fork maintenance burden
- May have features we don't need

### Recommendation: Hybrid Approach

1. **Start with Option A** (pure Pi-Mono)
   - Build minimal coordinator
   - Validate architecture
   - Understand pain points

2. **Adopt Oh-My-Pi patterns**
   - Study their orchestration code
   - Implement similar patterns
   - Cherry-pick features

3. **Contribute back**
   - Share swarm patterns with community
   - Improve ecosystem
   - Help others build multi-agent systems

---

## Code Examples

### Swarm Coordinator Extension

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";

interface SwarmState {
  agents: Array<{
    id: string;
    role: string;
    status: "idle" | "busy" | "error";
    model: string;
    tasks_completed: number;
  }>;
  tasks_queue: Array<{
    id: string;
    type: string;
    priority: number;
    assigned_to?: string;
  }>;
}

export default function (pi: ExtensionAPI) {
  let swarmState: SwarmState = {
    agents: [],
    tasks_queue: [],
  };

  // Track agent lifecycle
  pi.on("agent_start", async (event, ctx) => {
    const agentId = ctx.sessionManager.getCurrentSession().id;
    // Update swarm state
  });

  pi.on("agent_end", async (event, ctx) => {
    // Mark agent as idle, assign next task
  });

  // Monitor tool execution
  pi.on("tool_execution_end", async (event, ctx) => {
    // Collect results, update task status
  });

  // Register swarm management tools
  pi.registerTool({
    name: "distribute_task",
    description: "Distribute task to swarm agents",
    parameters: Type.Object({
      task: Type.String(),
      priority: Type.Number(),
      role: Type.String(),
    }),
    async execute(id, params, signal, update, ctx) {
      // Find idle agent with matching role
      const agent = swarmState.agents.find(
        a => a.role === params.role && a.status === "idle"
      );

      if (!agent) {
        return { content: [{ type: "text", text: "No idle agents" }] };
      }

      // Assign task via RPC
      const result = await sendRPC(agent.id, {
        type: "prompt",
        message: params.task,
      });

      return {
        content: [{ type: "text", text: `Assigned to ${agent.id}` }],
        details: { agent_id: agent.id, task_id: id },
      };
    },
  });

  // Register swarm status command
  pi.registerCommand("swarm", {
    description: "Show swarm status",
    handler: async (args, ctx) => {
      ctx.ui.notify(`Active agents: ${swarmState.agents.length}`, "info");
      // Render dashboard
    },
  });
}
```

### RPC Orchestrator (Python)

```python
import json
import subprocess
import sys
from typing import Dict, List

class SwarmOrchestrator:
    def __init__(self, agent_count: int):
        self.agents: Dict[str, subprocess.Popen] = {}
        self.agent_roles = {
            "router": 1,
            "security": 4,
            "intel": 4,
            "http": 4,
            "recon": 4,
            "discovery": 4,
            "api": 4,
            "mobile": 4,
        }
        self.spawn_agents()

    def spawn_agents(self):
        """Spawn all agents in RPC mode"""
        for role, count in self.agent_roles.items():
            for i in range(count):
                agent_id = f"{role}-{i}"
                process = subprocess.Popen(
                    ["pi", "--mode", "rpc", "--no-session"],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                self.agents[agent_id] = process
                print(f"[+] Spawned {agent_id}")

    def send_command(self, agent_id: str, command: dict) -> dict:
        """Send RPC command to agent"""
        agent = self.agents.get(agent_id)
        if not agent:
            return {"error": "Agent not found"}

        command_json = json.dumps(command) + "\n"
        agent.stdin.write(command_json.encode())
        agent.stdin.flush()

        # Read response
        response_line = agent.stdout.readline().decode()
        return json.loads(response_line)

    def distribute_task(self, task: str, role: str = None):
        """Distribute task to appropriate agent"""
        # Find idle agent with matching role
        for agent_id, process in self.agents.items():
            if role and not agent_id.startswith(role):
                continue

            # Send prompt command
            response = self.send_command(agent_id, {
                "type": "prompt",
                "message": task,
            })

            print(f"[>] Assigned to {agent_id}: {response}")
            return agent_id

    def monitor_events(self, agent_id: str):
        """Monitor event stream from agent"""
        agent = self.agents.get(agent_id)
        if not agent:
            return

        while True:
            line = agent.stdout.readline().decode()
            if not line:
                break

            event = json.loads(line)
            if event["type"] == "message_end":
                print(f"[+] {agent_id} completed message")
            elif event["type"] == "tool_execution_end":
                print(f"[+] {agent_id} executed tool: {event['tool']}")

# Usage
orchestrator = SwarmOrchestrator(32)
orchestrator.distribute_task("Enumerate subdomains for samsung.com", "intel")
orchestrator.distribute_task("Scan for XSS in login form", "security")
```

---

## Resources & Links

### Official Documentation
- [Pi-Mono GitHub](https://github.com/badlogic/pi-mono)
- [Coding Agent README](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md)
- [Extension API Docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md)
- [Skills Documentation](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md)
- [RPC Protocol](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/rpc.md)
- [SDK Documentation](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/sdk.md)
- [Packages Guide](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md)
- [AGENTS.md](https://github.com/badlogic/pi-mono/blob/main/AGENTS.md)
- [Releases](https://github.com/badlogic/pi-mono/releases)

### Community Resources
- [Awesome Pi Agent](https://github.com/qualisero/awesome-pi-agent)
- [Oh-My-Pi Fork](https://github.com/can1357/oh-my-pi)
- [Example Extensions](https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent/examples/extensions)

### Blog Posts
- [What I Learned Building an Opinionated and Minimal Coding Agent](https://mariozechner.at/posts/2025-11-30-pi-coding-agent/)
- [How to Build a Custom Agent Framework with PI](https://nader.substack.com/p/how-to-build-a-custom-agent-framework)

---

## Next Steps

1. **Prototype Swarm Coordinator Extension**
   - Implement basic event monitoring
   - Test with 4 agents (1 per role)
   - Validate architecture

2. **Build RPC Orchestrator**
   - Python or TypeScript
   - Task queue implementation
   - Agent registry with load balancing

3. **Define Agent Specifications**
   - Each role's capabilities
   - Default models per role
   - Tool suites per role

4. **Create Skill Library**
   - Security skills
   - Intel skills
   - HTTP skills
   - Shared utilities

5. **Implement Monitoring**
   - Real-time dashboard (tmux or custom TUI)
   - Cost tracking
   - Performance metrics

6. **Test at Scale**
   - Spawn 32 agents
   - Run parallel tasks
   - Measure coordination overhead
   - Optimize bottlenecks

7. **Document Patterns**
   - Write guide for Pi multi-agent systems
   - Contribute to community
   - Share learnings

---

## Conclusion

Pi-Mono provides an excellent foundation for building our 32-agent swarm. The extension API, RPC mode, and event system give us all the primitives needed for orchestration. While Pi intentionally lacks built-in multi-agent features, this is actually a strength—we can design exactly the coordination layer we need.

**Key Takeaway**: Pi's philosophy is "powerful primitives, not opinionated frameworks." This aligns perfectly with our swarm vision. We build the orchestration layer that fits our bounty hunting workflow, leveraging Pi's robust foundation.

**Biggest Wins**:
1. RPC mode = full programmatic control
2. Event system = inter-agent coordination
3. Extension API = custom tools and behaviors
4. Model flexibility = per-agent optimization
5. Active community = learn from existing patterns

**Biggest Challenges**:
1. Must build orchestrator from scratch
2. No native agent-to-agent messaging
3. Need custom monitoring/dashboard
4. Cost tracking per-agent not built-in

**Recommendation**: Start with minimal viable swarm (4-8 agents), validate patterns, then scale to 32. Build coordinator as Pi extension for tight integration, use RPC orchestrator for process management.

---

**Research conducted**: 2026-02-23
**Researcher**: Claude Sonnet 4.5 (agent-reviewer)
**Target**: Pi-Mono v0.54.2 and community ecosystem
**Purpose**: Pi Agent Swarm architecture planning
