#!/bin/bash
# D3BUGR Bridge — Call d3bugr MCP tools from shell scripts
# Usage: source d3bugr-bridge.sh
#
# This bridge allows Pi agents to access d3bugr security tools via HTTP API
# without needing direct MCP access.

D3BUGR_HOST="https://d3bugr-production.up.railway.app"

# === SUBDOMAIN ENUMERATION ===

d3bugr_subfinder() {
  local DOMAIN="$1"
  if [[ -z "$DOMAIN" ]]; then
    echo '{"error": "domain parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/subfinder_scan" \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$DOMAIN\"}" 2>/dev/null
}

# === HTTP PROBING ===

d3bugr_httpx() {
  local TARGETS="$1"  # comma-separated or newline-separated
  if [[ -z "$TARGETS" ]]; then
    echo '{"error": "targets parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/httpx_probe" \
    -H "Content-Type: application/json" \
    -d "{\"targets\": \"$TARGETS\"}" 2>/dev/null
}

# === VULNERABILITY SCANNING ===

d3bugr_nuclei() {
  local TARGET="$1"
  local SEVERITY="${2:-critical,high}"
  if [[ -z "$TARGET" ]]; then
    echo '{"error": "target parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/nuclei_scan" \
    -H "Content-Type: application/json" \
    -d "{\"target\": \"$TARGET\", \"severity\": \"$SEVERITY\"}" 2>/dev/null
}

d3bugr_nuclei_quick() {
  local TARGET="$1"
  if [[ -z "$TARGET" ]]; then
    echo '{"error": "target parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/nuclei_quick" \
    -H "Content-Type: application/json" \
    -d "{\"target\": \"$TARGET\"}" 2>/dev/null
}

# === PORT SCANNING ===

d3bugr_nmap() {
  local TARGET="$1"
  local PORTS="${2:-top-100}"
  if [[ -z "$TARGET" ]]; then
    echo '{"error": "target parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/nmap_scan" \
    -H "Content-Type: application/json" \
    -d "{\"target\": \"$TARGET\", \"ports\": \"$PORTS\"}" 2>/dev/null
}

d3bugr_nmap_quick() {
  local TARGET="$1"
  if [[ -z "$TARGET" ]]; then
    echo '{"error": "target parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/nmap_quick" \
    -H "Content-Type: application/json" \
    -d "{\"target\": \"$TARGET\"}" 2>/dev/null
}

# === XSS SCANNING ===

d3bugr_dalfox() {
  local URL="$1"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/dalfox_xss_scan" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\"}" 2>/dev/null
}

# === SQL INJECTION SCANNING ===

d3bugr_sqlmap() {
  local URL="$1"
  local LEVEL="${2:-1}"
  local RISK="${3:-1}"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/sqlmap_scan" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\", \"batch\": true, \"level\": $LEVEL, \"risk\": $RISK}" 2>/dev/null
}

d3bugr_sqlmap_test() {
  local URL="$1"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/sqlmap_test" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\"}" 2>/dev/null
}

# === DIRECTORY FUZZING ===

d3bugr_ffuf() {
  local URL="$1"
  local WORDLIST="${2:-common}"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/ffuf_scan" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\", \"wordlist\": \"$WORDLIST\"}" 2>/dev/null
}

d3bugr_feroxbuster() {
  local URL="$1"
  local WORDLIST="${2:-common}"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/feroxbuster_scan" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\", \"wordlist\": \"$WORDLIST\"}" 2>/dev/null
}

# === WEB CRAWLING ===

d3bugr_katana() {
  local URL="$1"
  local DEPTH="${2:-2}"
  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/katana_crawl" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\", \"depth\": $DEPTH}" 2>/dev/null
}

# === DNS ENUMERATION ===

d3bugr_dns_lookup() {
  local DOMAIN="$1"
  local RECORD_TYPE="${2:-A}"
  if [[ -z "$DOMAIN" ]]; then
    echo '{"error": "domain parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/dns_lookup" \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$DOMAIN\", \"record_type\": \"$RECORD_TYPE\"}" 2>/dev/null
}

d3bugr_dns_whois() {
  local DOMAIN="$1"
  if [[ -z "$DOMAIN" ]]; then
    echo '{"error": "domain parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/dns_whois" \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$DOMAIN\"}" 2>/dev/null
}

# === OSINT / HARVESTING ===

d3bugr_harvest() {
  local DOMAIN="$1"
  if [[ -z "$DOMAIN" ]]; then
    echo '{"error": "domain parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/harvest" \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$DOMAIN\"}" 2>/dev/null
}

d3bugr_harvest_quick() {
  local DOMAIN="$1"
  if [[ -z "$DOMAIN" ]]; then
    echo '{"error": "domain parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/harvest_quick" \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$DOMAIN\"}" 2>/dev/null
}

# === SHODAN INTEGRATION ===

d3bugr_shodan_ip() {
  local IP="$1"
  if [[ -z "$IP" ]]; then
    echo '{"error": "ip parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/shodan_ip_lookup" \
    -H "Content-Type: application/json" \
    -d "{\"ip\": \"$IP\"}" 2>/dev/null
}

d3bugr_shodan_search() {
  local QUERY="$1"
  if [[ -z "$QUERY" ]]; then
    echo '{"error": "query parameter required"}' >&2
    return 1
  fi
  curl -s "$D3BUGR_HOST/api/tools/shodan_search" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$QUERY\"}" 2>/dev/null
}

# === HEALTH CHECK ===

d3bugr_health() {
  local STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$D3BUGR_HOST/health" 2>/dev/null)
  echo "$STATUS_CODE"
}

d3bugr_status() {
  curl -s "$D3BUGR_HOST/health" 2>/dev/null
}

# === HELPER FUNCTIONS ===

d3bugr_list_tools() {
  curl -s "$D3BUGR_HOST/api/tools" 2>/dev/null
}

d3bugr_version() {
  curl -s "$D3BUGR_HOST/api/version" 2>/dev/null
}

# Export all functions for sourcing
export -f d3bugr_subfinder
export -f d3bugr_httpx
export -f d3bugr_nuclei
export -f d3bugr_nuclei_quick
export -f d3bugr_nmap
export -f d3bugr_nmap_quick
export -f d3bugr_dalfox
export -f d3bugr_sqlmap
export -f d3bugr_sqlmap_test
export -f d3bugr_ffuf
export -f d3bugr_feroxbuster
export -f d3bugr_katana
export -f d3bugr_dns_lookup
export -f d3bugr_dns_whois
export -f d3bugr_harvest
export -f d3bugr_harvest_quick
export -f d3bugr_shodan_ip
export -f d3bugr_shodan_search
export -f d3bugr_health
export -f d3bugr_status
export -f d3bugr_list_tools
export -f d3bugr_version
