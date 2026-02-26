# Pi Agent Swarm Governance System

> The rules that keep 30+ autonomous agents under control

## Philosophy

The Pi Agent Swarm operates 24/7 with minimal human oversight. To prevent chaos, every agent follows strict governance rules enforced at multiple layers:

1. **Pre-flight checks** — Bash script validates before agent starts
2. **Agent identity** — System prompt defines boundaries
3. **Tool-level validation** — Individual tools check permissions
4. **Audit logging** — Every action is recorded

**Core principle:** Agents are tools, not operators. They execute, not decide.

---

## Permission Tiers

Every agent is assigned a **tier** that determines what it can do:

| Tier | Name | Permissions | Examples |
|------|------|-------------|----------|
| **0** | OBSERVE | Read public APIs, no outbound requests to targets | hackernews-agent, cve-monitor |
| **1** | MONITOR | Read infrastructure state, internal APIs only | agent-reviewer, health-checker |
| **2** | RECON | Passive recon against approved targets (DNS, subdomain enum) | subdomain-enumerator, dns-recon-agent |
| **3** | SCAN | Active scanning against approved targets (port scans, vuln scans) | port-scanner, vuln-scanner |
| **4** | EXPLOIT | Exploitation tools (SQLi, XSS, SSRF testing) | sqli-hunter, xss-hunter, ssrf-prober |

### Tier Enforcement

**Tier 0-1:** Can run anytime, no OPSEC check required
**Tier 2+:** Require VPN connection (OPSEC GREEN) before running
**Tier 2+:** Require target to be in approved scope
**Tier 3+:** Require rate limit check before scanning

---

## Kill Switches

### Global Swarm Halt

**File:** `/tmp/swarm-halt`

When this file exists, **ALL agents stop immediately**.

```bash
# Halt the entire swarm
touch /tmp/swarm-halt

# Resume operations
rm /tmp/swarm-halt
```

**Use cases:**
- Emergency stop during incident response
- Maintenance windows
- Suspected compromise

### Agent-Specific Kill

**File:** `/tmp/agent-kill-{agent-name}`

Stops a specific agent without affecting others.

```bash
# Kill hackernews-agent
touch /tmp/agent-kill-hackernews-agent

# Resume
rm /tmp/agent-kill-hackernews-agent
```

**Use cases:**
- Agent misbehaving (infinite loop, spam, etc.)
- Debugging a specific agent
- Temporary disable during testing

### OPSEC Red Flag

**File:** `/tmp/opsec-red`

Blocks all **Tier 2+ agents** (those that make outbound requests to targets).

```bash
# Set OPSEC RED (blocks recon/scan/exploit agents)
touch /tmp/opsec-red

# Clear OPSEC RED
rm /tmp/opsec-red
```

**Automatically set by:**
- `vpn-sentinel` when VPN connection drops
- Manual override by Commander

**Use cases:**
- VPN disconnected
- IP address changed unexpectedly
- Suspected exposure

---

## Scope Lock

**File:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/approved-scope.json`

Agents at **Tier 2+** can ONLY target domains in this file.

### Format

```json
{
  "domains": [
    "example.com",
    "api.example.com",
    "staging.example.com"
  ],
  "wildcards": [
    "*.bugcrowd-example.com",
    "*.hackerone-example.com"
  ],
  "excluded": [
    "prod-secure.example.com",
    "internal.example.com"
  ],
  "notes": "Updated 2026-02-23 — Added Bugcrowd program ACME-2024"
}
```

### Scope Validation Logic

Before any Tier 2+ agent starts:

1. **Exact match:** Is target in `domains` array?
2. **Wildcard match:** Does target match any `wildcards` pattern?
3. **Exclusion check:** Is target in `excluded` array? (blocks even if matched above)
4. **Not in scope:** Agent exits with error

### Adding Targets to Scope

```bash
# Edit the scope file
nano /mnt/bounty/Claude/pi-agents/swarm-blueprint/approved-scope.json

# Add new domain to "domains" array
{
  "domains": [
    "example.com",
    "newclient.com"  # ← Add here
  ],
  ...
}

# Save and exit
# Next agent run will automatically use updated scope
```

### Removing Targets from Scope

```bash
# Option 1: Delete from "domains" array
# Option 2: Move to "excluded" array (safer — prevents accidental targeting)
{
  "excluded": [
    "old-client.com"  # ← Explicitly block
  ]
}
```

---

## Rate Limiting

**Directory:** `/tmp/rate-counters/`

Prevents agents from hammering targets and triggering WAFs.

### How It Works

1. Before scanning, agent checks rate counter for target
2. If under limit → proceed and increment counter
3. If over limit → exit with error
4. Counters reset hourly (via cron or automatic cleanup)

### Rate Files

```bash
/tmp/rate-counters/
├── example_com.count          # example.com counter
├── api_example_com.count      # api.example.com counter
└── staging_example_com.count  # staging.example.com counter
```

Each file contains a single number: the request count for the current hour.

### Limits

| Tier | Hard Limit | Warning Threshold |
|------|-----------|-------------------|
| **2 (RECON)** | 100 req/hr | 80 req/hr |
| **3 (SCAN)** | 500 req/hr | 400 req/hr |
| **4 (EXPLOIT)** | 100 req/hr | 80 req/hr |

### Manual Rate Check

```bash
# Check current rate for example.com
cat /tmp/rate-counters/example_com.count

