# Forensics Archive: Tainted Model Nuke
> Date: 2026-02-25T21:28:00Z
> Operation: MODEL_NUKE

## Context
Anthropic exposed industrial-scale distillation attacks by 3 Chinese AI labs:
- **DeepSeek**: 150K stolen Claude exchanges
- **Moonshot AI (Kimi)**: 3.4M stolen Claude exchanges
- **MiniMax**: 13M stolen Claude exchanges

Our entire agent swarm (45 agents) was running on `kimi-k2.5:cloud` (Moonshot AI) - a model built on stolen Claude data.

## Models Nuked
| Model | Origin | Reason |
|-------|--------|--------|
| kimi-k2.5:cloud | Moonshot AI | 3.4M stolen exchanges |
| kimi-fast:latest | Moonshot AI | Moonshot product |
| nurullahunlu/kimik2.5cloud:latest | Moonshot AI (3rd party) | Local copy, 2.0GB |
| deepseek-v3.2:cloud | DeepSeek | 150K stolen exchanges |
| minimax-m2.5:cloud | MiniMax | 13M stolen exchanges |

## Replacement Models
| Model | Origin | Role |
|-------|--------|------|
| devstral-2:123b-cloud | Mistral (France) | Hunting/Recon/Chiefs |
| glm-4.7:cloud | Zhipu AI (China, clean) | Content/Writing |
| gpt-oss:120b-cloud | OpenAI (US) | Intel/Analysis |
| gpt-oss:20b-cloud | OpenAI (US) | Ops/Quick tasks |

## Archived Contents
- `agent-states/` - All agent state dirs (logs, run history, analysis outputs)
- `chief-states/` - All chief state dirs (orchestration data)
- `chief-logs/` - All chief execution logs
- `ollama-monitor-*` - Ollama monitoring data showing tainted model usage

## Damage Analysis TODO
- [ ] Review all AI-generated outputs for injected content
- [ ] Check if any agent outputs contained exfiltration attempts
- [ ] Analyze prompt patterns for data leakage via cloud proxy
- [ ] Verify no backdoors in generated code/configs
- [ ] Check Discord webhook outputs for anomalous posts
- [ ] Review content pipeline articles for hidden manipulation
- [ ] Check if tainted models altered security assessments

## Key Questions
1. Did Moonshot/Kimi see our bounty hunting prompts via cloud inference?
2. Were any API keys, credentials, or target info sent through cloud proxy?
3. Did the model inject subtle misinformation into intel/CVE analysis?
4. Were content articles subtly manipulated for propaganda?
5. Did the model's censorship training affect security analysis accuracy?
