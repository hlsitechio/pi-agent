#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT CORE — HTTP caller, retry, timeout, JSON helpers
#
# Foundation layer for the Manager Toolkit.
# All tool modules depend on this file.
#
# Usage: source toolkit/_core.sh
# ═══════════════════════════════════════════════════════════════

# --- Railway Service Endpoints ---
declare -A TOOLKIT_ENDPOINTS=(
    # Primary gateway (routes to subfinder, httpx, katana, dalfox, ffuf, feroxbuster, wfuzz, arjun)
    ["d3bugr"]="https://d3bugr-production.up.railway.app"

    # Direct services
    ["nmap"]="https://nmap-production.up.railway.app"
    ["nuclei"]="https://nuclei-production-d931.up.railway.app"
    ["sqlmap"]="https://sqlmap-api-production.up.railway.app"
    ["dns"]="https://dns-tools-api-production.up.railway.app"
    ["bhp"]="https://bhp-api-production.up.railway.app"
    ["harvester"]="https://theharvester-production.up.railway.app"
    ["argus"]="https://argus-recon-production.up.railway.app"
    ["geolock"]="https://geolock-production.up.railway.app"
    ["etb"]="https://etb-production.up.railway.app"
    ["cdp"]="https://cdp-exploitation-production.up.railway.app"
    ["cvedb"]="https://divine-frost-production.up.railway.app"

    # JSON-RPC services (use /mcp endpoint)
    ["winrm"]="https://d3bugr-winrm-production.up.railway.app"
    ["trufflehog"]="https://trufflehog-production.up.railway.app"
)

# --- Auth ---
TOOLKIT_D3BUGR_KEY="e9137843440efa3b1958bd743191813e"
TOOLKIT_SHODAN_KEY="wjBjiVbDDJgglKO0IIBOgdMKo2mvAdu8"

# --- Config ---
TOOLKIT_TIMEOUT="${TOOLKIT_TIMEOUT:-30}"
TOOLKIT_RETRIES="${TOOLKIT_RETRIES:-2}"
TOOLKIT_LOG_DIR="/mnt/bounty/Claude/pi-agents/manager/state/toolkit"
mkdir -p "$TOOLKIT_LOG_DIR" 2>/dev/null

