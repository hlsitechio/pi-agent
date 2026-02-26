#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT RECON — Subdomain enum, HTTP probing, crawling, OSINT
#
# Tier 2 recon tools: subfinder, httpx, katana, theHarvester, Argus
# All functions require VPN + scope check via governance.
#
# Dependencies: _core.sh, _governance.sh, _output.sh
# Usage: source toolkit/recon.sh
# ═══════════════════════════════════════════════════════════════

# --- Subfinder: Subdomain enumeration ---
toolkit_subfinder() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "subfinder_scan" "$domain" || return 1
    local result=$(_toolkit_d3bugr "subfinder_scan" '{"domain":"'"$domain"'"}')
    _route_result "subfinder_scan" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_subfinder || true

# --- Httpx: HTTP probing ---
toolkit_httpx() {
    local targets="$1"
    [[ -z "$targets" ]] && { echo '{"error":"targets required (comma-separated)"}'; return 1; }
    _governance_check "httpx_probe" "$targets" || return 1
    local result=$(_toolkit_d3bugr "httpx_probe" '{"targets":"'"$targets"'"}')
    _route_result "httpx_probe" "$result" "$targets"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_httpx || true

# --- Katana: Web crawler ---
toolkit_katana() {
    local url="$1"
    local depth="${2:-2}"
    [[ -z "$url" ]] && { echo '{"error":"url required"}'; return 1; }
    _governance_check "katana_crawl" "$url" || return 1
    local result=$(_toolkit_d3bugr "katana_crawl" '{"url":"'"$url"'","depth":'"$depth"'}')
    _route_result "katana_crawl" "$result" "$url"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_katana || true

# --- theHarvester: Full harvest ---
toolkit_harvest() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "harvest" "$domain" || return 1
    local result=$(_toolkit_d3bugr "harvest" '{"domain":"'"$domain"'"}')
    _route_result "harvest" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_harvest || true

# --- theHarvester: Quick harvest ---
toolkit_harvest_quick() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "harvest_quick" "$domain" || return 1
    local result=$(_toolkit_d3bugr "harvest_quick" '{"domain":"'"$domain"'"}')
    _route_result "harvest_quick" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_harvest_quick || true

# --- theHarvester: Subdomain enumeration ---
toolkit_harvest_subdomains() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "harvest_subdomains" "$domain" || return 1
    local result=$(_toolkit_d3bugr "harvest_subdomains" '{"domain":"'"$domain"'"}')
    _route_result "harvest_subdomains" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_harvest_subdomains || true

# --- theHarvester: Email enumeration ---
toolkit_harvest_emails() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "harvest_emails" "$domain" || return 1
    local result=$(_toolkit_d3bugr "harvest_emails" '{"domain":"'"$domain"'"}')
    _route_result "harvest_emails" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_harvest_emails || true

# --- Argus: Full recon run ---
toolkit_argus_run() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "argus_run" "$domain" || return 1
    local result=$(_toolkit_d3bugr "argus_run" '{"domain":"'"$domain"'"}')
    _route_result "argus_run" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_run || true

# --- Argus: Bulk domain recon ---
toolkit_argus_bulk() {
    local domains="$1"
    [[ -z "$domains" ]] && { echo '{"error":"domains required (comma-separated)"}'; return 1; }
    _governance_check "argus_bulk" "$domains" || return 1
    local result=$(_toolkit_d3bugr "argus_bulk" '{"domains":"'"$domains"'"}')
    _route_result "argus_bulk" "$result" "$domains"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_bulk || true

# --- Argus: Subdomain enumeration ---
toolkit_argus_subdomain() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "argus_subdomain" "$domain" || return 1
    local result=$(_toolkit_d3bugr "argus_subdomain" '{"domain":"'"$domain"'"}')
    _route_result "argus_subdomain" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_subdomain || true

# --- Argus: DNS records ---
toolkit_argus_dns() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "argus_dns" "$domain" || return 1
    local result=$(_toolkit_d3bugr "argus_dns" '{"domain":"'"$domain"'"}')
    _route_result "argus_dns" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_dns || true

# --- Argus: WHOIS lookup ---
toolkit_argus_whois() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "argus_whois" "$domain" || return 1
    local result=$(_toolkit_d3bugr "argus_whois" '{"domain":"'"$domain"'"}')
    _route_result "argus_whois" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_whois || true

# --- Argus: SSL certificate analysis ---
toolkit_argus_ssl() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "argus_ssl" "$domain" || return 1
    local result=$(_toolkit_d3bugr "argus_ssl" '{"domain":"'"$domain"'"}')
    _route_result "argus_ssl" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_ssl || true

# --- Argus: HTTP header analysis ---
toolkit_argus_headers() {
    local url="$1"
    [[ -z "$url" ]] && { echo '{"error":"url required"}'; return 1; }
    _governance_check "argus_headers" "$url" || return 1
    local result=$(_toolkit_d3bugr "argus_headers" '{"url":"'"$url"'"}')
    _route_result "argus_headers" "$result" "$url"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_headers || true

# --- Argus: Port scanning ---
toolkit_argus_ports() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "argus_ports" "$target" || return 1
    local result=$(_toolkit_d3bugr "argus_ports" '{"target":"'"$target"'"}')
    _route_result "argus_ports" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_argus_ports || true
