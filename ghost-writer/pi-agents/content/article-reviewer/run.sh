#!/bin/bash
# Article Reviewer Agent Runner
# Tier: OBSERVE (0) — fact-checks articles before publishing
set -e

AGENT_HOME="/app/pi-agents/content/article-reviewer"
AGENT_TIER=0

# Governance pre-flight
source /app/pi-agents/swarm-blueprint/preflight-governance.sh

EXTENSION="${AGENT_HOME}/extension.ts"
TIMEOUT=240

cd "$AGENT_HOME"

echo "[*] Starting Article Reviewer agent..."
echo "[i] Model: GLM-5:cloud (ollama)"
echo "[i] Tier: OBSERVE ($AGENT_TIER)"
echo "[i] Timeout: ${TIMEOUT}s"
echo ""

timeout -k 10 "$TIMEOUT" pi \
  --provider ollama \
  --model "glm-5:cloud" \
  --extension "$EXTENSION" \
  --no-session \
  --thinking off \
  --print \
  "Review one article from the edited queue for factual accuracy.

1. Call check_opsec — if RED, stop.
2. Call get_edited_article to find the next article with status 'edited'
3. Call read_cowork_context to load research notes from previous stages
4. For EVERY statistic, number, percentage, or data point in the article:
   - Call verify_stat to check it against web sources
   - Call research_cve for any CVE numbers mentioned
5. For any claims that CANNOT be verified:
   - Flag them in your review
   - Suggest removal or replacement with verified data
6. Check for AI hallucination patterns:
   - Fabricated company names or products
   - Made-up statistics with suspiciously round numbers
   - Non-existent CVE IDs
   - Fake quotes or attributions
7. Call write_cowork_context with your findings
8. Call save_reviewed with your verdict:
   - APPROVED: all facts verified, ready for SEO + publish
   - NEEDS_REVISION: specific issues listed, sent back to editor
   - REJECTED: too many fabrications, needs full rewrite

REVIEW RULES:
- ZERO tolerance for fake data
- Every number needs a source
- Every CVE must be real and verified
- When in doubt, flag it
- Be thorough. This is the last gate before publishing.

Review ONE article, then STOP." \
  < /dev/null

echo ""
echo "[+] Article Reviewer completed"