# --- Core HTTP Caller ---
# _toolkit_call METHOD URL [DATA] [EXTRA_HEADERS...]
# Returns: JSON response or error JSON
_toolkit_call() {
    local method="$1"
    local url="$2"
    local data="$3"
    shift 3
    local extra_headers=("$@")

    local attempt=0
    local max_retries="$TOOLKIT_RETRIES"
    local start_ms
    local end_ms
    local duration_ms
    local http_code
    local response
    local tmpfile

    tmpfile=$(mktemp /tmp/toolkit-XXXXXX)

    while (( attempt <= max_retries )); do
        start_ms=$(date +%s%3N 2>/dev/null || date +%s)

        local curl_args=(
            -s -S
            --max-time "$TOOLKIT_TIMEOUT"
            -X "$method"
            -H "Content-Type: application/json"
            -w "%{http_code}"
            -o "$tmpfile"
        )

        # Add extra headers
        for hdr in "${extra_headers[@]}"; do
            curl_args+=(-H "$hdr")
        done

        # Add data for POST/PUT
        if [[ -n "$data" && ("$method" == "POST" || "$method" == "PUT" || "$method" == "PATCH") ]]; then
            curl_args+=(-d "$data")
        fi

        http_code=$(curl "${curl_args[@]}" "$url" 2>/dev/null)
        local curl_exit=$?

        end_ms=$(date +%s%3N 2>/dev/null || date +%s)
        duration_ms=$(( end_ms - start_ms ))

        if (( curl_exit == 0 )) && [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            response=$(cat "$tmpfile" 2>/dev/null)
            rm -f "$tmpfile"
            echo "$response"
            return 0
        fi

        attempt=$((attempt + 1))
        if (( attempt <= max_retries )); then
            sleep 1
        fi
    done

    # All retries failed
    response=$(cat "$tmpfile" 2>/dev/null)
    rm -f "$tmpfile"

    echo "{\"error\":\"HTTP $http_code after $((max_retries+1)) attempts\",\"url\":\"$url\",\"response\":$(echo "$response" | _json_escape_string),\"duration_ms\":$duration_ms}"
    return 1
}

# --- Convenience Wrappers ---

# _toolkit_post SERVICE ENDPOINT DATA [EXTRA_HEADERS...]
_toolkit_post() {
    local service="$1"
    local endpoint="$2"
    local data="$3"
    shift 3
    local base_url="${TOOLKIT_ENDPOINTS[$service]}"
    if [[ -z "$base_url" ]]; then
        echo "{\"error\":\"Unknown service: $service\"}"
        return 1
    fi
    _toolkit_call "POST" "${base_url}${endpoint}" "$data" "$@"
}

# _toolkit_get SERVICE ENDPOINT [EXTRA_HEADERS...]
_toolkit_get() {
    local service="$1"
    local endpoint="$2"
    shift 2
    local base_url="${TOOLKIT_ENDPOINTS[$service]}"
    if [[ -z "$base_url" ]]; then
        echo "{\"error\":\"Unknown service: $service\"}"
        return 1
    fi
    _toolkit_call "GET" "${base_url}${endpoint}" "" "$@"
}

# _toolkit_d3bugr ENDPOINT DATA
# Calls d3bugr gateway with auth header
_toolkit_d3bugr() {
    local endpoint="$1"
    local data="$2"
    _toolkit_post "d3bugr" "/api/tools/${endpoint}" "$data" "X-D3bugr-Key: $TOOLKIT_D3BUGR_KEY"
}

# --- JSON-RPC Caller ---
# _toolkit_jsonrpc SERVICE METHOD PARAMS_JSON
# For WinRM and TruffleHog services that use JSON-RPC 2.0 protocol
_toolkit_jsonrpc() {
    local service="$1"
    local method="$2"
    local params="$3"
    local rpc_id="${4:-1}"

    local payload
    payload=$(printf '{"jsonrpc":"2.0","method":"%s","params":%s,"id":%s}' "$method" "${params:-{}}" "$rpc_id")

    local base_url="${TOOLKIT_ENDPOINTS[$service]}"
    if [[ -z "$base_url" ]]; then
        echo "{\"error\":\"Unknown service: $service\"}"
        return 1
    fi

    local response
    response=$(_toolkit_call "POST" "${base_url}/mcp" "$payload")
    local exit_code=$?

    # Extract result from JSON-RPC response
    if (( exit_code == 0 )); then
        local result
        result=$(echo "$response" | python3 -c "import sys,json;r=json.load(sys.stdin);print(json.dumps(r.get('result',r)))" 2>/dev/null)
        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "$result"
        else
            echo "$response"
        fi
    else
        echo "$response"
    fi
    return $exit_code
}

# --- JSON Helpers ---

# _json_get KEY [JSON_INPUT]
# Extract a key from JSON using python3
_json_get() {
    local key="$1"
    local input="${2:-$(cat)}"
    echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = '$key'.split('.')
    for k in keys:
        if isinstance(d, dict):
            d = d.get(k)
        elif isinstance(d, list) and k.isdigit():
            d = d[int(k)]
        else:
            d = None
            break
    if d is not None:
        if isinstance(d, (dict, list)):
            print(json.dumps(d))
        else:
            print(d)
except:
    pass
" 2>/dev/null
}

# _json_valid [JSON_INPUT]
# Returns 0 if valid JSON, 1 otherwise
_json_valid() {
    local input="${1:-$(cat)}"
    echo "$input" | python3 -c "import sys,json;json.load(sys.stdin)" 2>/dev/null
    return $?
}

# _json_escape_string
# Escape a string for JSON embedding (reads stdin)
_json_escape_string() {
    python3 -c "import sys,json;print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '""'
}

# --- Result Standardizer ---
# _toolkit_result TOOL_NAME SUCCESS DATA [DURATION_MS]
_toolkit_result() {
    local tool="$1"
    local success="$2"
    local data="$3"
    local duration_ms="${4:-0}"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Validate data is JSON, wrap if not
    if ! echo "$data" | _json_valid 2>/dev/null; then
        data="{\"raw\":$(echo "$data" | _json_escape_string)}"
    fi

    printf '{"tool":"%s","success":%s,"data":%s,"timestamp":"%s","duration_ms":%s}\n' \
        "$tool" "$success" "$data" "$timestamp" "$duration_ms"
}

# --- Health Check ---
# _toolkit_health SERVICE
# Quick health check for a Railway service
_toolkit_health() {
    local service="$1"
    local base_url="${TOOLKIT_ENDPOINTS[$service]}"
    if [[ -z "$base_url" ]]; then
        echo "UNKNOWN"
        return 1
    fi

    local http_code
    http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 5 "${base_url}/health" 2>/dev/null)
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo "UP"
        return 0
    else
        echo "DOWN:${http_code}"
        return 1
    fi
}

# --- Logging ---
_toolkit_log() {
    local level="$1"
    shift
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [TOOLKIT] [$level] $*" >> "$TOOLKIT_LOG_DIR/toolkit.log" 2>/dev/null
}

# Export all core functions
[[ -n "${BASH_VERSION:-}" ]] && export -f _toolkit_call _toolkit_post _toolkit_get _toolkit_d3bugr || true
[[ -n "${BASH_VERSION:-}" ]] && export -f _toolkit_jsonrpc || true
[[ -n "${BASH_VERSION:-}" ]] && export -f _json_get _json_valid _json_escape_string || true
[[ -n "${BASH_VERSION:-}" ]] && export -f _toolkit_result _toolkit_health _toolkit_log || true
