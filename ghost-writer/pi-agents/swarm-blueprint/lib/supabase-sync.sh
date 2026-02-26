#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# SUPABASE SYNC LIBRARY — Persistence layer for swarm state
# Sourced by chiefs and manager to write state to Supabase
# All writes go through Supabase REST API (no extra deps)
# ═══════════════════════════════════════════════════════════════

# --- Config ---
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_KEY:-}"
SUPABASE_SYNC_ENABLED=false

# Chief UUID lookup (populated from DB seed)
declare -A CHIEF_IDS=(
    ["ops-chief"]="4e161db3-547e-4aed-bd56-05858d51e190"
    ["intel-chief"]="fa28f07d-94ef-4886-84c2-5b6b2045a4fa"
    ["recon-chief"]="22ce70a2-36a3-4339-b30b-c28b482f9006"
    ["hunter-chief"]="ff83b813-5de3-4bdf-bd6d-4b95fca198e5"
    ["analytics-chief"]="5876b811-536f-48d9-bd2d-90cf0164ed67"
    ["content-chief"]="1016eec6-614c-463e-89bc-dcf5bb88adb0"
)

# Auto-detect from env or config file
_supabase_init() {
    if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_KEY" ]]; then
        SUPABASE_SYNC_ENABLED=true
        return 0
    fi

    local config="/mnt/bounty/Claude/pi-agents/swarm-blueprint/supabase-config.env"
    if [[ -f "$config" ]]; then
        source "$config"
        if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_KEY" ]]; then
            SUPABASE_SYNC_ENABLED=true
            return 0
        fi
    fi

    return 1
}

# --- Helpers ---

# JSON-escape a string safely
_json_escape() {
    python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null || echo '""'
}

# --- Core API ---

# POST/PATCH to Supabase REST API
_supabase_api() {
    local method="$1"
    local endpoint="$2"
    local body="$3"
    local extra_headers="${4:-}"

    [[ "$SUPABASE_SYNC_ENABLED" != "true" ]] && return 0

    local -a headers=(
        -H "apikey: $SUPABASE_KEY"
        -H "Authorization: Bearer $SUPABASE_KEY"
        -H "Content-Type: application/json"
        -H "Prefer: return=minimal"
    )

    [[ -n "$extra_headers" ]] && headers+=(-H "$extra_headers")

    # Fire and forget with 5s timeout — never block the agent
    timeout 5 curl -s -X "$method" \
        "${SUPABASE_URL}${endpoint}" \
        "${headers[@]}" \
        -d "$body" 2>/dev/null || true
}

# --- Chief Operations ---
# Schema: chief_runs(id, chief_id, started_at, ended_at, duration_ms, status,
#          sub_agent_results jsonb, ai_briefing text, findings_count int,
#          actions_taken text[], errors text[], metadata jsonb)

# Record a chief run
# Status: running|success|partial|failed|timeout
# Usage: supabase_log_chief_run "ops-chief" "success" 120000 3 "All systems nominal" '{"check1":"ok"}' "restart_ollama,check_vpn" "error1"
supabase_log_chief_run() {
    local chief_name="$1"
    local run_status="${2:-success}"
    local duration_ms="${3:-0}"
    local findings_count="${4:-0}"
    local ai_briefing="${5:-}"
    local sub_agent_results="${6:-"{}"}"
    local actions_csv="${7:-}"    # Comma-separated actions
    local errors_csv="${8:-}"    # Comma-separated errors

    local chief_id="${CHIEF_IDS[$chief_name]:-}"
    [[ -z "$chief_id" ]] && return 1

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local briefing_escaped
    briefing_escaped=$(echo "$ai_briefing" | _json_escape)

    # Convert CSV to JSON array for PostgREST: ["item1","item2"]
    local json_actions="[]"
    if [[ -n "$actions_csv" ]]; then
        json_actions="[$(echo "$actions_csv" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"
    fi
    local json_errors="[]"
    if [[ -n "$errors_csv" ]]; then
        json_errors="[$(echo "$errors_csv" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"
    fi

    local body
    body=$(cat <<ENDJSON
{
    "chief_id": "$chief_id",
    "started_at": "$now",
    "ended_at": "$now",
    "duration_ms": $duration_ms,
    "status": "$run_status",
    "sub_agent_results": $sub_agent_results,
    "ai_briefing": $briefing_escaped,
    "findings_count": $findings_count,
    "actions_taken": $json_actions,
    "errors": $json_errors,
    "metadata": {}
}
ENDJSON
)
    _supabase_api "POST" "/rest/v1/chief_runs" "$body"
}

