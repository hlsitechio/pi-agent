# Model Benchmark: New AI Models for Pi Agent Swarm (T138-T142)

> Investigator: Claude Opus 4.6 (agent-reviewer session)
> Date: 2026-02-23
> Status: **COMPLETE**

---

## Executive Summary

Tested three new models (qwen3-coder, gpt-oss, devstral-small-2) for potential use in
the Pi agent swarm. **None are currently available on the local Ollama instance.** All three
exist in the Ollama library but require explicit `ollama pull` to install. Additionally
benchmarked all currently available models for comparison.

---

## T138: Qwen3-Coder

**Status: NOT AVAILABLE (not pulled)**

- Exists in Ollama library: **Yes** (`https://ollama.com/library/qwen3-coder`)
- Available tags: `latest`, `30b` (19GB), `480b` (290GB), `30b-a3b-q4_K_M` (19GB), `30b-a3b-q8_0` (32GB)
- Local installation: **Not found** — tested `qwen3-coder`, `qwen3-coder:cloud`, `qwen-coder`
- Action required: `ollama pull qwen3-coder:30b` (19GB) or use cloud proxy if available

**Assessment**: The 30B MoE variant (30B total, 3B active) is the sweet spot for Pi agents.
At 19GB it fits on a Pi with 32GB+ RAM (Pi 5 with swap or cluster node). The 480B variant
is server-only. Qwen3 series is known for strong code generation — ideal for coding-agent
tasks, report formatting, and structured output generation.

---

## T139: GPT-OSS

**Status: NOT AVAILABLE (not pulled)**

- Exists in Ollama library: **Yes** (`https://ollama.com/library/gpt-oss`)
- Available tags: `latest`, `20b` (14GB), `120b` (65GB), `20b-cloud`, `120b-cloud`
- Local installation: **Not found** — tested `gpt-oss`, `gpt-oss:cloud`, `gpt4o-mini`
- Action required: `ollama pull gpt-oss:20b-cloud` (cloud proxy) or `gpt-oss:20b` (14GB local)

**Assessment**: The 20B variant at 14GB is the most practical for Pi deployment. Cloud
variants may offer better performance without local resource cost. GPT-OSS is interesting
as an open-weight alternative — need to verify tool-calling compatibility with Pi's
openai-completions provider before deployment (ref: DeepSeek XML tool call bug in
model-investigation.md).

---

## T140: Devstral-Small-2

**Status: NOT AVAILABLE (not pulled)**

- Exists in Ollama library: **Partially** (library page exists but no clear tag listing)
- Local installation: **Not found** — tested `devstral-small`, `devstral-small-2`, `:cloud` variants
- Action required: Investigate exact model name in Ollama registry; may need alternative source

**Assessment**: Devstral is Mistral's coding-focused model. The "small" variant should
be Pi-friendly if available. Lower priority than qwen3-coder and gpt-oss until we confirm
availability and exact model specifications.

---

## T141-T142: Currently Available Models — Benchmark Results

### Test 1: General Security Knowledge

**Prompt**: "List 3 common web vulnerabilities. Be brief."

| Model | Status | Chars | Tokens | Latency | Quality |
|-------|--------|-------|--------|---------|---------|
| nurullahunlu/kimik2.5cloud | OK | 425 | 87 | 2.3s | Basic — listed SQLi, XSS, Clickjacking (clickjacking is unusual choice) |
| minimax-m2.5:cloud | OK | 320 | 194 | 5.7s | Good — XSS, SQLi, CSRF (solid picks, markdown formatting) |
| deepseek-v3.2:cloud | OK | 225 | 164 | 8.4s | Good — SQLi, XSS, Broken Auth (concise, accurate) |
| kimi-k2.5:cloud | OK | 348 | 552 | 5.1s | Good — SQLi, XSS, Broken Access Control (strong, well-structured) |
| m2.5-strike | FAIL | — | — | — | Does not support chat or generate |
| kimi-fast | FAIL | — | — | — | Does not support chat or generate |
| worker-* (3 models) | FAIL | — | — | — | Do not support chat (custom pipeline models) |

### Test 2: Security Header Analysis (Bounty-Relevant)

**Prompt**: Analyze Apache 2.4.49 / PHP 7.4.3 / ACAO wildcard headers for vulns.

| Model | Chars | Tokens | Latency | CVE Awareness | Quality Rating |
|-------|-------|--------|---------|---------------|----------------|
| nurullahunlu/kimik2.5cloud | 1962 | 380 | 10.0s | Generic (no CVEs cited) | 6/10 |
| minimax-m2.5:cloud | ~1115 | — | 16.5s | **CVE-2021-41773, CVE-2021-42013** | 9/10 |
| deepseek-v3.2:cloud | 2556 | 1250 | 31.7s | **CVE-2021-41773** (detailed) | 9/10 |
| kimi-k2.5:cloud | 743 | 571 | 8.9s | **CVE-2021-41773/42013** + PHP EOL | 9/10 |

### Speed Rankings (wall clock, general prompt)

