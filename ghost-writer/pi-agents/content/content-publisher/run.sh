#!/bin/bash
# Content Publisher Agent Runner
# Tier: MONITOR (1) — posts articles to platforms via API
set -e

AGENT_HOME="/app/pi-agents/content/content-publisher"
AGENT_TIER=1

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=120

cd "$AGENT_HOME"

echo "[*] Starting Content Publisher agent..."
echo "[i] Model: GLM-4.7:cloud (ollama)"
echo "[i] Tier: MONITOR ($AGENT_TIER)"
echo "[i] Timeout: ${TIMEOUT}s"
echo ""

timeout -k 10 "$TIMEOUT" pi \
  --provider ollama \
  --model "glm-4.7:cloud" \
  --extension "$EXTENSION" \
  --no-session \
  --thinking off \
  --print \
  "Publish edited articles to platforms.

1. Call check_opsec — if RED, stop.
2. Call get_publishable to find edited articles ready to publish
3. Call check_platforms to see which platforms are configured
4. For each article + platform combo:
   - Call publish_article with platform and article content
5. Call update_tracker with publication results

Follow governance. Publish what's ready, then STOP." \
  < /dev/null

echo ""
echo "[+] Content Publisher completed"