# Reset rate counter manually
rm /tmp/rate-counters/example_com.count

# Or set to specific value
echo "50" > /tmp/rate-counters/example_com.count
```

---

## Audit Trail

**File:** `{agent_home}/state/audit.log`

Every agent maintains an audit log of all governance decisions.

### Format

```
[2026-02-23T14:32:10Z] [TIER-2] [subdomain-enumerator] APPROVED: Agent starting (Tier 2, Target: example.com)
[2026-02-23T14:32:45Z] [TIER-2] [subdomain-enumerator] COMPLETED: Found 12 subdomains
[2026-02-23T14:45:00Z] [TIER-2] [subdomain-enumerator] BLOCKED: OPSEC RED — Tier 2 requires VPN
[2026-02-23T15:00:00Z] [TIER-2] [subdomain-enumerator] BLOCKED: Target api.hacker.com not in approved scope
```

### Fields

- **Timestamp:** UTC ISO-8601 format
- **Tier:** Agent's permission tier
- **Agent:** Agent name
- **Event:** APPROVED, BLOCKED, COMPLETED, ERROR, ESCALATION

### Viewing Audit Logs

```bash
# View all audit logs for an agent
cat /mnt/bounty/Claude/pi-agents/subdomain-enumerator/state/audit.log

# View recent governance blocks
grep "BLOCKED" /mnt/bounty/Claude/pi-agents/*/state/audit.log | tail -20

# Check what happened at a specific time
grep "2026-02-23T14:3" /mnt/bounty/Claude/pi-agents/*/state/audit.log
```

---

## Pre-flight Governance Check

**Script:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/preflight-governance.sh`

This script is sourced at the top of **every agent's `run.sh`**.

### Required Variables

Before sourcing the script, set:

```bash
AGENT_HOME="/mnt/bounty/Claude/pi-agents/my-agent"  # Agent's home directory
AGENT_TIER=2                                        # Permission tier (0-4)
TARGET="example.com"                                # Target domain (optional)
```

### Checks Performed

1. **Global halt check** → Exit if `/tmp/swarm-halt` exists
2. **Agent kill check** → Exit if `/tmp/agent-kill-{name}` exists
3. **OPSEC check** (Tier 2+ only) → Exit if `/tmp/opsec-red` exists
4. **Scope check** (Tier 2+ with target) → Exit if target not in `approved-scope.json`
5. **Rate limit check** (Tier 3+ with target) → Exit if rate limit exceeded

All checks are logged to `{agent_home}/state/audit.log`.

### Example Usage

```bash
#!/bin/bash
# my-agent/run.sh

AGENT_HOME="/mnt/bounty/Claude/pi-agents/my-agent"
AGENT_TIER=2
TARGET="example.com"

# Governance pre-flight
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/preflight-governance.sh

# If we get here, all checks passed
echo "[+] Running my-agent against $TARGET..."
# ... agent logic ...
```

---

## Agent Identity Prompt

**File:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/governance-prompt.txt`

This text is injected into **every agent's system prompt** to reinforce governance rules.

### Key Rules

1. **Single-task focus:** Do ONLY your assigned task
2. **Escalate uncertainty:** If unsure, STOP and ask
3. **Scope enforcement:** Never access targets outside scope
4. **Tier enforcement:** Never exceed your permission level
5. **OPSEC checks:** Always check flags before outbound requests
6. **Report before action:** Report findings BEFORE exploiting
7. **No freelancing:** No bug report submissions (Commander only)
8. **No cross-contamination:** Don't modify other agents' files
9. **PII/credential handling:** STOP if found, report to Orchestrator
10. **Channel discipline:** Post ONLY to assigned channels
11. **Message limits:** Max 5 Discord messages per run
12. **Stop when done:** Don't explore further after task completion

### Escalation Format

When an agent encounters something unexpected:

```
ESCALATION | [agent-name] | [what happened] | [what you need] | WAITING
```

Then the agent **STOPS and exits**. It does not continue.

---

## Governance in Agent Extensions

### TypeScript Example

```typescript
// Tool: Check OPSEC
pi.registerTool({
  name: "check_opsec",
  label: "Check OPSEC",
  description: "Checks all governance flags before proceeding.",
  parameters: { type: "object" as const, properties: {}, required: [] as string[] },
  execute: async () => {
    const fs = await import("fs");

    // Global halt
    if (fs.existsSync("/tmp/swarm-halt")) {
      return { content: [{ type: "text", text: "SWARM HALTED — abort" }], details: {} };
    }

    // Agent kill
    if (fs.existsSync("/tmp/agent-kill-my-agent")) {
      return { content: [{ type: "text", text: "AGENT KILLED — abort" }], details: {} };
    }

    // OPSEC red (for Tier 2+ agents)
    if (fs.existsSync("/tmp/opsec-red")) {
      return { content: [{ type: "text", text: "OPSEC RED — abort" }], details: {} };
    }

    return { content: [{ type: "text", text: "ALL CLEAR — proceed" }], details: {} };
  }
});
```

### Bash Example

```bash
#!/bin/bash
# Governance check in pure bash

