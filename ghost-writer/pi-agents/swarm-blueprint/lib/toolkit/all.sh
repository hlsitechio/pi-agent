#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT ALL — Meta-loader: sources foundation + all modules
#
# Usage: source toolkit/all.sh
# Works in both bash (Manager/agents) and zsh (Claude Code).
# Lazy-loaded on demand — do NOT source at startup.
# ═══════════════════════════════════════════════════════════════

# Resolve toolkit directory — works in both bash and zsh
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # zsh: $0 is the sourced script path when using 'source'
    TOOLKIT_ROOT="$(cd "$(dirname "$0")" && pwd)"
fi

# Validate resolution (catch bad $0 in interactive shells)
if [[ ! -f "$TOOLKIT_ROOT/_core.sh" ]]; then
    TOOLKIT_ROOT="/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/toolkit"
fi

# --- Foundation (order matters) ---
source "$TOOLKIT_ROOT/_core.sh"
source "$TOOLKIT_ROOT/_governance.sh"
source "$TOOLKIT_ROOT/_output.sh"

# --- Tool Modules ---
source "$TOOLKIT_ROOT/dns.sh"
source "$TOOLKIT_ROOT/intel.sh"
source "$TOOLKIT_ROOT/secrets.sh"
source "$TOOLKIT_ROOT/recon.sh"
source "$TOOLKIT_ROOT/scanning.sh"
source "$TOOLKIT_ROOT/exploitation.sh"
source "$TOOLKIT_ROOT/browser.sh"

# Conditional: only source if file exists (built by background agent)
[[ -f "$TOOLKIT_ROOT/winrm.sh" ]] && source "$TOOLKIT_ROOT/winrm.sh"
[[ -f "$TOOLKIT_ROOT/etb.sh" ]]   && source "$TOOLKIT_ROOT/etb.sh"

# --- Toolkit Info ---
toolkit_list() {
    echo "=== MANAGER TOOLKIT ==="
    echo "Foundation: _core.sh, _governance.sh, _output.sh"
    echo ""
    echo "Modules loaded:"
    local funcs
    funcs=$(declare -F | grep -c 'toolkit_')
    echo "  dns.sh          — 5 tools  (Tier 0-2)"
    echo "  intel.sh         — 5 tools  (Tier 0)"
    echo "  secrets.sh       — 4 tools  (Tier 0)"
    echo "  recon.sh         — 15 tools (Tier 2)"
    echo "  scanning.sh      — 11 tools (Tier 3)"
    echo "  exploitation.sh  — 8 tools  (Tier 4)"
    echo "  browser.sh       — 17 tools (Tier 2-4)"
    [[ -f "$TOOLKIT_ROOT/winrm.sh" ]] && echo "  winrm.sh         — 35 tools (Tier 4)"
    [[ -f "$TOOLKIT_ROOT/etb.sh" ]]   && echo "  etb.sh           — 3 tools  (Tier 1)"
    echo ""
    echo "Total toolkit_ functions: $funcs"
    echo "Agent: ${AGENT_NAME:-manager} | Tier: ${AGENT_TIER:-3}"
    echo ""
    echo "Governance: VPN required Tier 2+, scope check Tier 2+, rate limit Tier 3+, approval Tier 4"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_list || true

# --- Quick Health Check All Services ---
toolkit_health_all() {
    echo "=== RAILWAY SERVICE HEALTH ==="
    local services=(d3bugr nmap nuclei sqlmap dns bhp harvester argus geolock etb cdp cvedb winrm trufflehog)
    for svc in "${services[@]}"; do
        local status
        status=$(_toolkit_health "$svc")
        printf "  %-15s %s\n" "$svc" "$status"
    done
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_health_all || true

# --- Execute Tool by Name ---
# toolkit_exec TOOL_NAME [ARGS...]
# Dispatches to toolkit_TOOL_NAME function
toolkit_exec() {
    local tool_name="$1"
    shift
    local func_name="toolkit_${tool_name}"

    if ! declare -F "$func_name" &>/dev/null; then
        echo "{\"error\":\"Unknown tool: $tool_name. Run toolkit_list for available tools.\"}"
        return 1
    fi

    "$func_name" "$@"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_exec || true

_toolkit_log "INFO" "Toolkit fully loaded | agent=${AGENT_NAME:-manager} tier=${AGENT_TIER:-3}"
