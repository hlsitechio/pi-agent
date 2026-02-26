#!/bin/bash
# Trend Scanner Agent Runner
# Tier: OBSERVE (0) — scans for trending tech/security topics
set -e

AGENT_HOME="/app/pi-agents/content/trend-scanner"
AGENT_TIER=0

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=180

cd "$AGENT_HOME"

echo "[*] Starting Trend Scanner agent..."
echo "[i] Model: GLM-4.7:cloud (ollama)"
echo "[i] Tier: OBSERVE ($AGENT_TIER)"
echo "[i] Timeout: ${TIMEOUT}s"
echo ""

timeout -k 10 "$TIMEOUT" pi \
  --provider ollama \
  --model "glm-4.7:cloud" \
  --extension "$EXTENSION" \
  --no-session \
  --thinking off \
  --print \
  "Scan for trending cybersecurity and technology topics across ALL data sources.

1. Call check_opsec — if RED, stop.
2. Scan ALL sources in parallel:
   - scan_hackernews (HN top stories)
   - scan_tech_trends (CISA KEV)
   - scan_reddit (r/netsec, r/cybersecurity, r/programming)
   - scan_github_trending (popular repos from last 7 days)
   - scan_lobsters (Lobste.rs hottest)
   - scan_rss_feeds (BleepingComputer, TheHackerNews, Krebs)
3. Cross-reference topics: if same topic appears on 3+ sources, add +2 to trending_score
4. Score each unique topic: trending_score (1-10), monetization_potential (1-10), competition (1-10, lower=better)
5. Ensure diversity: don't pick 5 articles about the same CVE. Spread across categories.
6. Pick top 5 topics with unique angles
7. Call save_topics to write to the queue

Follow governance rules. Stop when done." \
  < /dev/null

echo ""
echo "[+] Trend Scanner completed"
