#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT GOVERNANCE — Tier enforcement, VPN, scope, rate limits
#
# Every tool function calls _governance_check() before executing.
# Tiers: 0=observe, 1=monitor, 2=recon, 3=scan, 4=exploit
#
# Usage: source toolkit/_governance.sh (after _core.sh)
# ═══════════════════════════════════════════════════════════════

# --- Config ---
GOVERNANCE_SCOPE_FILE="/mnt/bounty/Claude/pi-agents/swarm-blueprint/approved-scope.json"
GOVERNANCE_RATE_DIR="/tmp/toolkit-rates"
GOVERNANCE_RATE_LIMIT="${GOVERNANCE_RATE_LIMIT:-500}"  # requests per hour per target
GOVERNANCE_LOG_DIR="/mnt/bounty/Claude/pi-agents/manager/state/toolkit"

mkdir -p "$GOVERNANCE_RATE_DIR" 2>/dev/null
mkdir -p "$GOVERNANCE_LOG_DIR" 2>/dev/null

# Caller tier (set by the sourcing agent's run.sh)
# Default: Tier 3 for Manager, override in agent config
AGENT_TIER="${AGENT_TIER:-3}"
AGENT_NAME="${AGENT_NAME:-manager}"

# --- Tier Registry (loaded from toolkit-registry.json or hardcoded fallback) ---
declare -A TOOLKIT_TIERS

_governance_init() {
    local registry_file="/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/toolkit-registry.json"

    if [[ -f "$registry_file" ]]; then
        # Parse registry JSON into associative array
        eval "$(python3 -c "
import json, sys
try:
    with open('$registry_file') as f:
        reg = json.load(f)
    for tool_name, info in reg.get('tools', {}).items():
        tier = info.get('tier', 0)
        print(f'TOOLKIT_TIERS[\"{tool_name}\"]={tier}')
except Exception as e:
    print(f'# Registry parse error: {e}', file=sys.stderr)
" 2>/dev/null)"
    fi

    # Hardcoded fallback for critical tools (if registry missing)
    [[ -z "${TOOLKIT_TIERS[dns_lookup]+x}" ]] && TOOLKIT_TIERS["dns_lookup"]=0
    [[ -z "${TOOLKIT_TIERS[dns_whois]+x}" ]] && TOOLKIT_TIERS["dns_whois"]=0
    [[ -z "${TOOLKIT_TIERS[shodan_ip]+x}" ]] && TOOLKIT_TIERS["shodan_ip"]=0
    [[ -z "${TOOLKIT_TIERS[shodan_search]+x}" ]] && TOOLKIT_TIERS["shodan_search"]=0
    [[ -z "${TOOLKIT_TIERS[nmap_scan]+x}" ]] && TOOLKIT_TIERS["nmap_scan"]=3
    [[ -z "${TOOLKIT_TIERS[nuclei_scan]+x}" ]] && TOOLKIT_TIERS["nuclei_scan"]=3
    [[ -z "${TOOLKIT_TIERS[sqlmap_scan]+x}" ]] && TOOLKIT_TIERS["sqlmap_scan"]=4
    [[ -z "${TOOLKIT_TIERS[dalfox_xss]+x}" ]] && TOOLKIT_TIERS["dalfox_xss"]=4

    _governance_log "INFO" "Governance initialized | agent=$AGENT_NAME tier=$AGENT_TIER tools=${#TOOLKIT_TIERS[@]}"
}

# --- Main Governance Check ---
# _governance_check TOOL_NAME [TARGET]
# Returns 0 if allowed, 1 if blocked
_governance_check() {
    local tool_name="$1"
    local target="${2:-}"
    local required_tier="${TOOLKIT_TIERS[$tool_name]:-0}"

    # 1. Tier check — caller must have sufficient privileges
    if (( AGENT_TIER < required_tier )); then
        _governance_log "BLOCKED" "tier | tool=$tool_name required=$required_tier agent_tier=$AGENT_TIER agent=$AGENT_NAME"
        echo "{\"error\":\"Governance: $AGENT_NAME (Tier $AGENT_TIER) blocked from $tool_name (requires Tier $required_tier)\"}" >&2
        return 1
    fi

    # 2. VPN check for Tier 2+ tools
    if (( required_tier >= 2 )); then
        if ! _governance_vpn_check; then
            _governance_log "BLOCKED" "vpn | tool=$tool_name agent=$AGENT_NAME"
            echo "{\"error\":\"Governance: VPN required for Tier $required_tier tools. VPN is DOWN.\"}" >&2
            return 1
        fi
    fi

    # 3. Scope check for Tier 2+ tools with a target
    if (( required_tier >= 2 )) && [[ -n "$target" ]]; then
        if ! _governance_scope_check "$target"; then
            _governance_log "BLOCKED" "scope | tool=$tool_name target=$target agent=$AGENT_NAME"
            echo "{\"error\":\"Governance: Target '$target' not in approved scope for $tool_name\"}" >&2
            return 1
        fi
    fi

    # 4. Rate limit for Tier 3+ tools
    if (( required_tier >= 3 )) && [[ -n "$target" ]]; then
        if ! _governance_rate_check "$target"; then
            _governance_log "BLOCKED" "rate | tool=$tool_name target=$target agent=$AGENT_NAME"
            echo "{\"error\":\"Governance: Rate limit exceeded for target '$target' ($GOVERNANCE_RATE_LIMIT/hr)\"}" >&2
            return 1
        fi
    fi

    # 5. Commander approval for Tier 4 tools
    if (( required_tier >= 4 )); then
        if ! _governance_approval_check "$tool_name" "$target"; then
            _governance_log "BLOCKED" "approval | tool=$tool_name target=$target agent=$AGENT_NAME"
            echo "{\"error\":\"Governance: Tier 4 tool '$tool_name' requires Commander approval. Request via Supabase tool_approvals.\"}" >&2
            return 1
        fi
    fi

    _governance_log "ALLOWED" "tool=$tool_name target=${target:-none} tier=$required_tier agent=$AGENT_NAME"
    return 0
}

