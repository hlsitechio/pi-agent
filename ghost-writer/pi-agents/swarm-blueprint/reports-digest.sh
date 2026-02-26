#!/bin/bash
# === FINDINGS & REPORTS DIGEST → #reports ===
# Aggregates bounty-triager, lead-tracker, bounty-estimator state,
# runs AI analysis, posts daily report digest to Discord.
# Cron: 0 20 * * *  (daily at 20:00 UTC — end of day summary)

set -euo pipefail

AGENTS_DIR="/mnt/bounty/Claude/pi-agents"
WEBHOOKS="$AGENTS_DIR/swarm-blueprint/webhooks.json"
OLLAMA_API="http://localhost:11434"
OLLAMA_MODEL="kimi-k2.5:cloud"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STATE_DIR="$AGENTS_DIR/swarm-blueprint/state"
LOG="$STATE_DIR/reports-digest.log"

mkdir -p "$STATE_DIR"

log() { echo "[$(date -u +%H:%M:%S)] $1" >> "$LOG"; }
log "[*] Reports digest starting"

# === OPSEC CHECK ===
if [ -f /tmp/swarm-halt ]; then log "SWARM HALTED"; exit 0; fi
if [ -f /tmp/opsec-red ]; then log "OPSEC RED"; exit 0; fi

