#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT DNS — Domain lookup, WHOIS, zone transfer, reverse, DNSSEC
#
# Service: dns (via d3bugr gateway)
# Tiers: 0 (lookup, whois, dnssec), 1 (reverse), 2 (zone_transfer)
#
# Usage: source toolkit/dns.sh (after _core.sh, _governance.sh, _output.sh)
# ═══════════════════════════════════════════════════════════════

# --- toolkit_dns_lookup DOMAIN [RECORD_TYPE] ---
# Tier 0: DNS record lookup (A, AAAA, MX, NS, TXT, CNAME, SOA, etc.)
toolkit_dns_lookup() {
    local domain="$1"
    local record_type="${2:-A}"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }

    _governance_check "dns_lookup" "$domain" || return 1

    local result
    result=$(_toolkit_post "dns" "/lookup" '{"domain":"'"$domain"'","record_type":"'"$record_type"'"}')
    _route_result "dns_lookup" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_dns_lookup || true

# --- toolkit_dns_whois DOMAIN ---
# Tier 0: WHOIS registration data for a domain
toolkit_dns_whois() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }

    _governance_check "dns_whois" "$domain" || return 1

    local result
    result=$(_toolkit_post "dns" "/whois" '{"domain":"'"$domain"'"}')
    _route_result "dns_whois" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_dns_whois || true

# --- toolkit_dns_zone_transfer DOMAIN ---
# Tier 2: Attempt AXFR zone transfer (requires VPN + scope check)
toolkit_dns_zone_transfer() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }

    _governance_check "dns_zone_transfer" "$domain" || return 1

    local result
    result=$(_toolkit_post "dns" "/zone-transfer" '{"domain":"'"$domain"'"}')
    _route_result "dns_zone_transfer" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_dns_zone_transfer || true

# --- toolkit_dns_reverse IP ---
# Tier 1: Reverse DNS lookup for an IP address
toolkit_dns_reverse() {
    local ip="$1"
    [[ -z "$ip" ]] && { echo '{"error":"ip required"}'; return 1; }

    _governance_check "dns_reverse" "$ip" || return 1

    local result
    result=$(_toolkit_post "dns" "/reverse" '{"ip":"'"$ip"'"}')
    _route_result "dns_reverse" "$result" "$ip"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_dns_reverse || true

# --- toolkit_dns_dnssec DOMAIN ---
# Tier 0: Check DNSSEC configuration for a domain
toolkit_dns_dnssec() {
    local domain="$1"
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }

    _governance_check "dns_dnssec" "$domain" || return 1

    local result
    result=$(_toolkit_post "dns" "/dnssec" '{"domain":"'"$domain"'"}')
    _route_result "dns_dnssec" "$result" "$domain"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_dns_dnssec || true
