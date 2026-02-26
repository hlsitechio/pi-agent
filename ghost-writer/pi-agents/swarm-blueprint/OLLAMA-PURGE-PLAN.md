# Ollama Purge Plan — Tainted Model Cleanup
> Generated: 2026-02-26 | Status: PENDING

## Context
Post-Supabase nuke. Chinese-origin and questionable models need removal from local Ollama instance.
All credentials already rotated or dead (Supabase nuked). This is the local cleanup phase.

## Layer 1: Ollama Models to Delete

| Model | Origin | Size | Verdict |
|-------|--------|------|---------|
| glm-4.7:cloud | Zhipu AI (CN) | cloud | **KEEP** (needed for Ghost project) |
| glm-5:cloud | Zhipu AI (CN) | cloud | **KEEP** (needed for Ghost project) |
| gpt-oss:20b-cloud | Unknown | cloud | DELETE |
| gpt-oss:120b-cloud | Unknown | cloud | DELETE |
| devstral-2:123b-cloud | Mistral (FR) | cloud | DECIDE — not Chinese, keep? |
| m2.5-strike:latest | MiniMax (CN) | 1.3 KB | DELETE |
| worker-intel-analyst | Custom | 5.7 KB | INSPECT base model, then decide |
| worker-report-generator | Custom | 5.2 KB | INSPECT base model, then decide |
| worker-visitor-profiler | Custom | 6.6 KB | INSPECT base model, then decide |

## Layer 2: ~/.ollama/config.json

Current (TAINTED):
```json
{
  "integrations": {
    "claude": {
      "models": ["kimi-k2.5:cloud"],
      "aliases": {
        "fast": "kimi-k2.5:cloud",
        "primary": "kimi-k2.5:cloud"
      }
    }
  }
}
```

Action: Rewrite with clean model reference.

## Layer 3: Agent Config Files (45 roster JSONs)

All 45 files in `/mnt/bounty/Claude/pi-agents/manager/roster/` contain tainted model references.
These were from the Phase 1-5 run.sh updates — roster regen may have re-introduced them.

Action: Batch replace model references with chosen clean model.

## Layer 4: Other File References

| File | Reference | Action |
|------|-----------|--------|
| `agent-reviewer/state/models-config.json` | kimi-k2.5, deepseek-v3.2, minimax-m2.5 | Clean |
| `ollama-monitor/run.sh` | devstral-2, glm-4.7, gpt-oss (TARGET_MODELS) | Update model list |
| `swarm-blueprint/swarm-state.json` | kimi-k2.5:cloud (line 380) | Clean |
| `supabase backup/data/memories.json` | kimi refs | LEAVE (historical evidence) |
| `supabase backup/data/chief_runs.json` | kimi refs | LEAVE (historical evidence) |
| `forensics/` directory | kimi refs | LEAVE (preserved evidence) |

## Execution Order

1. `ollama rm gpt-oss:20b-cloud gpt-oss:120b-cloud m2.5-strike:latest`
2. Decide on devstral-2 (Mistral = French, not Chinese)
3. Decide on worker-* models (custom, can't inspect base)
4. Rewrite `~/.ollama/config.json` with clean model
5. Clean `ollama-monitor/run.sh` TARGET_MODELS
6. Clean `agent-reviewer/state/models-config.json`
7. Clean `swarm-blueprint/swarm-state.json` line 380
8. Re-check 45 roster JSONs for clean model refs
9. Leave forensics/ and supabase backup/ untouched (read-only evidence)

## Notes
- GLM-4.7 and GLM-5 are Zhipu-created but hosted on Ollama's US cloud infra
- Ollama says "does not retain your data"
- kimi-k2.5:cloud already removed from model list but still in config
- The `:cloud` tag = Ollama proxy, NOT direct to model creator's servers