# === LOAD WEBHOOK ===
WEBHOOK_URL=$(python3 -c "
import json
w = json.load(open('$WEBHOOKS'))
print(w.get('reports', {}).get('webhook_url', ''))
" 2>/dev/null || echo "")

if [ -z "$WEBHOOK_URL" ]; then
  log "[-] No webhook for #reports"
  exit 1
fi

# === GATHER FINDINGS DATA ===

# 1. Bounty Triager — findings count, triage status
TRIAGER_STATE="$AGENTS_DIR/bounty-triager/state"
TRIAGER_SUMMARY=""
POSTED_TRIAGES=0
if [ -f "$TRIAGER_STATE/last-run.json" ]; then
  TRIAGER_SUMMARY=$(python3 -c "
import json
d = json.load(open('$TRIAGER_STATE/last-run.json'))
print(d.get('summary', 'no data'))
" 2>/dev/null || echo "no data")
fi
if [ -f "$TRIAGER_STATE/posted-triages.json" ]; then
  POSTED_TRIAGES=$(python3 -c "
import json
d = json.load(open('$TRIAGER_STATE/posted-triages.json'))
print(len(d) if isinstance(d, list) else 0)
" 2>/dev/null || echo "0")
fi

# Chain log — shows triage workflow
CHAIN_LOG=""
if [ -f "$TRIAGER_STATE/chain-run.log" ]; then
  CHAIN_LOG=$(tail -20 "$TRIAGER_STATE/chain-run.log" 2>/dev/null || echo "")
fi

# 2. Lead Tracker — target prioritization
LEAD_STATE="$AGENTS_DIR/lead-tracker/state"
LEAD_SUMMARY=""
ACTIVE_PROGRAMS=0
if [ -f "$LEAD_STATE/last-run.json" ]; then
  LEAD_SUMMARY=$(python3 -c "
import json
d = json.load(open('$LEAD_STATE/last-run.json'))
print(json.dumps(d, indent=2))
" 2>/dev/null || echo "no data")
  ACTIVE_PROGRAMS=$(python3 -c "
import json
d = json.load(open('$LEAD_STATE/last-run.json'))
print(d.get('programs', d.get('active_programs', 0)))
" 2>/dev/null || echo "0")
fi

# 3. Bounty Estimator (may not have state yet)
ESTIMATOR_STATE="$AGENTS_DIR/bounty-estimator/state"
ESTIMATOR_DATA=""
if [ -d "$ESTIMATOR_STATE" ] && [ -f "$ESTIMATOR_STATE/last-run.json" ]; then
  ESTIMATOR_DATA=$(python3 -c "
import json
d = json.load(open('$ESTIMATOR_STATE/last-run.json'))
print(d.get('summary', json.dumps(d)))
" 2>/dev/null || echo "")
fi

# 4. Scope watcher — any scope changes
SCOPE_STATE="$AGENTS_DIR/scope-watcher/state"
SCOPE_CHANGES=""
if [ -f "$SCOPE_STATE/last-run.json" ]; then
  SCOPE_CHANGES=$(python3 -c "
import json
d = json.load(open('$SCOPE_STATE/last-run.json'))
print(d.get('summary', 'no changes'))
" 2>/dev/null || echo "no changes")
fi

# 5. Count findings across Bounty_New
FINDINGS_COUNT=0
REPORTS_DIR="/mnt/bounty/Claude/Bounty_New"
if [ -d "$REPORTS_DIR" ]; then
  FINDINGS_COUNT=$(find "$REPORTS_DIR" -name "*.md" -path "*/findings/*" 2>/dev/null | wc -l || echo "0")
fi

log "[+] Data: $POSTED_TRIAGES triages, $ACTIVE_PROGRAMS programs, $FINDINGS_COUNT finding files"

# === AI ANALYSIS ===
AI_PROMPT="You are a bug bounty report analyst. Generate a daily report digest from this data:

Bounty Triager: ${TRIAGER_SUMMARY:-no data}
Triages posted: $POSTED_TRIAGES
Triage chain log (last entries): ${CHAIN_LOG:-none}

Lead Tracker: ${LEAD_SUMMARY:-no data}
Active programs: $ACTIVE_PROGRAMS

Bounty Estimator: ${ESTIMATOR_DATA:-not configured}

Scope Changes: ${SCOPE_CHANGES:-none}

Finding files on disk: $FINDINGS_COUNT

Provide:
1. 📋 Pipeline Status: How many findings in each stage (new, triaged, reported, paid)
2. 🏆 Top Targets: Which programs look most promising right now
3. 💰 Revenue Outlook: Estimated pending payouts (if data available)
4. 📝 Submission Readiness: Any findings ready to submit?
5. 🎯 Tomorrow's Focus: What to hunt next based on current state

Be specific. Use numbers. Max 1000 chars."

AI_RESPONSE=$(curl -sf --max-time 45 "$OLLAMA_API/api/generate" \
  -d "$(python3 -c "
import json, sys
print(json.dumps({
  'model': '$OLLAMA_MODEL',
  'prompt': sys.stdin.read(),
  'stream': False,
  'options': {'temperature': 0.3, 'num_predict': 500}
}))
" <<< "$AI_PROMPT")" 2>/dev/null | python3 -c "
import json, sys
try:
  d = json.load(sys.stdin)
  print(d.get('response', 'AI analysis unavailable'))
except:
  print('AI analysis unavailable')
" 2>/dev/null || echo "AI analysis unavailable")

# === BUILD DISCORD MESSAGE ===
DISCORD_MSG="📊 **Daily Reports Digest** — $TIMESTAMP

**Sources:** Bounty Triager + Lead Tracker + Scope Watcher
**Triages:** $POSTED_TRIAGES | **Programs:** $ACTIVE_PROGRAMS | **Finding files:** $FINDINGS_COUNT

$AI_RESPONSE

$([ "$SCOPE_CHANGES" != "no changes" ] && echo "🔄 **Scope changes detected** — check #scope-watch" || echo "")
---
*Auto-generated daily by reports-digest | End-of-day summary*"

# === POST TO DISCORD ===
RESULT=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
msg = sys.stdin.read()[:1950]
print(json.dumps({'content': msg, 'username': 'Reports Digest'}))
" <<< "$DISCORD_MSG")" 2>/dev/null || echo "000")

if [ "$RESULT" = "204" ] || [ "$RESULT" = "200" ]; then
  log "[+] Posted to #reports (HTTP $RESULT)"
else
  log "[-] Failed to post (HTTP $RESULT)"
fi

# Save state
echo "{\"last_run\":\"$TIMESTAMP\",\"triages\":$POSTED_TRIAGES,\"programs\":$ACTIVE_PROGRAMS,\"findings\":$FINDINGS_COUNT}" > "$STATE_DIR/reports-digest-state.json"

log "[*] Done"
