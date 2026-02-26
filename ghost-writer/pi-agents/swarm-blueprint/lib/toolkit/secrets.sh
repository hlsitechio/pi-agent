#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT SECRETS — TruffleHog secret scanning (GitHub, S3, Docker, Postman)
#
# Service: trufflehog (JSON-RPC via /mcp endpoint)
# All Tier 0 (passive observation)
#
# Usage: source toolkit/secrets.sh (after _core.sh, _governance.sh, _output.sh)
# ═══════════════════════════════════════════════════════════════

# --- toolkit_trufflehog_github REPO_URL ---
# Tier 0: Scan a GitHub repository for leaked secrets
toolkit_trufflehog_github() {
    local repo="$1"
    [[ -z "$repo" ]] && { echo '{"error":"repo_url required"}'; return 1; }

    _governance_check "trufflehog_github" "$repo" || return 1

    local result
    result=$(_toolkit_jsonrpc "trufflehog" "trufflehog_github" '{"repo":"'"$repo"'"}')
    _route_result "trufflehog_github" "$result" "$repo"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_trufflehog_github || true

# --- toolkit_trufflehog_s3 BUCKET ---
# Tier 0: Scan an S3 bucket for leaked secrets
toolkit_trufflehog_s3() {
    local bucket="$1"
    [[ -z "$bucket" ]] && { echo '{"error":"bucket required"}'; return 1; }

    _governance_check "trufflehog_s3" "$bucket" || return 1

    local result
    result=$(_toolkit_jsonrpc "trufflehog" "trufflehog_s3" '{"bucket":"'"$bucket"'"}')
    _route_result "trufflehog_s3" "$result" "$bucket"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_trufflehog_s3 || true

# --- toolkit_trufflehog_docker IMAGE ---
# Tier 0: Scan a Docker image for leaked secrets
toolkit_trufflehog_docker() {
    local image="$1"
    [[ -z "$image" ]] && { echo '{"error":"image required"}'; return 1; }

    _governance_check "trufflehog_docker" "$image" || return 1

    local result
    result=$(_toolkit_jsonrpc "trufflehog" "trufflehog_docker" '{"image":"'"$image"'"}')
    _route_result "trufflehog_docker" "$result" "$image"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_trufflehog_docker || true

# --- toolkit_trufflehog_postman WORKSPACE_ID ---
# Tier 0: Scan a Postman workspace for leaked secrets
toolkit_trufflehog_postman() {
    local workspace="$1"
    [[ -z "$workspace" ]] && { echo '{"error":"workspace_id required"}'; return 1; }

    _governance_check "trufflehog_postman" "$workspace" || return 1

    local result
    result=$(_toolkit_jsonrpc "trufflehog" "trufflehog_postman" '{"workspace":"'"$workspace"'"}')
    _route_result "trufflehog_postman" "$result" "$workspace"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_trufflehog_postman || true
