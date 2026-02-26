#!/bin/bash
# Article Editor Agent Runner
# Tier: OBSERVE (0) — reviews and improves drafted articles
set -e

AGENT_HOME="/app/pi-agents/content/article-editor"
AGENT_TIER=0

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=180

cd "$AGENT_HOME"

echo "[*] Starting Article Editor agent..."
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
  "Edit one drafted article.

1. Call check_opsec — if RED, stop.
2. Call get_draft to load the latest unedited article
3. Review it for: quality, tone (must sound human), accuracy, structure
4. Apply edits: fix AI patterns, improve flow, add personality, verify claims
5. Call save_edited with the improved version

EDITING PRIORITIES:
- Kill AI slop phrases ('In this article...', 'It is worth noting...')
- Add first-person voice where missing
- Tighten paragraphs (3-4 sentences max)
- Verify any CVE numbers or tool versions mentioned
- Ensure actionable takeaways exist
- Check word count is 1500-2500

Follow governance. Edit ONE article, then STOP." \
  < /dev/null

echo ""
echo "[+] Article Editor completed"
