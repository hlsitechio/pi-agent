#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT MODULE: ETB — Exposed Token Bucket scanner
#
# 3 functions, all Tier 1 (monitor). Scans for exposed tokens,
# secrets, and API keys in target assets.
#
# Dependencies: _core.sh, _governance.sh, _output.sh
# Gateway: d3bugr (ETB endpoints)
# ═══════════════════════════════════════════════════════════════

# toolkit_etb_scan TARGET — Scan a single target for exposed tokens
toolkit_etb_scan() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "etb_scan" "$target" || return 1
    local result
    result=$(_toolkit_d3bugr "etb_scan" "{\"target\":\"$target\"}")
    _route_result "etb_scan" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_etb_scan || true

# toolkit_etb_batch TARGETS — Batch scan comma-separated targets
toolkit_etb_batch() {
    local targets="$1"
    [[ -z "$targets" ]] && { echo '{"error":"targets required"}'; return 1; }
    _governance_check "etb_batch" "$targets" || return 1
    local result
    result=$(_toolkit_d3bugr "etb_batch" "{\"targets\":\"$targets\"}")
    _route_result "etb_batch" "$result" "$targets"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_etb_batch || true

# toolkit_etb_results SCAN_ID — Retrieve results for a scan
toolkit_etb_results() {
    local scan_id="$1"
    [[ -z "$scan_id" ]] && { echo '{"error":"scan_id required"}'; return 1; }
    _governance_check "etb_results" "$scan_id" || return 1
    local result
    result=$(_toolkit_d3bugr "etb_results" "{\"scan_id\":\"$scan_id\"}")
    _route_result "etb_results" "$result" "$scan_id"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_etb_results || true
