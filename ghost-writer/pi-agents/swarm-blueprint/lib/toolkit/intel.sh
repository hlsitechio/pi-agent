#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT INTEL — Shodan IP, search, DNS, reverse DNS, CVE
#
# Service: Shodan API (direct) + d3bugr gateway (CVE)
# All Tier 0 (passive observation)
#
# Usage: source toolkit/intel.sh (after _core.sh, _governance.sh, _output.sh)
# ═══════════════════════════════════════════════════════════════

# --- toolkit_shodan_ip IP ---
# Tier 0: Full Shodan host report for an IP address
toolkit_shodan_ip() {
    local ip="$1"
    [[ -z "$ip" ]] && { echo '{"error":"ip required"}'; return 1; }

    _governance_check "shodan_ip" "$ip" || return 1

    local result
    result=$(_toolkit_call "GET" "https://api.shodan.io/shodan/host/${ip}?key=${TOOLKIT_SHODAN_KEY}" "")
    _route_result "shodan_ip" "$result" "$ip"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_shodan_ip || true

# --- toolkit_shodan_search QUERY ---
# Tier 0: Shodan search (query is URL-encoded)
toolkit_shodan_search() {
    local query="$1"
    [[ -z "$query" ]] && { echo '{"error":"query required"}'; return 1; }

    _governance_check "shodan_search" "$query" || return 1

    local encoded_query
    encoded_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))" 2>/dev/null)

    local result
    result=$(_toolkit_call "GET" "https://api.shodan.io/shodan/host/search?query=${encoded_query}&key=${TOOLKIT_SHODAN_KEY}" "")
    _route_result "shodan_search" "$result" "$query"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_shodan_search || true

# --- toolkit_shodan_dns DOMAIN ---
# Tier 0: Resolve domain to IP via Shodan DNS
toolkit_shodan_dns() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }

    _governance_check "shodan_dns" "$domain" || return 1

    local result
    result=$(_toolkit_call "GET" "https://api.shodan.io/dns/resolve?hostnames=${domain}&key=${TOOLKIT_SHODAN_KEY}" "")
    _route_result "shodan_dns" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_shodan_dns || true

# --- toolkit_shodan_reverse IP ---
# Tier 0: Reverse DNS lookup via Shodan
toolkit_shodan_reverse() {
    local ip="$1"
    [[ -z "$ip" ]] && { echo '{"error":"ip required"}'; return 1; }

    _governance_check "shodan_reverse" "$ip" || return 1

    local result
    result=$(_toolkit_call "GET" "https://api.shodan.io/dns/reverse?ips=${ip}&key=${TOOLKIT_SHODAN_KEY}" "")
    _route_result "shodan_reverse" "$result" "$ip"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_shodan_reverse || true

# --- toolkit_shodan_cve CVE_ID ---
# Tier 0: CVE details lookup via d3bugr gateway
toolkit_shodan_cve() {
    local cve_id="$1"
    [[ -z "$cve_id" ]] && { echo '{"error":"cve_id required"}'; return 1; }

    _governance_check "shodan_cve" "$cve_id" || return 1

    local result
    result=$(_toolkit_d3bugr "shodan_cve" '{"cve":"'"$cve_id"'"}')
    _route_result "shodan_cve" "$result" "$cve_id"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_shodan_cve || true