if [ -f /tmp/swarm-halt ]; then
  echo "[HALT] Global swarm halt active"
  exit 0
fi

if [ -f /tmp/agent-kill-my-agent ]; then
  echo "[HALT] Agent killed"
  exit 0
fi

# Proceed with agent logic
echo "[+] Governance check passed"
```

---

## Emergency Procedures

### Stop Everything Immediately

```bash
# Nuclear option — halt all agents
touch /tmp/swarm-halt

# Verify all cron jobs will exit on next run
watch 'grep -c "SWARM HALTED" /mnt/bounty/Claude/pi-agents/*/state/last-run.log'

# When safe to resume
rm /tmp/swarm-halt
```

### Stop Offensive Agents Only

```bash
# Block Tier 2+ (recon/scan/exploit)
touch /tmp/opsec-red

# Intel agents (Tier 0-1) continue running
# All offensive agents will exit on next cron run

# Resume offensive operations
rm /tmp/opsec-red
```

### Kill a Rogue Agent

```bash
# Stop the agent via kill switch
touch /tmp/agent-kill-subdomain-enumerator

# Kill any running process
pkill -f "subdomain-enumerator"

# Check audit log for what happened
tail -50 /mnt/bounty/Claude/pi-agents/subdomain-enumerator/state/audit.log

# When fixed, resume
rm /tmp/agent-kill-subdomain-enumerator
```

---

## Monitoring Governance

### Check All Kill Switches

```bash
# List all active kill switches
ls -1 /tmp/swarm-* /tmp/agent-kill-* /tmp/opsec-* 2>/dev/null || echo "No kill switches active"
```

### View Recent Governance Blocks

```bash
# All blocks in last hour
find /mnt/bounty/Claude/pi-agents/*/state/audit.log -mmin -60 -exec grep "BLOCKED" {} + | tail -20
```

### Check Scope Validity

```bash
# Validate JSON syntax
python3 -m json.tool /mnt/bounty/Claude/pi-agents/swarm-blueprint/approved-scope.json > /dev/null && echo "✓ Valid" || echo "✗ Invalid JSON"
```

### Check Rate Limit Status

```bash
# Show all active rate counters
for f in /tmp/rate-counters/*.count; do
  [ -f "$f" ] && echo "$(basename $f): $(cat $f) requests"
done
```

---

## Governance Best Practices

### For Agent Development

1. **Always source preflight-governance.sh** in `run.sh`
2. **Always include governance prompt** in system prompt
3. **Always implement check_opsec tool** in extension
4. **Always log to audit trail** for major actions
5. **Always respect message limits** (max 5 per run)

### For Operations

1. **Review audit logs weekly** for governance violations
2. **Update approved-scope.json** when programs change
3. **Monitor kill switches** for unexpected blocks
4. **Test governance** before deploying new agents
5. **Document scope changes** in `approved-scope.json` notes field

### For Debugging

1. **Check audit log first** — it shows what happened
2. **Verify kill switches** — they may have blocked the agent
3. **Test scope validation** — ensure target is properly added
4. **Check rate counters** — agent may be rate-limited
5. **Review last-run.log** — shows agent's perspective

---

## Files Reference

| File/Dir | Purpose |
|----------|---------|
| `/tmp/swarm-halt` | Global kill switch (all agents) |
| `/tmp/agent-kill-{name}` | Agent-specific kill switch |
| `/tmp/opsec-red` | OPSEC flag (blocks Tier 2+) |
| `/tmp/rate-counters/` | Rate limit tracking |
| `approved-scope.json` | Allowed target domains |
| `governance-prompt.txt` | Agent identity/rules prompt |
| `preflight-governance.sh` | Pre-flight validation script |
| `{agent}/state/audit.log` | Per-agent audit trail |

---

**Maintained by:** rainkode
**Last updated:** 2026-02-23
**See also:** [SWARM-ARCHITECTURE.md](SWARM-ARCHITECTURE.md), [WEBHOOKS.md](WEBHOOKS.md)
