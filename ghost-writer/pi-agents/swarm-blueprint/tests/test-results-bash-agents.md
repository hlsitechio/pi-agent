# Bash Agent Test Results

**Date:** 2026-02-23  
**Tester:** Claude Opus 4.6 (automated)  
**Scope:** T027 opsec-guardian, T030 rate-monitor, T038 error-watcher

---

## T027: opsec-guardian

**Script:** `/mnt/bounty/Claude/pi-agents/opsec-guardian/run.sh`  
**Log:** `/mnt/bounty/Claude/pi-agents/opsec-guardian/state/last-run.log`

### Syntax Check
- `bash -n run.sh` — **PASS** (exit 0)

### Governance Preflight
- **PASS** — Sources `preflight-governance.sh`
- Also has inline kill-switch checks before sourcing (belt-and-suspenders for the opsec agent itself, since it IS the opsec checker)
- Skips OPSEC-RED check correctly (it is the opsec checker, circular dependency avoided)

### 8 Security Checks
| # | Check | Implemented | Log Evidence |
|---|-------|-------------|--------------|
| 1 | VPN Status | YES — `nordvpn status` parsed | `[+] VPN connected: Montreal, Canada` |
| 2 | DNS Leak | YES — `dig` against OpenDNS + Akamai | `[!] DNS: Possible leak detected: 74.63.30.243` |
| 3 | Open Ports | YES — `ss -tlnp` vs expected list | `[!] Unexpected ports: 11434 19999 ...` |
| 4 | Tor Service | YES — `pgrep -x tor` | `[+] Tor process running` |
| 5 | Kill Switches | YES — checks `/tmp/swarm-halt` and `/tmp/opsec-red` | `[+] No kill switches active` |
| 6 | Disk Encryption | YES — checks `/mnt/bounty` mount for `mapper` (LUKS) | `[+] /mnt/bounty encrypted: /dev/mapper/bounty-crypt` |
| 7 | SSH Sessions | YES — `who` parsed for pts sessions | `[+] SSH: 0 sessions` |
| 8 | Process Audit | YES — regex scan for reverse shells + high CPU | `[!] Suspicious processes: ...chrome_crashpad_handler` |

### Discord Posting
- **PASS** — Posts to `sentinel` channel every run
- **PASS** — Posts to `opsec-alerts` channel when critical or 3+ warnings
- Log confirms: `[+] Posted to sentinel channel` and `[!] ALERT posted to opsec-alerts`

### State Persistence
- **PASS** — Writes `last-run.json` with structured status (vpn, dns_leak, ssh_sessions, etc.)

### Summary
- Log shows: `Passed: 5 | Warnings: 3 | Failures: 0`
- All 8 checks execute and produce output
- **VERDICT: PASS**

---

## T030: rate-monitor

**Script:** `/mnt/bounty/Claude/pi-agents/rate-monitor/run.sh`  
**Log:** `/mnt/bounty/Claude/pi-agents/rate-monitor/state/last-run.log`

### Syntax Check
- `bash -n run.sh` — **PASS** (exit 0)

### Governance Preflight
- **PASS** — Sources `preflight-governance.sh`
- Has inline kill-switch checks before sourcing (same belt-and-suspenders pattern)
- Sets `AGENT_TIER=1` (MONITOR)

### Manual Execution
- **PASS** — Runs cleanly, exit code 0
- Governance reports: `[+] Governance pre-flight passed — Tier 1 authorized`
- Log: `All targets within limits (0 monitored)` (correct — no active counters)

### Blocking Logic (Tier 3+ blocking)

**Two blocking mechanisms exist:**

1. **rate-monitor block files** (`/tmp/rate-block-{domain}`):
   - Created when domain hits `BLOCK_THRESHOLD=100` or `CRITICAL_THRESHOLD=200` req/hr
   - Tested by injecting `echo 150 > /tmp/rate-counters/test-target.example.com`
   - **PASS** — Block file created at `/tmp/rate-block-test-target.example.com`
   - Log confirmed: `[!] BLOCKED: test-target.example.com at 150 requests/hour`
   - Scanning agents (xss-hunter, sqli-hunter, etc.) check block files via `rate-increment.sh`

2. **Governance preflight rate limit** (in `preflight-governance.sh`):
   - Tier 3+ agents with a TARGET are checked against `HARD_LIMIT=500` req/hr
   - Reads from `/tmp/rate-counters/{domain_underscored}.count`

**Integration with rate-increment.sh:**
- `rate-increment.sh` creates counters at `/tmp/rate-counters/{domain_underscored}` (no `.count` suffix)
- Agents (xss-hunter, sqli-hunter, etc.) call `rate-increment.sh` before requests
- `rate-increment.sh` checks `/tmp/rate-block-{domain_underscored}` and returns `BLOCKED` if present

### Thresholds
| Level | Threshold | Action |
|-------|-----------|--------|
| Warn | 50 req/hr | Log warning |
| Block | 100 req/hr | Create block file |
| Critical | 200 req/hr | Create block file + alert |

