#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT SCANNING — Port scanning, vuln scanning, content discovery
#
# Tier 3 scanning tools: nmap, nuclei, ffuf, feroxbuster
# All functions require VPN + scope + rate limit via governance.
#
# Dependencies: _core.sh, _governance.sh, _output.sh
# Usage: source toolkit/scanning.sh
# ═══════════════════════════════════════════════════════════════

# --- Nmap: Full port scan ---
toolkit_nmap_scan() {
    local target="$1"
    local ports="${2:-top-100}"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nmap_scan" "$target" || return 1
    local result=$(_toolkit_d3bugr "nmap_scan" '{"target":"'"$target"'","ports":"'"$ports"'"}')
    _route_result "nmap_scan" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nmap_scan || true

# --- Nmap: Quick scan ---
toolkit_nmap_quick() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nmap_quick" "$target" || return 1
    local result=$(_toolkit_d3bugr "nmap_quick" '{"target":"'"$target"'"}')
    _route_result "nmap_quick" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nmap_quick || true

# --- Nuclei: Full vulnerability scan ---
toolkit_nuclei_scan() {
    local target="$1"
    local severity="${2:-critical,high}"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_scan" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_scan" '{"target":"'"$target"'","severity":"'"$severity"'"}')
    _route_result "nuclei_scan" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_scan || true

# --- Nuclei: Quick scan ---
toolkit_nuclei_quick() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_quick" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_quick" '{"target":"'"$target"'"}')
    _route_result "nuclei_quick" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_quick || true

# --- Nuclei: CVE detection ---
toolkit_nuclei_cves() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_cves" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_cves" '{"target":"'"$target"'"}')
    _route_result "nuclei_cves" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_cves || true

# --- Nuclei: Technology detection ---
toolkit_nuclei_tech() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_tech" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_tech" '{"target":"'"$target"'"}')
    _route_result "nuclei_tech" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_tech || true

# --- Nuclei: Exposure detection ---
toolkit_nuclei_exposures() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_exposures" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_exposures" '{"target":"'"$target"'"}')
    _route_result "nuclei_exposures" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_exposures || true

# --- Nuclei: Misconfiguration detection ---
toolkit_nuclei_misconfigs() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "nuclei_misconfigs" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_misconfigs" '{"target":"'"$target"'"}')
    _route_result "nuclei_misconfigs" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_misconfigs || true

# --- Nuclei: Custom template scan ---
toolkit_nuclei_templates() {
    local target="$1"
    local template="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$template" ]] && { echo '{"error":"template required"}'; return 1; }
    _governance_check "nuclei_templates" "$target" || return 1
    local result=$(_toolkit_d3bugr "nuclei_templates" '{"target":"'"$target"'","template":"'"$template"'"}')
    _route_result "nuclei_templates" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_nuclei_templates || true

# --- Ffuf: Content discovery / fuzzing ---
toolkit_ffuf() {
    local url="$1"
    local wordlist="${2:-common}"
    [[ -z "$url" ]] && { echo '{"error":"url required"}'; return 1; }
    _governance_check "ffuf_scan" "$url" || return 1
    local result=$(_toolkit_d3bugr "ffuf_scan" '{"url":"'"$url"'","wordlist":"'"$wordlist"'"}')
    _route_result "ffuf_scan" "$result" "$url"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_ffuf || true

# --- Feroxbuster: Recursive content discovery ---
toolkit_feroxbuster() {
    local url="$1"
    local wordlist="${2:-common}"
    [[ -z "$url" ]] && { echo '{"error":"url required"}'; return 1; }
    _governance_check "feroxbuster_scan" "$url" || return 1
    local result=$(_toolkit_d3bugr "feroxbuster_scan" '{"url":"'"$url"'","wordlist":"'"$wordlist"'"}')
    _route_result "feroxbuster_scan" "$result" "$url"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_feroxbuster || true