# Update chief health + last_run + last_briefing
# Usage: supabase_update_chief "ops-chief" 95 "All systems green"
supabase_update_chief() {
    local chief_name="$1"
    local health_score="${2:-100}"
    local last_briefing="${3:-}"

    local briefing_escaped
    briefing_escaped=$(echo "$last_briefing" | _json_escape)
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local body
    body=$(cat <<ENDJSON
{
    "health_score": $health_score,
    "last_run_at": "$now",
    "last_briefing": $briefing_escaped,
    "updated_at": "$now"
}
ENDJSON
)
    _supabase_api "PATCH" "/rest/v1/chiefs?name=eq.$chief_name" "$body"
}

# --- Agent Operations ---
# Schema: swarm_agents(id, name, agent_type, division, tier, is_ai, status,
#          last_run_at, last_exit_code, last_output_summary, run_count, fail_count,
#          uptime_pct, script_path, schedule, config jsonb)

# Update agent after a run
# Usage: supabase_update_agent "cve-monitor" 0 "2 CVEs found"
supabase_update_agent() {
    local agent_name="$1"
    local exit_code="${2:-0}"
    local output_summary="${3:-}"

    local summary_escaped
    summary_escaped=$(echo "$output_summary" | _json_escape)
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local body
    body=$(cat <<ENDJSON
{
    "last_run_at": "$now",
    "last_exit_code": $exit_code,
    "last_output_summary": $summary_escaped,
    "updated_at": "$now"
}
ENDJSON
)
    _supabase_api "PATCH" "/rest/v1/swarm_agents?name=eq.$agent_name" "$body"
}

# Mark agent as errored
supabase_agent_error() {
    local agent_name="$1"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _supabase_api "PATCH" "/rest/v1/swarm_agents?name=eq.$agent_name" \
        "{\"status\":\"error\",\"last_exit_code\":1,\"updated_at\":\"$now\"}"
}

# Mark agent back to active
supabase_agent_active() {
    local agent_name="$1"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _supabase_api "PATCH" "/rest/v1/swarm_agents?name=eq.$agent_name" \
        "{\"status\":\"active\",\"updated_at\":\"$now\"}"
}

# --- Heartbeat Metrics ---
# Schema: heartbeat_metrics(id, recorded_at, cpu_pct, mem_pct, disk_pct, load_avg,
#          agents_up, agents_warn, agents_down, agents_new, agents_total,
#          vpn_connected, ollama_up, d3bugr_up, health_score, severity, metadata)

# Record heartbeat snapshot
# Usage: supabase_heartbeat 15.2 42.1 67.3 1.5 21 3 0 5 29 true true true 92 "GREEN"
supabase_heartbeat() {
    local cpu="${1:-0}" mem="${2:-0}" disk="${3:-0}" load="${4:-0}"
    local up="${5:-0}" warn="${6:-0}" down="${7:-0}" new="${8:-0}" total="${9:-0}"
    local vpn="${10:-true}" ollama="${11:-true}" d3bugr="${12:-true}"
    local score="${13:-100}" severity="${14:-GREEN}"

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local body
    body=$(cat <<ENDJSON
{
    "recorded_at": "$now",
    "cpu_pct": $cpu,
    "mem_pct": $mem,
    "disk_pct": $disk,
    "load_avg": $load,
    "agents_up": $up,
    "agents_warn": $warn,
    "agents_down": $down,
    "agents_new": $new,
    "agents_total": $total,
    "vpn_connected": $vpn,
    "ollama_up": $ollama,
    "d3bugr_up": $d3bugr,
    "health_score": $score,
    "severity": "$severity",
    "metadata": {}
}
ENDJSON
)
    _supabase_api "POST" "/rest/v1/heartbeat_metrics" "$body"
}

