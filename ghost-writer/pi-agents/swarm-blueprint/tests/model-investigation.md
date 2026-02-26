# Model Investigation: T126 (DeepSeek V3.2) & T127 (Kimi K2.5) Empty Content Bugs

> Investigator: Claude Opus 4.6 (agent-reviewer session)
> Date: 2026-02-24
> Status: **ROOT CAUSE IDENTIFIED**

---

## Executive Summary

DeepSeek V3.2 and Kimi K2.5 do NOT have an empty content bug at the Ollama API level.
Both models return valid content via all Ollama endpoints (native `/api/chat`, `/api/generate`,
and OpenAI-compatible `/v1/chat/completions`).

The "empty content" issue has **two distinct root causes**:

1. **DeepSeek V3.2: Broken tool calling** — DeepSeek does NOT use the OpenAI tool_calls
   response format. Instead, it emits tool calls as XML in the `content` field
   (`<function_calls><invoke name="...">...`). Pi's `openai-completions` provider
   only parses `tool_calls` from the delta, so DeepSeek's tool invocations are treated
   as plain text content, never executed, and the agent loop stalls.

2. **Both models with `--thinking off`**: When Pi sends `--thinking off`, it does NOT
   pass any reasoning suppression parameter to the Ollama OpenAI-compat endpoint.
   Ollama cloud models with `capabilities: ["thinking"]` always emit a `reasoning`
   field in the streaming delta alongside an empty `content: ""`. Pi correctly handles
   the `reasoning` field (it IS in the `reasoningFields` list), so thinking content
   IS captured. However, if the agent's prompt or workflow expects ONLY text content
   (no thinking blocks), the agent may incorrectly interpret the result as "empty".

---

## Detailed Findings

### Test 1: Raw Ollama API (`/api/chat`, non-streaming)

All three models return valid content:

| Model | content | thinking | Status |
|-------|---------|----------|--------|
| deepseek-v3.2:cloud | "Hello! It's wonderful to connect with you." | Present (chain-of-thought) | OK |
| kimi-k2.5:cloud | "Hello, it's wonderful to meet you!" | Present (chain-of-thought) | OK |
| minimax-m2.5:cloud | "Hello! It's great to meet you." | Present (shorter) | OK |

### Test 2: Raw Ollama API (`/api/generate`, non-streaming)

Same result — all three return valid `response` fields. This is what `test-ollama.sh` uses.

### Test 3: OpenAI-Compatible Endpoint (`/v1/chat/completions`, non-streaming)

All three return valid content:

| Model | content | reasoning field | Status |
|-------|---------|----------------|--------|
| deepseek-v3.2:cloud | "Hello there! It's lovely to meet you." | Present | OK |
| kimi-k2.5:cloud | "Hello, I hope you're having a wonderful day!" | Present | OK |
| minimax-m2.5:cloud | "Hello! It's great to meet you." | Present | OK |

Message keys for ALL models: `['role', 'content', 'reasoning']`
Note: Ollama uses `reasoning` (NOT `reasoning_content`).

### Test 4: OpenAI-Compatible Endpoint (STREAMING) — **Critical Finding**

Streaming structure for all three models:
```
reasoning chunks:  {"delta": {"content": "", "reasoning": "..."}}
content chunks:    {"delta": {"content": "Hello!", "reasoning": null}}
```

Key observation: During the reasoning phase, `content` is always `""` (empty string).
Pi's openai-completions.ts has a guard:
```typescript
if (choice.delta.content !== null && choice.delta.content !== undefined && choice.delta.content.length > 0)
```

This correctly SKIPS empty string content (`"".length === 0`), so no spurious empty
text blocks are created. The reasoning is captured via the `reasoning` field handler.
Content arrives after reasoning completes. **This path works correctly in Pi.**

### Test 5: Tool Calling — **BUG CONFIRMED for DeepSeek**

| Model | tool_calls field | content | finish_reason | Status |
|-------|-----------------|---------|---------------|--------|
| deepseek-v3.2:cloud | **None** | XML function_calls in content | stop | **BROKEN** |
| kimi-k2.5:cloud | Present (correct) | "" (empty) | tool_calls | OK |
| minimax-m2.5:cloud | Present (correct) | "" (empty) | tool_calls | OK |

DeepSeek V3.2 via Ollama's cloud proxy does NOT use the OpenAI tool_calls format.
Instead, it returns tool calls as XML content:
```xml
<function_calls>
<invoke name="get_weather">
<parameter name="city" string="true">Paris</parameter>
</invoke>
</function_calls>
```

Pi's `openai-completions.ts` only processes `choice.delta.tool_calls`, which is never
present for DeepSeek. The XML goes into a text block and is never executed.

Kimi K2.5 correctly uses the `tool_calls` format with proper function call IDs.

### Test 6: Model Capabilities (from `ollama show`)

| Model | capabilities | architecture |
|-------|-------------|-------------|
| deepseek-v3.2:cloud | completion, tools, thinking | deepseek3.2 |
| kimi-k2.5:cloud | completion, tools, thinking, vision | (remote, no arch) |
| minimax-m2.5:cloud | completion, tools, thinking | (remote, no arch) |

All report `tools` capability, but DeepSeek's tool calling format is incompatible
with the OpenAI standard that Pi expects.

