#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# TOOLKIT MODULE: WINRM — Windows Remote Management exploitation
#
# 35 functions, all Tier 4. Recon, auth, exec, evasion, lateral,
# opsec, advanced, and binary-level WinRM attacks.
#
# Dependencies: _core.sh, _governance.sh, _output.sh
# Protocol: JSON-RPC 2.0 via d3bugr-winrm service (/mcp)
# ═══════════════════════════════════════════════════════════════

# ---------------------------------------------------------------
# RECON GROUP — Enumerate and fingerprint WinRM services
# ---------------------------------------------------------------

# toolkit_winrm_recon TARGET — Full WinRM reconnaissance
toolkit_winrm_recon() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_recon" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_recon" "{\"target\":\"$target\"}")
    _route_result "winrm_recon" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_recon || true

# toolkit_winrm_check TARGET — Check if WinRM is enabled
toolkit_winrm_check() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_check" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_check" "{\"target\":\"$target\"}")
    _route_result "winrm_check" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_check || true

# toolkit_winrm_config TARGET — Dump WinRM configuration
toolkit_winrm_config() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_config" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_config" "{\"target\":\"$target\"}")
    _route_result "winrm_config" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_config || true

# toolkit_winrm_ntlm_info TARGET — Extract NTLM authentication info
toolkit_winrm_ntlm_info() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_ntlm_info" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_ntlm_info" "{\"target\":\"$target\"}")
    _route_result "winrm_ntlm_info" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_ntlm_info || true

# toolkit_winrm_fingerprint TARGET — Fingerprint WinRM service
toolkit_winrm_fingerprint() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_fingerprint" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_fingerprint" "{\"target\":\"$target\"}")
    _route_result "winrm_fingerprint" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_fingerprint || true

# toolkit_winrm_sweep CIDR — Sweep a CIDR range for WinRM hosts
toolkit_winrm_sweep() {
    local cidr="$1"
    [[ -z "$cidr" ]] && { echo '{"error":"cidr required"}'; return 1; }
    _governance_check "winrm_sweep" "$cidr" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_sweep" "{\"cidr\":\"$cidr\"}")
    _route_result "winrm_sweep" "$result" "$cidr"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_sweep || true

# ---------------------------------------------------------------
# AUTH GROUP — Authentication testing and credential attacks
# ---------------------------------------------------------------

# toolkit_winrm_auth_test TARGET USER PASS — Test credentials
toolkit_winrm_auth_test() {
    local target="$1"
    local user="$2"
    local pass="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$user" ]] && { echo '{"error":"username required"}'; return 1; }
    [[ -z "$pass" ]] && { echo '{"error":"password required"}'; return 1; }
    _governance_check "winrm_auth_test" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_auth_test" "{\"target\":\"$target\",\"username\":\"$user\",\"password\":\"$pass\"}")
    _route_result "winrm_auth_test" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_auth_test || true

# toolkit_winrm_spray TARGET USERS PASS — Password spray attack
toolkit_winrm_spray() {
    local target="$1"
    local users="$2"
    local pass="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$users" ]] && { echo '{"error":"users required"}'; return 1; }
    [[ -z "$pass" ]] && { echo '{"error":"password required"}'; return 1; }
    _governance_check "winrm_spray" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_spray" "{\"target\":\"$target\",\"users\":\"$users\",\"password\":\"$pass\"}")
    _route_result "winrm_spray" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_spray || true

# toolkit_winrm_pth TARGET USER HASH — Pass-the-hash authentication
toolkit_winrm_pth() {
    local target="$1"
    local user="$2"
    local hash="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$user" ]] && { echo '{"error":"username required"}'; return 1; }
    [[ -z "$hash" ]] && { echo '{"error":"hash required"}'; return 1; }
    _governance_check "winrm_pth" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_pth" "{\"target\":\"$target\",\"username\":\"$user\",\"hash\":\"$hash\"}")
    _route_result "winrm_pth" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_pth || true

# toolkit_winrm_kerberos TARGET USER DOMAIN — Kerberos authentication
toolkit_winrm_kerberos() {
    local target="$1"
    local user="$2"
    local domain="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$user" ]] && { echo '{"error":"username required"}'; return 1; }
    [[ -z "$domain" ]] && { echo '{"error":"domain required"}'; return 1; }
    _governance_check "winrm_kerberos" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_kerberos" "{\"target\":\"$target\",\"username\":\"$user\",\"domain\":\"$domain\"}")
    _route_result "winrm_kerberos" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_kerberos || true

# ---------------------------------------------------------------
# EXEC GROUP — Remote command running
# ---------------------------------------------------------------