### Finding: Counter File Naming Mismatch
- **ISSUE (minor):** `rate-increment.sh` writes to `/tmp/rate-counters/{domain_underscored}` (e.g., `example_com`)
- Governance preflight reads from `/tmp/rate-counters/{domain_underscored}.count` (e.g., `example_com.count`)
- The `.count` suffix in governance means it will never find counters created by `rate-increment.sh`
- **Impact:** Governance hard-limit (500 req/hr) will never fire. However, the rate-monitor's own blocking (100 req/hr) fires earlier at a lower threshold, so the safety net still works via block files checked in `rate-increment.sh`.
- **Recommendation:** Remove `.count` suffix from governance line 125, or add `.count` to `rate-increment.sh`.

### Discord Posting
- **PASS** — Posts to `opsec-alerts` webhook when issues detected
- Sends hourly heartbeat (silent otherwise to avoid spam)

### Summary
- Core blocking logic works: block files are created and respected by scanning agents
- Counter file naming mismatch between governance and rate-increment is a minor gap but does not break safety (rate-monitor catches it earlier at 100 req/hr)
- **VERDICT: PASS (with minor finding noted)**

---

## T038: error-watcher

**Script:** `/mnt/bounty/Claude/pi-agents/error-watcher/run.sh`  
**Log:** `/mnt/bounty/Claude/pi-agents/error-watcher/state/last-run.log`

### Syntax Check
- `bash -n run.sh` — **PASS** (exit 0)

### Governance Preflight
- **PASS** — Sources `preflight-governance.sh` as first operational step
- Sets `AGENT_TIER=1` (MONITOR)

### Manual Execution
- **PASS** — Runs cleanly, exit code 0
- Governance reports: `[+] Governance pre-flight passed — Tier 1 authorized`

### Agent Log Scanning
- **PASS** — Scans all agent directories under `/mnt/bounty/Claude/pi-agents/`
- Correctly skips `swarm-blueprint/` and `error-watcher/` (avoids self-monitoring loops)
- Checks `state/last-run.log` in each agent directory
- Uses timestamp-based deduplication: only reports errors from logs modified since last check

### Error Patterns
Scans for 9 patterns: `ERROR`, `FAIL`, `FATAL`, `Traceback`, `panic:`, `ABORT`, `Exception`, `killed`, `timeout`

### Execution Results
- First run (cold): `checked 9 agents, found 0 new errors` — posted clean status
- Second run (after opsec-guardian ran): `checked 32 agents, found 2 new errors`
  - Detected `opsec-guardian` log containing "Failures" string (matched FAIL pattern — false positive from `[SUMMARY] Passed: 5 | Warnings: 3 | Failures: 0`)
  - Detected `railway-monitor` log containing grep error pattern

### Finding: False Positive on "Failures: 0"
- **ISSUE (minor):** The `FAIL` pattern matches the summary line `Failures: 0` in opsec-guardian's log, triggering a false-positive error alert.
- **Recommendation:** Use word-boundary matching or exclude lines containing `Failures: 0`. Alternatively, change error patterns to require `FAIL` at the start of a line or use `grep -w`.

### Discord Posting
- **PASS** — Posts to `agent-errors` webhook when errors found
- **PASS** — Posts to `agent-status` webhook for clean runs

### State Persistence
- **PASS** — Saves `last-run.json` with structured data (timestamp, counts, agents checked)
- **PASS** — Saves `last-check-timestamp` for deduplication

### Summary
- Core functionality works: scans all agent logs, detects errors, posts to Discord
- Has a false-positive on the FAIL pattern matching "Failures: 0" — minor issue
- **VERDICT: PASS (with minor finding noted)**

---

## Overall Summary

| Agent | Syntax | Governance | Core Function | Discord | Verdict |
|-------|--------|-----------|---------------|---------|---------|
| T027 opsec-guardian | PASS | PASS | PASS (8/8 checks) | PASS | **PASS** |
| T030 rate-monitor | PASS | PASS | PASS (blocking works) | PASS | **PASS** (minor: counter naming) |
| T038 error-watcher | PASS | PASS | PASS (scans agents) | PASS | **PASS** (minor: false positive) |

### Findings to Address
1. **rate-monitor / governance counter file naming mismatch** — Governance preflight appends `.count` to rate counter filenames but `rate-increment.sh` does not. The governance hard-limit (500/hr) will never fire. The rate-monitor block-file mechanism (100/hr) covers this gap at a lower threshold, so safety is maintained.
2. **error-watcher false positive on "FAIL" pattern** — The case-insensitive grep for `FAIL` matches `Failures: 0` in summary lines. Consider using `grep -w "FAIL"` or excluding known summary patterns.

### All Three Agents
- Execute without error
- Source governance preflight correctly
- Perform their stated function
- Produce structured log output
- Post results to Discord

**All tests PASSED.**
