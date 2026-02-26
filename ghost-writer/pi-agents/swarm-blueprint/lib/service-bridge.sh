#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SERVICE BRIDGE — Railway + Supabase query helpers for chiefs
# Source this from any chief's run.sh for service management tools.
#
# Usage: source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/service-bridge.sh
#
# Provides:
#   railway_service_status  — Check Railway deployment status
#   railway_service_logs    — Get recent logs from Railway
#   supabase_query          — Read-only PostgREST query
#   supabase_list_tables    — List available tables
#   supabase_count          — Count rows in a table
#   service_health_check    — Probe any HTTP endpoint
# ═══════════════════════════════════════════════════════════════

# --- Railway Config ---
RAILWAY_API_TOKEN="${RAILWAY_API_TOKEN:-}"
RAILWAY_API_URL="https://backboard.railway.app/graphql/v2"

# Auto-detect Railway token
_railway_init() {
  if [[ -n "$RAILWAY_API_TOKEN" ]]; then
    return 0
  fi

  local config="/mnt/bounty/Claude/pi-agents/swarm-blueprint/railway-config.env"
  if [[ -f "$config" ]]; then
    source "$config"
    [[ -n "$RAILWAY_API_TOKEN" ]] && return 0
  fi

  return 1
}

# --- Supabase Config (for queries — writes use supabase-sync.sh) ---
# Re-uses SUPABASE_URL and SUPABASE_KEY if supabase-sync.sh was sourced first
_supabase_query_init() {
  if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_KEY:-}" ]]; then
    return 0
  fi

  local config="/mnt/bounty/Claude/pi-agents/swarm-blueprint/supabase-config.env"
  if [[ -f "$config" ]]; then
    source "$config"
    [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_KEY:-}" ]] && return 0
  fi

  return 1
}

# ═══════════════════════════════════════
# RAILWAY TOOLS
# ═══════════════════════════════════════

# Check Railway service deployment status
# Usage: railway_service_status [service_id]
railway_service_status() {
  local SERVICE_ID="${1:-}"
  _railway_init || { echo '{"error": "no Railway token configured"}'; return 1; }

  if [[ -z "$SERVICE_ID" ]]; then
    # Default: query all services in the project
    local QUERY='{"query":"{ me { projects(first: 5) { edges { node { id name services(first: 10) { edges { node { id name updatedAt } } } } } } } }"}'
  else
    local QUERY="{\"query\":\"{ service(id: \\\"$SERVICE_ID\\\") { id name updatedAt deployments(first: 3) { edges { node { id status createdAt } } } } }\"}"
  fi

  curl -s --max-time 10 "$RAILWAY_API_URL" \
    -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$QUERY" 2>/dev/null || echo '{"error": "Railway API unreachable"}'
}

# Get recent logs from a Railway service
# Usage: railway_service_logs <service_id> [limit]
railway_service_logs() {
  local SERVICE_ID="$1"
  local LIMIT="${2:-50}"

  _railway_init || { echo '{"error": "no Railway token configured"}'; return 1; }

  if [[ -z "$SERVICE_ID" ]]; then
    echo '{"error": "service_id parameter required"}'
    return 1
  fi

  local QUERY="{\"query\":\"{ deployments(serviceId: \\\"$SERVICE_ID\\\", first: 1) { edges { node { id status staticUrl buildLogs(limit: $LIMIT) } } } }\"}"

  curl -s --max-time 15 "$RAILWAY_API_URL" \
    -H "Authorization: Bearer $RAILWAY_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$QUERY" 2>/dev/null || echo '{"error": "Railway API unreachable"}'
}

# ═══════════════════════════════════════
# SUPABASE QUERY TOOLS (read-only)
# ═══════════════════════════════════════