# --- Findings ---
# Schema: findings(id, source_chief, source_agent, finding_type, severity, title,
#          description, target, evidence jsonb, status, bounty_estimate, metadata, created_at)

# Record a finding
# Usage: supabase_log_finding "CVE-2026-3046" "cve" "intel-chief" "cve-monitor" "critical" "" "target.com" '{"cvss":7.3}' 500
supabase_log_finding() {
    local title="$1"
    local finding_type="$2"
    local source_chief="$3"
    local source_agent="${4:-}"
    local severity="$5"
    local description="${6:-}"
    local target="${7:-}"
    local evidence_json="${8:-"{}"}"
    local bounty_estimate="${9:-0}"

    local title_escaped desc_escaped
    title_escaped=$(echo "$title" | _json_escape)
    desc_escaped=$(echo "$description" | _json_escape)

    local body
    body=$(cat <<ENDJSON
{
    "title": $title_escaped,
    "finding_type": "$finding_type",
    "source_chief": "$source_chief",
    "source_agent": "$source_agent",
    "severity": "$severity",
    "description": $desc_escaped,
    "target": "$target",
    "evidence": $evidence_json,
    "status": "new",
    "bounty_estimate": $bounty_estimate,
    "metadata": {}
}
ENDJSON
)
    _supabase_api "POST" "/rest/v1/findings" "$body"
}

# --- Incidents ---
# Schema: incidents(id, incident_id, classification, lifecycle, reporter, title,
#          details, actions_taken text[], resolved_at, auto_resolved, metadata)

# Record an incident
# Usage: supabase_log_incident "INC-20260224-001" "security" "ops-chief" "VPN Down" "VPN disconnected during scan" "reconnect_vpn,alert_discord"
supabase_log_incident() {
    local incident_id="$1"
    local classification="$2"
    local reporter="$3"
    local title="$4"
    local details="$5"
    local actions_csv="${6:-}"

    local title_escaped details_escaped
    title_escaped=$(echo "$title" | _json_escape)
    details_escaped=$(echo "$details" | _json_escape)

    local json_actions="[]"
    if [[ -n "$actions_csv" ]]; then
        json_actions="[$(echo "$actions_csv" | sed 's/,/","/g' | sed 's/^/"/;s/$/"/')]"
    fi

    local body
    body=$(cat <<ENDJSON
{
    "incident_id": "$incident_id",
    "classification": "$classification",
    "lifecycle": "new",
    "reporter": "$reporter",
    "title": $title_escaped,
    "details": $details_escaped,
    "actions_taken": $json_actions,
    "auto_resolved": false,
    "metadata": {}
}
ENDJSON
)
    _supabase_api "POST" "/rest/v1/incidents" "$body"
}

# Resolve an incident
supabase_resolve_incident() {
    local incident_id="$1"
    local auto="${2:-false}"
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _supabase_api "PATCH" "/rest/v1/incidents?incident_id=eq.$incident_id" \
        "{\"lifecycle\":\"resolved\",\"resolved_at\":\"$now\",\"auto_resolved\":$auto,\"updated_at\":\"$now\"}"
}

# --- Memory Snapshots ---
# Schema: memory_snapshots(id, snapshot_type, session_path, content, content_hash, metadata)

# Backup state.md or .mci to Supabase
# Usage: supabase_snapshot_memory "state" "/path/to/state.md" "/path/to/session/"
supabase_snapshot_memory() {
    local snapshot_type="$1"
    local file_path="$2"
    local session_path="${3:-}"

    [[ ! -f "$file_path" ]] && return 1

    local content content_hash content_escaped
    content=$(cat "$file_path" 2>/dev/null)
    content_hash=$(echo "$content" | md5sum | cut -d' ' -f1)
    content_escaped=$(echo "$content" | _json_escape)

    local body
    body=$(cat <<ENDJSON
{
    "snapshot_type": "$snapshot_type",
    "session_path": "$session_path",
    "content": $content_escaped,
    "content_hash": "$content_hash",
    "metadata": {"file_path": "$file_path", "hostname": "$(hostname)"}
}
ENDJSON
)
    _supabase_api "POST" "/rest/v1/memory_snapshots" "$body"
}

# --- Init on source ---
_supabase_init