# toolkit_winrm_exec TARGET CMD — Run a command via WinRM
toolkit_winrm_exec() {
    local target="$1"
    local cmd="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$cmd" ]] && { echo '{"error":"command required"}'; return 1; }
    _governance_check "winrm_exec" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_exec" "{\"target\":\"$target\",\"command\":\"$cmd\"}")
    _route_result "winrm_exec" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_exec || true

# toolkit_winrm_ps_exec TARGET SCRIPT — Run PowerShell script
toolkit_winrm_ps_exec() {
    local target="$1"
    local script="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$script" ]] && { echo '{"error":"script required"}'; return 1; }
    _governance_check "winrm_ps_exec" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_ps_exec" "{\"target\":\"$target\",\"script\":\"$script\"}")
    _route_result "winrm_ps_exec" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_ps_exec || true

# toolkit_winrm_upload TARGET LOCAL REMOTE — Upload file to target
toolkit_winrm_upload() {
    local target="$1"
    local local_path="$2"
    local remote_path="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$local_path" ]] && { echo '{"error":"local_path required"}'; return 1; }
    [[ -z "$remote_path" ]] && { echo '{"error":"remote_path required"}'; return 1; }
    _governance_check "winrm_upload" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_upload" "{\"target\":\"$target\",\"local_path\":\"$local_path\",\"remote_path\":\"$remote_path\"}")
    _route_result "winrm_upload" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_upload || true

# toolkit_winrm_download TARGET REMOTE LOCAL — Download file from target
toolkit_winrm_download() {
    local target="$1"
    local remote_path="$2"
    local local_path="$3"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$remote_path" ]] && { echo '{"error":"remote_path required"}'; return 1; }
    [[ -z "$local_path" ]] && { echo '{"error":"local_path required"}'; return 1; }
    _governance_check "winrm_download" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_download" "{\"target\":\"$target\",\"remote_path\":\"$remote_path\",\"local_path\":\"$local_path\"}")
    _route_result "winrm_download" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_download || true

# ---------------------------------------------------------------
# EVASION GROUP — Defense evasion and payload generation
# ---------------------------------------------------------------

# toolkit_winrm_amsi_bypass TARGET — Bypass AMSI on target
toolkit_winrm_amsi_bypass() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_amsi_bypass" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_amsi_bypass" "{\"target\":\"$target\"}")
    _route_result "winrm_amsi_bypass" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_amsi_bypass || true

# toolkit_winrm_clm_bypass TARGET — Bypass Constrained Language Mode
toolkit_winrm_clm_bypass() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_clm_bypass" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_clm_bypass" "{\"target\":\"$target\"}")
    _route_result "winrm_clm_bypass" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_clm_bypass || true

# toolkit_winrm_payloads TYPE — Generate WinRM payloads by type
toolkit_winrm_payloads() {
    local type="$1"
    [[ -z "$type" ]] && { echo '{"error":"type required"}'; return 1; }
    _governance_check "winrm_payloads" "$type" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_payloads" "{\"type\":\"$type\"}")
    _route_result "winrm_payloads" "$result" "$type"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_payloads || true

# toolkit_winrm_cradle TARGET URL — Deploy download cradle on target
toolkit_winrm_cradle() {
    local target="$1"
    local url="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$url" ]] && { echo '{"error":"url required"}'; return 1; }
    _governance_check "winrm_cradle" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_cradle" "{\"target\":\"$target\",\"url\":\"$url\"}")
    _route_result "winrm_cradle" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_cradle || true

# ---------------------------------------------------------------
# LATERAL GROUP — Lateral movement and pivoting
# ---------------------------------------------------------------

# toolkit_winrm_lateral TARGET_LIST — Lateral movement across targets
toolkit_winrm_lateral() {
    local targets="$1"
    [[ -z "$targets" ]] && { echo '{"error":"targets required"}'; return 1; }
    _governance_check "winrm_lateral" "$targets" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_lateral" "{\"targets\":\"$targets\"}")
    _route_result "winrm_lateral" "$result" "$targets"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_lateral || true

# toolkit_winrm_pivot TARGET DEST — Pivot through target to destination
toolkit_winrm_pivot() {
    local target="$1"
    local dest="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$dest" ]] && { echo '{"error":"destination required"}'; return 1; }
    _governance_check "winrm_pivot" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_pivot" "{\"target\":\"$target\",\"destination\":\"$dest\"}")
    _route_result "winrm_pivot" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_pivot || true

# toolkit_winrm_session_enum TARGET — Enumerate active WinRM sessions
toolkit_winrm_session_enum() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_session_enum" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_session_enum" "{\"target\":\"$target\"}")
    _route_result "winrm_session_enum" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_session_enum || true