# --- VPN Check ---
_governance_vpn_check() {
    # Check NordVPN status
    if command -v nordvpn &>/dev/null; then
        local status
        status=$(nordvpn status 2>/dev/null | grep -i "status" | head -1)
        if echo "$status" | grep -qi "connected"; then
            return 0
        fi
    fi

    # Fallback: check opsec flag file
    if [[ -f "/tmp/opsec-green" ]]; then
        return 0
    fi

    # Red flag means VPN is down
    if [[ -f "/tmp/opsec-red" ]]; then
        return 1
    fi

    # If we can't determine, be cautious — block
    return 1
}

# --- Scope Check ---
_governance_scope_check() {
    local target="$1"

    # If no scope file, allow (no restrictions configured)
    if [[ ! -f "$GOVERNANCE_SCOPE_FILE" ]]; then
        return 0
    fi

    # Extract domain from target (strip protocol, path, port)
    local domain
    domain=$(echo "$target" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')

    # Check if domain is in scope
    python3 -c "
import json, sys, fnmatch
try:
    with open('$GOVERNANCE_SCOPE_FILE') as f:
        scope = json.load(f)
    domain = '$domain'
    for pattern in scope.get('domains', []) + scope.get('wildcards', []):
        if fnmatch.fnmatch(domain, pattern) or fnmatch.fnmatch(domain, '*.' + pattern):
            sys.exit(0)
    # Check IPs
    for ip_range in scope.get('ips', []):
        if domain == ip_range:
            sys.exit(0)
    sys.exit(1)
except:
    sys.exit(0)  # If scope file is malformed, allow
" 2>/dev/null
    return $?
}

# --- Rate Limit Check ---
_governance_rate_check() {
    local target="$1"
    local hour
    hour=$(date -u +%Y%m%d%H)
    local rate_file="$GOVERNANCE_RATE_DIR/${target//[^a-zA-Z0-9._-]/_}_${hour}"

    # Read current count
    local count=0
    if [[ -f "$rate_file" ]]; then
        count=$(cat "$rate_file" 2>/dev/null || echo 0)
    fi

    # Check limit
    if (( count >= GOVERNANCE_RATE_LIMIT )); then
        return 1
    fi

    # Increment
    echo "$((count + 1))" > "$rate_file"

    # Cleanup old rate files (older than 2 hours)
    find "$GOVERNANCE_RATE_DIR" -name "*_*" -mmin +120 -delete 2>/dev/null &

    return 0
}

# --- Commander Approval Check ---
_governance_approval_check() {
    local tool_name="$1"
    local target="${2:-}"

    # Source Supabase config if not already loaded
    if [[ -z "$SUPABASE_URL" ]]; then
        source /mnt/bounty/Claude/pi-agents/swarm-blueprint/supabase-config.env 2>/dev/null
    fi

    if [[ -z "$SUPABASE_URL" ]]; then
        return 1  # Can't check without Supabase
    fi

    # Check for valid (non-expired) approval
    local filter="tool_name=eq.${tool_name}&status=eq.approved&expires_at=gt.$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -n "$target" ]]; then
        filter="${filter}&target=eq.${target}"
    fi

    local result
    result=$(curl -sf \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        "${SUPABASE_URL}/rest/v1/tool_approvals?${filter}&limit=1" 2>/dev/null)

    # If we got a non-empty array, approval exists
    if [[ -n "$result" && "$result" != "[]" ]]; then
        return 0
    fi

    # Auto-request approval
    _governance_request_approval "$tool_name" "$target"
    return 1
}

# --- Request Commander Approval ---
_governance_request_approval() {
    local tool_name="$1"
    local target="${2:-}"

    if [[ -z "$SUPABASE_URL" ]]; then
        return 1
    fi

    local payload
    payload=$(python3 -c "
import json
print(json.dumps({
    'tool_name': '$tool_name',
    'target': '$target' or None,
    'requested_by': '$AGENT_NAME',
    'status': 'pending'
}))
" 2>/dev/null)

    curl -sf \
        -X POST \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=minimal" \
        "${SUPABASE_URL}/rest/v1/tool_approvals" \
        -d "$payload" 2>/dev/null

    _governance_log "APPROVAL_REQUESTED" "tool=$tool_name target=${target:-none} agent=$AGENT_NAME"
}

# --- Governance Logging ---
_governance_log() {
    local level="$1"
    shift
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [GOV] [$level] $*" >> "$GOVERNANCE_LOG_DIR/governance.log" 2>/dev/null
}

# --- Initialize on source ---
_governance_init

# Export functions
[[ -n "${BASH_VERSION:-}" ]] && export -f _governance_check _governance_vpn_check _governance_scope_check || true
[[ -n "${BASH_VERSION:-}" ]] && export -f _governance_rate_check _governance_approval_check _governance_request_approval || true
[[ -n "${BASH_VERSION:-}" ]] && export -f _governance_log _governance_init || true
