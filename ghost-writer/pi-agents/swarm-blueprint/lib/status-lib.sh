#!/bin/bash
# === STATUS-LIB — Shared StatusOps Functions ===
# Source this in StatusOps agents:
#   source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/status-lib.sh

# Read a service monitor's state file safely
# Usage: read_service_state "d3bugr-monitor"
# Returns: JSON content or empty string
read_service_state() {
  local agent="$1"
  local state_file="/mnt/bounty/Claude/pi-agents/$agent/state/last-run.json"
  if [ -f "$state_file" ]; then
    cat "$state_file" 2>/dev/null
  else
    echo ""
  fi
}

# Check if a maintenance window is currently active
# Returns: 0 if in maintenance, 1 if not
is_maintenance_window() {
  [ -f /tmp/swarm-maintenance ] && return 0 || return 1
}

# Get the affected services during active maintenance
# Returns: comma-separated list or empty
get_maintenance_services() {
  if [ -f /tmp/swarm-maintenance ]; then
    cat /tmp/swarm-maintenance 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('affected_services',[])))" 2>/dev/null
  fi
}

# Check if a specific service should suppress alerts during maintenance
# Usage: suppress_during_maint "ollama"
# Returns: 0 if should suppress, 1 if not
suppress_during_maint() {
  local service="$1"
  if is_maintenance_window; then
    local services=$(get_maintenance_services)
    echo "$services" | grep -qi "$service" && return 0
  fi
  return 1
}

# Format a status line consistently
# Usage: format_status_line "UP" "VPN" "Montreal, CA" "4h 23m"
# Output: "  [UP] VPN         Montreal, CA      uptime: 4h 23m"
format_status_line() {
  local status="$1"    # UP or DOWN
  local name="$2"      # Service name
  local detail="$3"    # Status detail
  local duration="$4"  # Uptime duration

  if [ "$status" = "UP" ]; then
    printf "  [\xe2\x9c\x85 UP]   %-12s %-18s %s\n" "$name" "$detail" "uptime: $duration"
  else
    printf "  [\xf0\x9f\x94\xb4 DOWN] %-12s %-18s %s\n" "$name" "$detail" "down: $duration"
  fi
}

# Get how long a service has been in its current state
# Usage: get_service_duration "2026-02-25T14:30:00Z"
# Output: "4h 23m"
get_service_duration() {
  local since="$1"
  if [ -z "$since" ]; then echo "unknown"; return; fi
  local since_epoch=$(date -d "$since" +%s 2>/dev/null || echo "0")
  local now_epoch=$(date +%s)
  local diff=$(( now_epoch - since_epoch ))
  if [ "$diff" -lt 0 ] || [ "$since_epoch" = "0" ]; then echo "unknown"; return; fi
  local hours=$(( diff / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    echo "${hours}h ${mins}m"
  else
    echo "${mins}m"
  fi
}

# Compute uptime percentage from JSONL history for a service
# Usage: compute_uptime "vpn" "/path/to/uptime-history.jsonl" "86400"
# Args: service_key, jsonl_path, seconds_window
# Output: percentage like "99.7"
compute_uptime() {
  local service="$1"
  local jsonl="$2"
  local window="${3:-86400}"  # default 24h

  if [ ! -f "$jsonl" ]; then echo "N/A"; return; fi

  local cutoff=$(( $(date +%s) - window ))
  python3 -c "
import json, sys
from datetime import datetime
cutoff = $cutoff
total = 0
up = 0
with open('$jsonl') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            d = json.loads(line)
            ts = datetime.fromisoformat(d['ts'].replace('Z','+00:00')).timestamp()
            if ts >= cutoff:
                total += 1
                if d.get('$service', 0) == 1:
                    up += 1
        except: continue
if total == 0:
    print('N/A')
else:
    print(f'{(up/total)*100:.1f}')
" 2>/dev/null || echo "N/A"
}

# Read VPN state specifically (commonly needed)
read_vpn_state() {
  local vpn_file="/mnt/bounty/Claude/pi-agents/vpn-sentinel/state/vpn-state.json"
  if [ -f "$vpn_file" ]; then
    cat "$vpn_file" 2>/dev/null
  else
    echo '{"status":"unknown"}'
  fi
}

# Post to Discord with proper JSON escaping (safe for multi-line)
status_post_discord() {
  local webhook="$1"
  local message="$2"
  local username="${3:-StatusOps}"
  [ -z "$webhook" ] && return 1
  # Truncate to Discord limit
  if [ ${#message} -gt 1950 ]; then
    message="${message:0:1947}..."
  fi
  curl -s -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
msg = sys.stdin.read()
print(json.dumps({'content': msg, 'username': '$username'}))
" <<< "$message" 2>/dev/null)" > /dev/null 2>&1
}