# ---------------------------------------------------------------
# OPSEC GROUP — Operational security and auditing
# ---------------------------------------------------------------

# toolkit_winrm_opsec TARGET — OPSEC assessment of WinRM activity
toolkit_winrm_opsec() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_opsec" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_opsec" "{\"target\":\"$target\"}")
    _route_result "winrm_opsec" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_opsec || true

# toolkit_winrm_log_analysis TARGET — Analyze WinRM event logs
toolkit_winrm_log_analysis() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_log_analysis" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_log_analysis" "{\"target\":\"$target\"}")
    _route_result "winrm_log_analysis" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_log_analysis || true

# toolkit_winrm_audit TARGET — Audit WinRM security configuration
toolkit_winrm_audit() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_audit" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_audit" "{\"target\":\"$target\"}")
    _route_result "winrm_audit" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_audit || true

# toolkit_winrm_hardening TARGET — Check WinRM hardening status
toolkit_winrm_hardening() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_hardening" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_hardening" "{\"target\":\"$target\"}")
    _route_result "winrm_hardening" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_hardening || true

# ---------------------------------------------------------------
# ADVANCED GROUP — Deep analysis, CVE checks, fuzzing
# ---------------------------------------------------------------

# toolkit_winrm_win11_checks TARGET — Windows 11 specific WinRM checks
toolkit_winrm_win11_checks() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_win11_checks" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_win11_checks" "{\"target\":\"$target\"}")
    _route_result "winrm_win11_checks" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_win11_checks || true

# toolkit_winrm_cve_check TARGET — Check for known WinRM CVEs
toolkit_winrm_cve_check() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_cve_check" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_cve_check" "{\"target\":\"$target\"}")
    _route_result "winrm_cve_check" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_cve_check || true

# toolkit_winrm_fuzz TARGET — Fuzz WinRM service for anomalies
toolkit_winrm_fuzz() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_fuzz" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_fuzz" "{\"target\":\"$target\"}")
    _route_result "winrm_fuzz" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_fuzz || true

# toolkit_winrm_deep_probe TARGET — Deep protocol-level probe
toolkit_winrm_deep_probe() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_deep_probe" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_deep_probe" "{\"target\":\"$target\"}")
    _route_result "winrm_deep_probe" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_deep_probe || true

# toolkit_winrm_poc_gen TARGET CVE — Generate PoC for a CVE
toolkit_winrm_poc_gen() {
    local target="$1"
    local cve="$2"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    [[ -z "$cve" ]] && { echo '{"error":"cve required"}'; return 1; }
    _governance_check "winrm_poc_gen" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_poc_gen" "{\"target\":\"$target\",\"cve\":\"$cve\"}")
    _route_result "winrm_poc_gen" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_poc_gen || true

# toolkit_winrm_rce_hunt TARGET — Hunt for RCE vectors via WinRM
toolkit_winrm_rce_hunt() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_rce_hunt" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_rce_hunt" "{\"target\":\"$target\"}")
    _route_result "winrm_rce_hunt" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_rce_hunt || true

# ---------------------------------------------------------------
# BINARY GROUP — Low-level protocol abuse
# ---------------------------------------------------------------

# toolkit_winrm_ntlm_binary TARGET — Binary NTLM analysis
toolkit_winrm_ntlm_binary() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_ntlm_binary" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_ntlm_binary" "{\"target\":\"$target\"}")
    _route_result "winrm_ntlm_binary" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_ntlm_binary || true

# toolkit_winrm_chunked_abuse TARGET — HTTP chunked transfer abuse
toolkit_winrm_chunked_abuse() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_chunked_abuse" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_chunked_abuse" "{\"target\":\"$target\"}")
    _route_result "winrm_chunked_abuse" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_chunked_abuse || true

# toolkit_winrm_path_fuzz TARGET — Fuzz WinRM URL paths
toolkit_winrm_path_fuzz() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_path_fuzz" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_path_fuzz" "{\"target\":\"$target\"}")
    _route_result "winrm_path_fuzz" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_path_fuzz || true

# toolkit_winrm_header_poison TARGET — HTTP header poisoning attacks
toolkit_winrm_header_poison() {
    local target="$1"
    [[ -z "$target" ]] && { echo '{"error":"target required"}'; return 1; }
    _governance_check "winrm_header_poison" "$target" || return 1
    local result
    result=$(_toolkit_jsonrpc "winrm" "winrm_header_poison" "{\"target\":\"$target\"}")
    _route_result "winrm_header_poison" "$result" "$target"
    echo "$result"
}
[[ -n "${BASH_VERSION:-}" ]] && export -f toolkit_winrm_header_poison || true
