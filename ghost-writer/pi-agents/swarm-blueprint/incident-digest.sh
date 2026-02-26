#!/bin/bash
# === INCIDENT DIGEST → #incidents ===
# Scans incident logs across all agents, aggregates by type,
# runs AI pattern analysis, posts digest to Discord.
# Cron: 0 */4 * * *  (every 4 hours)

set -euo pipefail

AGENTS_DIR="/mnt/bounty/Claude/pi-agents"
WEBHOOKS="$AGENTS_DIR/swarm-blueprint/webhooks.json"
OLLAMA_API="http://localhost:11434"
OLLAMA_MODEL="kimi-k2.5:cloud"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOOKBACK_HOURS=4
STATE_DIR="$AGENTS_DIR/swarm-blueprint/state"
LOG="$STATE_DIR/incident-digest.log"

mkdir -p "$STATE_DIR"

log() { echo "[$(date -u +%H:%M:%S)] $1" >> "$LOG"; }
log "[*] Incident digest starting"

# === OPSEC CHECK ===
if [ -f /tmp/swarm-halt ]; then log "SWARM HALTED"; exit 0; fi
if [ -f /tmp/opsec-red ]; then log "OPSEC RED"; exit 0; fi

# === LOAD WEBHOOK ===
WEBHOOK_URL=$(python3 -c "
import json
w = json.load(open('$WEBHOOKS'))
print(w.get('incidents', {}).get('webhook_url', ''))
" 2>/dev/null || echo "")

if [ -z "$WEBHOOK_URL" ]; then
  log "[-] No webhook for #incidents"
  exit 1
fi

# === AGGREGATE INCIDENTS ===
# Cutoff: 4 hours ago
CUTOFF=$(date -u -d "${LOOKBACK_HOURS} hours ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S)

INCIDENT_DATA=""
TOTAL_INCIDENTS=0
AGENTS_WITH_INCIDENTS=0

# Scan all agents for incidents.log
for inc_log in $(find "$AGENTS_DIR" -name "incidents.log" -type f 2>/dev/null); do
  agent_dir=$(dirname "$(dirname "$inc_log")")
  agent_name=$(basename "$agent_dir")

  # Get recent lines (within lookback window)
  recent=$(awk -v cutoff="$CUTOFF" '
    match($0, /\[([0-9T:Z-]+)\]/, ts) {
      if (ts[1] >= cutoff) print
    }
  ' "$inc_log" 2>/dev/null || tail -5 "$inc_log" 2>/dev/null)

  if [ -n "$recent" ]; then
    count=$(echo "$recent" | wc -l)
    TOTAL_INCIDENTS=$((TOTAL_INCIDENTS + count))
    AGENTS_WITH_INCIDENTS=$((AGENTS_WITH_INCIDENTS + 1))
    INCIDENT_DATA+="
--- $agent_name ($count incidents) ---
$recent
"
  fi
done

# Also scan error-watcher state for recent errors
ERROR_LOG="$AGENTS_DIR/error-watcher/state/last-run.json"
ERROR_SUMMARY=""
if [ -f "$ERROR_LOG" ]; then
  ERROR_SUMMARY=$(python3 -c "
import json
d = json.load(open('$ERROR_LOG'))
print(d.get('summary', 'no data'))
" 2>/dev/null || echo "")
fi

# Also scan audit logs for DENIED/BLOCKED events
DENIED_EVENTS=""
for audit_log in $(find "$AGENTS_DIR" -name "audit.log" -type f 2>/dev/null); do
  denied=$(grep -i "DENIED\|BLOCKED\|VIOLATION\|UNAUTHORIZED" "$audit_log" 2>/dev/null | tail -3)
  if [ -n "$denied" ]; then
    agent_name=$(basename "$(dirname "$(dirname "$audit_log")")")
    DENIED_EVENTS+="$agent_name: $denied
"
  fi
done

log "[+] Scanned: $TOTAL_INCIDENTS incidents from $AGENTS_WITH_INCIDENTS agents"

# === AI ANALYSIS ===
if [ "$TOTAL_INCIDENTS" -gt 0 ]; then
  AI_PROMPT="You are an incident analyst for a bug bounty agent swarm. Analyze these incidents from the last ${LOOKBACK_HOURS}h and provide:
1. Pattern summary (what's failing and why)
2. Severity assessment (CRITICAL/HIGH/MEDIUM/LOW)
3. Top 3 issues by frequency
4. Recommended actions

Error watcher summary: ${ERROR_SUMMARY:-none}
Governance violations: ${DENIED_EVENTS:-none}

Incident data:
$INCIDENT_DATA

Be concise. Max 800 chars."

  AI_RESPONSE=$(curl -sf --max-time 30 "$OLLAMA_API/api/generate" \
    -d "$(python3 -c "
import json, sys
print(json.dumps({
  'model': '$OLLAMA_MODEL',
  'prompt': sys.stdin.read(),
  'stream': False,
  'options': {'temperature': 0.3, 'num_predict': 400}
}))
" <<< "$AI_PROMPT")" 2>/dev/null | python3 -c "
import json, sys
try:
  d = json.load(sys.stdin)
  print(d.get('response', 'AI analysis unavailable'))
except:
  print('AI analysis unavailable')
" 2>/dev/null || echo "AI analysis unavailable")

  # === POST DIGEST ===
  DISCORD_MSG="🚨 **Incident Digest** — $TIMESTAMP

**Window:** Last ${LOOKBACK_HOURS}h | **Incidents:** $TOTAL_INCIDENTS | **Agents affected:** $AGENTS_WITH_INCIDENTS

$AI_RESPONSE

$([ -n "$DENIED_EVENTS" ] && echo "⛔ **Governance violations detected** — check audit logs" || echo "✅ No governance violations")
---
*Auto-generated every ${LOOKBACK_HOURS}h by incident-digest*"

else
  # All clear
  DISCORD_MSG="✅ **Incident Digest** — $TIMESTAMP

**Window:** Last ${LOOKBACK_HOURS}h | **Incidents:** 0 | **All clear**

No incidents detected across $(find "$AGENTS_DIR" -name "incidents.log" -type f 2>/dev/null | wc -l) monitored agents.
$([ -n "$ERROR_SUMMARY" ] && echo "**Error watcher:** $ERROR_SUMMARY" || echo "**Error watcher:** clean")
$([ -n "$DENIED_EVENTS" ] && echo "⛔ **Governance violations detected**" || echo "✅ No governance violations")
---
*Auto-generated every ${LOOKBACK_HOURS}h by incident-digest*"
fi

# === POST TO DISCORD ===
RESULT=$(curl -sf -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, sys
msg = sys.stdin.read()[:1950]
print(json.dumps({'content': msg, 'username': 'Incident Digest'}))
" <<< "$DISCORD_MSG")" 2>/dev/null || echo "000")

if [ "$RESULT" = "204" ] || [ "$RESULT" = "200" ]; then
  log "[+] Posted to #incidents (HTTP $RESULT)"
else
  log "[-] Failed to post (HTTP $RESULT)"
fi

log "[*] Done — $TOTAL_INCIDENTS incidents"