1. **nurullahunlu/kimik2.5cloud** — 2.3s (fastest, but lowest quality)
2. **kimi-k2.5:cloud** — 5.2s (best speed/quality ratio)
3. **minimax-m2.5:cloud** — 5.8s (reliable, good formatting)
4. **deepseek-v3.2:cloud** — 8.5s (slowest, but most detailed)

### Quality Rankings (security analysis)

1. **deepseek-v3.2:cloud** — Most thorough analysis, cites specific CVEs, detailed recommendations
2. **kimi-k2.5:cloud** — Concise but accurate, correctly identifies CVEs and EOL status
3. **minimax-m2.5:cloud** — Good tabular output, CVE-aware, reliable tool calling
4. **nurullahunlu/kimik2.5cloud** — Acceptable but generic, no CVE citations

### Tool Calling Compatibility (from model-investigation.md)

| Model | Tool Calling | Format | Pi Compatible |
|-------|-------------|--------|---------------|
| minimax-m2.5:cloud | Yes | OpenAI standard | **Yes** |
| kimi-k2.5:cloud | Yes | OpenAI standard | **Yes** |
| deepseek-v3.2:cloud | Broken | XML in content field | **No** (text-only OK) |
| nurullahunlu/kimik2.5cloud | Unknown | Not tested | Needs verification |

---

## Model Availability Summary

| Model | In Ollama Library | Locally Installed | Smallest Size | Cloud Available |
|-------|-------------------|-------------------|---------------|-----------------|
| qwen3-coder | Yes | **No** | 19GB (30B MoE) | Unknown |
| gpt-oss | Yes | **No** | 14GB (20B) | Yes (20b-cloud) |
| devstral-small-2 | Unclear | **No** | Unknown | Unknown |
| minimax-m2.5 | Yes | **Yes** (cloud) | Cloud only | Yes |
| deepseek-v3.2 | Yes | **Yes** (cloud) | Cloud only | Yes |
| kimi-k2.5 | Yes | **Yes** (cloud) | Cloud only | Yes |
| nurullahunlu/kimik2.5cloud | Yes | **Yes** (1.9GB) | 1.9GB | N/A (local) |

---

## Recommendations for Agent Assignment

### Current Best: Keep MiniMax M2.5 as Primary

MiniMax M2.5 remains the best choice for the swarm:
- Reliable tool calling (OpenAI-compatible)
- Good security analysis quality (9/10)
- Reasonable latency (~6s)
- Proven in production (all current agents use it)

### Secondary: Kimi K2.5 for Speed-Sensitive Agents

Kimi K2.5 is the best alternative:
- Correct tool calling format
- Fastest among high-quality models (~5s)
- Strong CVE awareness
- Use for: real-time monitors, alert-driven agents

### Text-Only: DeepSeek V3.2 for Analysis Agents

DeepSeek V3.2 excels at deep analysis but cannot do tool calling:
- Most thorough vulnerability analysis
- Use for: report-generator, technique-librarian, news-analyst
- Do NOT assign to agents requiring tool use

### New Models: Pull Priority

1. **gpt-oss:20b-cloud** — Highest priority. Cloud proxy avoids RAM constraints.
   Test tool calling compatibility before agent assignment.
2. **qwen3-coder:30b** — Second priority. Strong code generation for coding-agent
   tasks. 19GB requires dedicated node or swap.
3. **devstral-small-2** — Lowest priority. Availability unclear. Revisit when Ollama
   registry confirms the model.

### Action Items

```bash
# Pull new models for testing
ollama pull gpt-oss:20b-cloud
ollama pull qwen3-coder              # Will pull default tag

# After pulling, verify tool calling
curl -s http://localhost:11434/v1/chat/completions -d '{
  "model": "gpt-oss:20b-cloud",
  "messages": [{"role": "user", "content": "Get weather for Paris"}],
  "tools": [{"type":"function","function":{"name":"get_weather","description":"Get weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}],
  "stream": false
}' | python3 -c "
import json,sys
d=json.load(sys.stdin)
m=d['choices'][0]['message']
print('tool_calls:', m.get('tool_calls','NONE'))
print('content:', m.get('content','')[:100])
"
```

---

## Non-Functional Models

The following models on the Ollama instance do not support standard chat/generate:

| Model | Size | Issue |
|-------|------|-------|
| m2.5-strike:latest | 0GB (proxy) | No chat or generate support |
| kimi-fast:latest | 0GB (proxy) | No chat or generate support |
| worker-intel-analyst | 0GB (proxy) | No chat support (custom pipeline) |
| worker-report-generator | 0GB (proxy) | No chat support (custom pipeline) |
| worker-visitor-profiler | 0GB (proxy) | No chat support (custom pipeline) |

These appear to be custom routing/pipeline models, not standard LLMs. They may require
specific API endpoints or orchestration layers to function.

---

## Files Referenced

- Prior investigation: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/tests/model-investigation.md`
- Ollama test script: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/tests/test-ollama.sh`
- Agent utils: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/agent-utils.ts`
- Pi model resolver: `/mnt/bounty/Claude/pi-mono/packages/coding-agent/src/core/model-resolver.ts`
