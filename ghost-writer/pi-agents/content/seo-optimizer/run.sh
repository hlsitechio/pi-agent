#!/bin/bash
# SEO Optimizer Agent Runner
# Tier: OBSERVE (0) — optimizes edited articles for SEO
set -e

AGENT_HOME="/app/pi-agents/content/seo-optimizer"
AGENT_TIER=0

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=120

cd "$AGENT_HOME"

echo "[*] Starting SEO Optimizer agent..."
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
  "Optimize one edited article for SEO.

1. Call check_opsec — if RED, stop.
2. Call get_edited_articles to load an article with status 'edited'
3. Apply SEO optimizations:
   - Add compelling meta description (150-160 chars)
   - Extract relevant keywords (5-10 primary keywords)
   - Optimize title for clicks (power words, numbers, urgency)
   - Improve H2/H3 structure (SEO hierarchy)
   - Add 3-5 internal link suggestions (to related topics)
   - Add 2-3 external link suggestions (authoritative sources)
   - Add schema markup suggestions (Article, HowTo, or FAQPage)
4. Call save_optimized with the enhanced article

SEO OPTIMIZATION PRIORITIES:
- Meta description: compelling, includes primary keyword, calls to action
- Title: under 60 chars, includes keyword, numbers/power words
- Headers: keyword-rich but natural, proper H2/H3 hierarchy
- Links: contextual, valuable, natural anchor text
- Schema: appropriate type for content, all required fields

Follow governance. Optimize ONE article, then STOP." \
  < /dev/null

echo ""
echo "[+] SEO Optimizer completed"
