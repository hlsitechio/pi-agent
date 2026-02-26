#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT OUTPUT — Result routing: local JSON + Supabase + Discord
#
# Routes tool results to:
# 1. Local JSON file (always)
# 2. Supabase tool_results table (if configured)
# 3. Discord webhook summary (if configured)
#
# Usage: source toolkit/_output.sh (after _core.sh and _governance.sh)
# ═══════════════════════════════════════════════════════════════

OUTPUT_DIR="/mnt/bounty/Claude/pi-agents/manager/state/toolkit/results"
mkdir -p "$OUTPUT_DIR" 2>/dev/null

# Discord webhook for tool results (uses manager's cmd-center webhook)
TOOLKIT_DISCORD_WH="${TOOLKIT_DISCORD_WH:-}"

# --- Route Result ---
# _route_result TOOL_NAME RESULT_JSON [TARGET]
# Saves locally, posts to Supabase + Discord
_route_result() {
    local tool_name="$1"
    local result_json="$2"
    local target="${3:-}"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local date_dir
    date_dir=$(date -u +%Y-%m-%d)

    # 1. Save locally
    local result_dir="$OUTPUT_DIR/$date_dir"
    mkdir -p "$result_dir" 2>/dev/null
    local filename="${tool_name}_$(date -u +%H%M%S)_${target//[^a-zA-Z0-9._-]/_}.json"
    echo "$result_json" > "$result_dir/$filename" 2>/dev/null

    # 2. Post to Supabase (async, don't block)
    _route_supabase "$tool_name" "$result_json" "$target" "$timestamp" &

    # 3. Post Discord summary (async, don't block)
    if [[ -n "$TOOLKIT_DISCORD_WH" ]]; then
        _route_discord "$tool_name" "$result_json" "$target" &
    fi

    _toolkit_log "OUTPUT" "Routed result for $tool_name → $result_dir/$filename"
}

# --- Supabase Insert ---
_route_supabase() {
    local tool_name="$1"
    local result_json="$2"
    local target="${3:-}"
    local timestamp="${4:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

    # Source Supabase config if needed
    if [[ -z "$SUPABASE_URL" ]]; then
        source /mnt/bounty/Claude/pi-agents/swarm-blueprint/supabase-config.env 2>/dev/null
    fi
    [[ -z "$SUPABASE_URL" ]] && return 1

    local success
    success=$(echo "$result_json" | _json_get "success" 2>/dev/null)
    [[ -z "$success" ]] && success="true"

    local payload
    payload=$(python3 -c "
import json, sys
result = json.loads('''$result_json''') if '''$result_json'''.strip() else {}
print(json.dumps({
    'tool_name': '$tool_name',
    'target': '$target' or None,
    'success': $success if '$success' in ('true','false') else True,
    'result': result,
    'agent': '${AGENT_NAME:-manager}',
    'created_at': '$timestamp'
}))
" 2>/dev/null)

    [[ -z "$payload" ]] && return 1

    curl -sf \
        -X POST \
        -H "apikey: $SUPABASE_KEY" \
        -H "Authorization: Bearer $SUPABASE_KEY" \
        -H "Content-Type: application/json" \
        -H "Prefer: return=minimal" \
        "${SUPABASE_URL}/rest/v1/tool_results" \
        -d "$payload" 2>/dev/null

    return $?
}

# --- Discord Summary ---
_route_discord() {
    local tool_name="$1"
    local result_json="$2"
    local target="${3:-}"

    local summary
    summary=$(_format_discord_summary "$tool_name" "$result_json" "$target")

    [[ -z "$summary" ]] && return 1

    curl -sf \
        -X POST \
        -H "Content-Type: application/json" \
        "$TOOLKIT_DISCORD_WH" \
        -d "{\"content\":\"$summary\"}" 2>/dev/null

    return $?
}

# --- Format Discord Summary ---
# Truncates to 1950 chars, extracts key findings
_format_discord_summary() {
    local tool_name="$1"
    local result_json="$2"
    local target="${3:-}"

    python3 -c "
import json, sys

tool = '$tool_name'
target = '$target'
try:
    data = json.loads('''$result_json''')
except:
    data = {'raw': 'Parse error'}

# Build header
header = f'🔧 **{tool}**'
if target:
    header += f' → \`{target}\`'

# Extract key info based on common patterns
lines = [header]
success = data.get('success', True)
if not success:
    lines.append('❌ **FAILED**')
    error = data.get('error', data.get('data', {}).get('error', 'Unknown'))
    lines.append(f'Error: {error}')
else:
    lines.append('✅ **OK**')
    # Try to extract meaningful data
    inner = data.get('data', data)
    if isinstance(inner, dict):
        for key in ['findings', 'results', 'hosts', 'subdomains', 'vulnerabilities', 'ports', 'records']:
            val = inner.get(key)
            if val:
                if isinstance(val, list):
                    lines.append(f'{key}: **{len(val)}** found')
                    for item in val[:3]:
                        if isinstance(item, dict):
                            lines.append(f'  • {json.dumps(item)[:100]}')
                        else:
                            lines.append(f'  • {str(item)[:100]}')
                elif isinstance(val, (int, float)):
                    lines.append(f'{key}: **{val}**')

summary = chr(10).join(lines)

# Truncate to 1950 chars (Discord 2000 limit minus safety margin)
if len(summary) > 1950:
    summary = summary[:1947] + '...'

# Escape for JSON
print(summary.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"').replace(chr(10), '\\\\n'))
" 2>/dev/null
}

# Export functions
[[ -n "${BASH_VERSION:-}" ]] && export -f _route_result _route_supabase _route_discord _format_discord_summary || true
