#!/bin/bash
# Article Writer Agent Runner
# Tier: OBSERVE (0) — writes articles from topic queue
set -e

AGENT_HOME="/app/pi-agents/content/article-writer"
AGENT_TIER=0

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=180

cd "$AGENT_HOME"

echo "[*] Starting Article Writer agent..."
echo "[i] Model: GLM-4.7:cloud (ollama)"
echo "[i] Tier: OBSERVE ($AGENT_TIER)"
echo "[i] Timeout: ${TIMEOUT}s"
echo ""

timeout --kill-after=10 "$TIMEOUT" pi \
  --provider ollama \
  --model "glm-4.7:cloud" \
  --extension "$EXTENSION" \
  --no-session \
  --thinking off \
  --print \
  "Write one article from the topic queue.

1. Call check_opsec — if RED, stop.
2. Call get_next_topic to pick the highest-scored pending topic
3. Call get_template to load the right article template for the category
4. Write a complete, high-quality article (1500-2500 words)
5. Call save_article with the full markdown content

WRITING RULES:
- Write like a REAL human practitioner, not a chatbot
- First person perspective: 'I found...', 'In my experience...'
- Include code examples, real commands, specific tools
- NO filler phrases: 'In this article...', 'It is important to note...'
- Strong opening hook (anecdote, surprising fact, provocative question)
- Actionable takeaways at the end
- Keep paragraphs short (3-4 sentences max)

Follow governance rules. Write ONE article, then STOP." \
  < /dev/null

echo ""
echo "[+] Article Writer completed"