---

## Root Causes

### T126: DeepSeek V3.2 Empty Content Bug

**Root Cause**: DeepSeek V3.2 (via Ollama cloud) does not implement OpenAI-compatible
tool calling. When tools are provided, it outputs XML-formatted function calls in the
`content` field instead of using the `tool_calls` response structure. Pi never sees
a tool call, the content contains XML that the agent can't act on, and the agent loop
appears to produce "empty" useful output.

**Impact**: DeepSeek V3.2 is **unusable for Pi agents that require tool calling**.
Simple text-only prompts work fine.

**Fix Options**:
1. **Parse XML tool calls** — Add a post-processing step in Pi's openai-completions
   provider (or a wrapper) that detects `<function_calls>` XML in text content and
   converts it to proper tool call objects. (Complex, fragile)
2. **Avoid DeepSeek for tool-calling agents** — Use DeepSeek only for text-generation
   tasks (analysis, summarization) where tools are not needed.
3. **Wait for Ollama fix** — Ollama's cloud proxy may eventually fix DeepSeek's
   tool calling to use the standard format.
4. **Use DeepSeek's native API directly** — Bypass Ollama and call DeepSeek's API
   with their native tool calling format.

**Recommended**: Option 2 (short-term) + Option 1 (long-term).

### T127: Kimi K2.5 Empty Content Bug

**Root Cause**: Kimi K2.5 works correctly for both text generation and tool calling
via the Ollama OpenAI-compatible endpoint. The "empty content" report may stem from:

1. **Intermittent cloud failures** — Ollama cloud models route to remote servers
   (`remote_host: https://ollama.com:443`). Network timeouts or rate limits could
   produce empty responses.
2. **Thinking-only responses** — If the agent processes only `content` blocks and
   ignores `thinking` blocks, responses that are mostly reasoning may appear empty.
3. **Tool call responses** — When Kimi makes a tool call, `content` is `""` and the
   actual response is in `tool_calls`. If the caller checks only `content`, it looks empty.

**Impact**: Kimi K2.5 is **functional** but may appear broken under specific conditions.

**Fix Options**:
1. **Add retry logic** — If content is empty and no tool_calls present, retry once.
2. **Check all response fields** — Ensure agent code checks `content`, `tool_calls`,
   AND `reasoning` before declaring a response "empty".
3. **Monitor cloud latency** — Log response times for cloud models to catch timeouts.

**Recommended**: Options 1 + 2.

---

## Agent Impact Assessment

| Agent | Model Used | Tool Calling Required | Impact |
|-------|-----------|----------------------|--------|
| agent-reviewer | minimax-m2.5:cloud | Yes | None (uses MiniMax) |
| hackernews-agent | minimax-m2.5:cloud | Yes | None |
| cve-monitor | minimax-m2.5:cloud | Yes | None |

Currently ALL agents use `minimax-m2.5:cloud`. The DeepSeek and Kimi bugs would only
manifest if agents are reassigned to those models (e.g., during T142-T144 benchmarking).

---

## Verification Commands

```bash
# Test basic text generation (all models work)
curl -s http://localhost:11434/v1/chat/completions -d '{
  "model": "deepseek-v3.2:cloud",
  "messages": [{"role": "user", "content": "Say hello"}],
  "stream": false
}' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])"

# Test tool calling (DeepSeek fails, Kimi/MiniMax work)
curl -s http://localhost:11434/v1/chat/completions -d '{
  "model": "deepseek-v3.2:cloud",
  "messages": [{"role": "user", "content": "Get weather for Paris"}],
  "tools": [{"type":"function","function":{"name":"get_weather","description":"Get weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],
  "stream": false
}' | python3 -c "import json,sys; d=json.load(sys.stdin); m=d['choices'][0]['message']; print('tool_calls:', m.get('tool_calls','NONE')); print('content:', m.get('content','')[:100])"
```

---

## Recommendations

1. **Keep MiniMax M2.5 as primary swarm model** — It has reliable tool calling and
   reasonable reasoning quality.
2. **DeepSeek V3.2 for text-only agents** — Good for analysis/summarization tasks
   that don't need tools (e.g., news-analyst, technique-librarian).
3. **Kimi K2.5 as secondary tool-calling model** — Works correctly, can serve as
   backup to MiniMax or for agents needing stronger reasoning.
4. **Add model capability validation** — Before assigning a model to an agent,
   verify tool calling works with a test prompt. Add this to `test-ollama.sh`.
5. **Update SWARM-ARCHITECTURE.md** — Document which models support which capabilities.

---

## Files Referenced

- Pi openai-completions provider: `/mnt/bounty/Claude/pi-mono/packages/ai/src/providers/openai-completions.ts`
- Pi model discovery: `/mnt/bounty/Claude/pi-mono/packages/web-ui/src/utils/model-discovery.ts`
- Pi model resolver: `/mnt/bounty/Claude/pi-mono/packages/coding-agent/src/core/model-resolver.ts`
- Agent utils: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/agent-utils.ts`
- Ollama test script: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/tests/test-ollama.sh`
- Agent-reviewer extension: `/mnt/bounty/Claude/pi-agents/agent-reviewer/extension.ts`