# PostgREST query — read-only table access
# Usage: supabase_query <table> [filter] [select] [limit]
# Examples:
#   supabase_query "chief_runs" "chief_id=eq.ops-chief" "id,status,started_at" "10"
#   supabase_query "chiefs" "" "*" "50"
supabase_query() {
  local TABLE="$1"
  local FILTER="${2:-}"
  local SELECT="${3:-*}"
  local LIMIT="${4:-25}"

  _supabase_query_init || { echo '{"error": "no Supabase config"}'; return 1; }

  if [[ -z "$TABLE" ]]; then
    echo '{"error": "table parameter required"}'
    return 1
  fi

  local URL="${SUPABASE_URL}/rest/v1/${TABLE}?select=${SELECT}&limit=${LIMIT}"
  [[ -n "$FILTER" ]] && URL="${URL}&${FILTER}"

  curl -s --max-time 10 "$URL" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Accept: application/json" \
    2>/dev/null || echo '{"error": "Supabase API unreachable"}'
}

# List all tables (via introspection)
# Usage: supabase_list_tables
supabase_list_tables() {
  _supabase_query_init || { echo '{"error": "no Supabase config"}'; return 1; }

  # Use PostgREST root endpoint which returns OpenAPI spec with table names
  local SPEC
  SPEC=$(curl -s --max-time 10 "${SUPABASE_URL}/rest/v1/" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    2>/dev/null) || { echo '{"error": "Supabase unreachable"}'; return 1; }

  # Extract table names from OpenAPI paths
  echo "$SPEC" | python3 -c "
import json, sys
try:
    spec = json.load(sys.stdin)
    paths = spec.get('paths', {})
    tables = sorted([p.strip('/') for p in paths.keys() if p.strip('/') and not p.startswith('/rpc')])
    print(json.dumps({'tables': tables, 'count': len(tables)}))
except:
    print('{\"tables\": [], \"error\": \"parse_failed\"}')" 2>/dev/null
}

# Count rows in a table
# Usage: supabase_count <table> [filter]
supabase_count() {
  local TABLE="$1"
  local FILTER="${2:-}"

  _supabase_query_init || { echo '{"error": "no Supabase config"}'; return 1; }

  local URL="${SUPABASE_URL}/rest/v1/${TABLE}?select=count"
  [[ -n "$FILTER" ]] && URL="${URL}&${FILTER}"

  curl -s --max-time 10 "$URL" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Accept: application/json" \
    -H "Prefer: count=exact" \
    -I 2>/dev/null | grep -i "content-range" | awk -F'/' '{print $2}' || echo "0"
}

# ═══════════════════════════════════════
# GENERIC HEALTH CHECK
# ═══════════════════════════════════════

# Probe any HTTP endpoint and return status
# Usage: service_health_check <url> [timeout_secs]
service_health_check() {
  local URL="$1"
  local TIMEOUT="${2:-10}"

  if [[ -z "$URL" ]]; then
    echo '{"error": "url parameter required"}'
    return 1
  fi

  local HTTP_CODE RESPONSE_TIME
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>/dev/null || echo "000")
  RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time "$TIMEOUT" "$URL" 2>/dev/null || echo "0")

  local STATUS="unknown"
  case "$HTTP_CODE" in
    200|201|204) STATUS="healthy" ;;
    000)         STATUS="down" ;;
    5*)          STATUS="error" ;;
    4*)          STATUS="client_error" ;;
    3*)          STATUS="redirect" ;;
    *)           STATUS="degraded" ;;
  esac

  echo "{\"url\":\"$URL\",\"status\":\"$STATUS\",\"http_code\":\"$HTTP_CODE\",\"response_time\":\"${RESPONSE_TIME}s\"}"
}

# ═══════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════

export -f railway_service_status 2>/dev/null || true
export -f railway_service_logs 2>/dev/null || true
export -f supabase_query 2>/dev/null || true
export -f supabase_list_tables 2>/dev/null || true
export -f supabase_count 2>/dev/null || true
export -f service_health_check 2>/dev/null || true
