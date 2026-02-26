# How to Add a New Agent

> Step-by-step guide to building a new Pi agent for the swarm

## Quick Start

```bash
cd /mnt/bounty/Claude/pi-agents
./new-agent.sh exploit-db-watcher 0 minimax-m2.5:cloud "Monitor ExploitDB RSS for new exploits"
```

That's it! You now have a scaffolded agent ready to customize.

---

## The `new-agent.sh` Script

### Syntax

```bash
./new-agent.sh <agent-name> <tier> <model> <description>
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `agent-name` | Directory name (kebab-case) | `exploit-db-watcher` |
| `tier` | Permission tier (0-4) | `0` |
| `model` | Ollama model or NONE | `minimax-m2.5:cloud` |
| `description` | Brief job description (quoted) | `"Monitor ExploitDB RSS"` |

### Tiers

| Tier | Name | Use For |
|------|------|---------|
| **0** | OBSERVE | Public API readers (HN, CVE feeds, ExploitDB) |
| **1** | MONITOR | Internal monitoring (health checks, reviews) |
| **2** | RECON | Passive recon (subdomain enum, DNS) |
| **3** | SCAN | Active scanning (port scans, vuln scans) |
| **4** | EXPLOIT | Exploitation testing (SQLi, XSS, SSRF) |

### Models

| Model | Use For |
|-------|---------|
| `minimax-m2.5:cloud` | Simple tasks (fetch, format, post) |
| `deepseek-v3.2:cloud` | Analysis, summarization, scoring |
| `kimi-k2.5:cloud` | Writing, reports, personality |
| `NONE` | Pure bash agents (no AI needed) |

---

## Generated Files

After running `new-agent.sh`, you'll have:

```
/mnt/bounty/Claude/pi-agents/exploit-db-watcher/
├── extension.ts  ← Pi agent extension (tools, system prompt)
├── run.sh        ← Launcher script (executable)
└── state/        ← Runtime data directory
```

---

## The `extension.ts` Template

### Structure

```typescript
/**
 * AGENT_NAME — Pi Agent Extension
 *
 * HOME: /path/to/agent
 * JOB:  What the agent does
 * Tier: OBSERVE/MONITOR/RECON/SCAN/EXPLOIT
 * Model: minimax-m2.5:cloud or other
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const WEBHOOKS_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json";
const AGENT_HOME = "/mnt/bounty/Claude/pi-agents/exploit-db-watcher";
const STATE_DIR = `${AGENT_HOME}/state`;

export default function (pi: ExtensionAPI) {

  // 1. System Prompt (Agent Identity)
  pi.on("before_agent_start", async () => { ... });

  // 2. Built-in Tools
  pi.registerTool({ name: "check_opsec", ... });
  pi.registerTool({ name: "post_discord", ... });
  pi.registerTool({ name: "save_state", ... });

  // 3. YOUR CUSTOM TOOLS GO HERE

  // 4. Session Start Hook
  pi.on("session_start", async () => { ... });
}
```

### What's Pre-configured

The template includes:

1. **Governance prompt** — Loaded from `governance-prompt.txt`
2. **check_opsec tool** — Checks kill switches and OPSEC flags
3. **post_discord tool** — Posts to Discord channels
4. **save_state tool** — Saves run state to disk
5. **System prompt** — Agent identity, tier, workflow

### What You Need to Add

1. **Agent-specific tools** — Your custom functionality
2. **Workflow steps** — Update system prompt with task details
3. **Discord channels** — Specify which channels to post to

---

## Adding Custom Tools

### Example: Fetch ExploitDB RSS

```typescript
pi.registerTool({
  name: "fetch_exploitdb",
  label: "Fetch ExploitDB",
  description: "Fetches recent exploits from ExploitDB RSS feed.",
  parameters: {
    type: "object" as const,
    properties: {
      count: { type: "number" as const, description: "Number of items to fetch (default 20)" }
    },
    required: [] as string[]
  },
  execute: async (_id, params, _signal, onUpdate) => {
    const count = params.count || 20;

    onUpdate({ content: [{ type: "text", text: `Fetching ${count} exploits...` }], details: {} });

    // Fetch RSS feed
    const res = await fetch("https://www.exploit-db.com/rss.xml");
    const xml = await res.text();

    // Parse XML (use DOMParser or xml2js)
    // For simplicity, regex parsing here (not production-grade)
    const items = xml.match(/<item>[\s\S]*?<\/item>/g) || [];
    const exploits = items.slice(0, count).map((item) => {
      const title = item.match(/<title>(.*?)<\/title>/)?.[1] || "No title";
      const link = item.match(/<link>(.*?)<\/link>/)?.[1] || "";
      const pubDate = item.match(/<pubDate>(.*?)<\/pubDate>/)?.[1] || "";
      return { title, link, pubDate };
    });

    return {
      content: [{ type: "text", text: JSON.stringify(exploits, null, 2) }],
      details: { count: exploits.length }
    };
  }
});
```

### Tool Best Practices

1. **Clear parameters** — Use descriptive parameter names and descriptions
2. **Progress updates** — Call `onUpdate()` for long-running operations
3. **Error handling** — Use try/catch and return error messages
4. **Data validation** — Validate inputs before processing
5. **Return structured data** — Use JSON for complex results

---

## Updating the System Prompt

Edit the `systemPrompt` in the `before_agent_start` hook:

```typescript
return {
  systemPrompt: `You are the EXPLOIT-DB WATCHER agent. You live at ${AGENT_HOME}.

IDENTITY:
  Name: exploit-db-watcher
  Level: 3 (OPERATOR)
  Tier: OBSERVE
  Reports to: Orchestrator (Claude Opus)
  Commander: rainkode

${govPrompt}

YOUR ONE JOB: Monitor ExploitDB RSS feed for new exploits. Post relevant ones to #exploit-db.

WORKFLOW:
1. Call check_opsec — if not GREEN, stop immediately.
2. Call fetch_exploitdb with count=30
3. Filter for relevant categories (webapps, remote, local)
4. Format as Discord markdown with severity indicators
5. Post to #exploit-db via post_discord
6. Save state with posted exploit IDs to avoid duplicates

RULES:
- Focus on recent exploits (last 24 hours)
- Categorize: 🔴 remote code execution, 🟠 local privilege escalation, 🟡 denial of service
- If exploit matches active target tech stack → also post to #findings
- Max 5 Discord messages per run
- When done, STOP.`
};
```

### Key Sections

1. **IDENTITY** — Who the agent is, its tier, who it reports to
2. **YOUR ONE JOB** — The agent's single, focused task
3. **WORKFLOW** — Step-by-step instructions (tool calls)
4. **RULES** — Constraints, limits, special cases

---

## The `run.sh` Script

### Default Structure

```bash
#!/bin/bash
# exploit-db-watcher Launcher
# Tier: 0 (OBSERVE)
# Model: minimax-m2.5:cloud

AGENT_HOME="/mnt/bounty/Claude/pi-agents/exploit-db-watcher"
AGENT_TIER=0
PI_BIN="$HOME/bin/pi"
LOG="$AGENT_HOME/state/last-run.log"

# Governance pre-flight
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/preflight-governance.sh

echo "[$(date -u)] exploit-db-watcher starting..." > "$LOG"

timeout 120 $PI_BIN \
  --provider ollama \
  --model minimax-m2.5:cloud \
  --print \
  --no-session \
  --no-skills \
  --no-prompt-templates \
  --thinking off \
  --tools read,bash \
  -e "$AGENT_HOME/extension.ts" \
  "Execute your full workflow. Do all steps." \
  2>&1 | tee -a "$LOG"

echo "[$(date -u)] exploit-db-watcher finished." >> "$LOG"
```

### Customizations

#### Add Target Parameter

If your agent targets specific domains:

```bash
TARGET="example.com"  # Add this before preflight

# Governance pre-flight uses $TARGET for scope validation
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/preflight-governance.sh
```

#### Change Timeout

Default is 120 seconds. Adjust for longer-running agents:

```bash
timeout 300 $PI_BIN ...  # 5 minutes
```

#### Add Additional Tools

Enable more Pi tools:

```bash
--tools read,bash,write,glob,grep \
```

#### Pre-flight Data Gathering

Create a `preflight.sh` to gather data before the agent runs:

```bash
# preflight.sh
#!/bin/bash
curl -s "https://www.exploit-db.com/rss.xml" > "$AGENT_HOME/state/exploitdb-rss.xml"
```

Then call it in `run.sh`:

```bash
bash "$AGENT_HOME/preflight.sh"
```

---

## Wiring into Crontab

### Manual Crontab Entry

```bash
crontab -e
```

Add:

```cron
# ExploitDB Watcher — every hour
0 * * * * /mnt/bounty/Claude/pi-agents/exploit-db-watcher/run.sh
```

### Using install-crontab.sh

The swarm includes a master crontab installer:

```bash
# Edit swarm-blueprint/install-crontab.sh
# Add your agent to the cron schedule

# Then install
bash /mnt/bounty/Claude/pi-agents/swarm-blueprint/install-crontab.sh
```

### Cron Schedule Examples

```cron
# Every 5 minutes
*/5 * * * * /path/to/agent/run.sh

# Every 30 minutes
*/30 * * * * /path/to/agent/run.sh

# Hourly
0 * * * * /path/to/agent/run.sh

# Every 6 hours
0 */6 * * * /path/to/agent/run.sh

# Daily at 6am UTC
0 6 * * * /path/to/agent/run.sh

# Weekly on Sunday at midnight
0 0 * * 0 /path/to/agent/run.sh
```

---

## Testing Checklist

Before adding to cron:

### 1. Validate Extension Syntax

```bash
cd /mnt/bounty/Claude/pi-agents/exploit-db-watcher
npx tsc --noEmit extension.ts
```

### 2. Test Run Manually

```bash
./run.sh
```

Check:
- Does it complete successfully?
- Are governance checks working?
- Is output logged to `state/last-run.log`?
- Did it post to Discord?

### 3. Verify Governance

```bash
# Test global halt
touch /tmp/swarm-halt
./run.sh  # Should exit immediately with "SWARM HALTED"
rm /tmp/swarm-halt

# Test agent kill
touch /tmp/agent-kill-exploit-db-watcher
./run.sh  # Should exit with "AGENT KILLED"
rm /tmp/agent-kill-exploit-db-watcher

# Test OPSEC (Tier 2+ only)
touch /tmp/opsec-red
./run.sh  # Tier 2+ should exit, Tier 0-1 should proceed
rm /tmp/opsec-red
```

### 4. Check Audit Log

```bash
cat state/audit.log
# Should show governance decisions
```

### 5. Verify Discord Posting

Check the Discord channel — did the message appear?

### 6. Test Idempotency

Run the agent twice:

```bash
./run.sh
./run.sh
```

- Does it avoid duplicate posts?
- Is state tracking working?

### 7. Load Test

If the agent fetches external data:

```bash
# Run 5 times in quick succession
for i in {1..5}; do ./run.sh; sleep 5; done

# Check for rate limit errors
grep -i "rate" state/last-run.log
```

---

## Integration with Swarm

### Agent Chain Configuration

If your agent should trigger other agents, add it to the chain config:

**TODO:** Create `/mnt/bounty/Claude/pi-agents/swarm-blueprint/chain-config.json`

```json
{
  "exploit-db-watcher": {
    "triggers": ["bounty-triager"],
    "when": "new_exploit_found",
    "data": { "exploit_id": "EDB-12345", "category": "webapps" }
  }
}
```

### Swarm Dashboard

The agent will automatically appear in the dashboard:

```bash
/mnt/bounty/Claude/pi-agents/swarm-dashboard.sh
```

### Agent Reviewer

The agent-reviewer daemon will automatically discover and document your agent.

---

## Advanced Patterns

### Stateful Agents

Track previously seen items to avoid duplicates:

```typescript
// In a tool
const fs = await import("fs");
const STATE_FILE = `${STATE_DIR}/posted-ids.json`;

// Load existing state
let posted: number[] = [];
try {
  posted = JSON.parse(fs.readFileSync(STATE_FILE, "utf-8"));
} catch {}

// Filter new items
const newItems = allItems.filter(item => !posted.includes(item.id));

// Save updated state
posted.push(...newItems.map(i => i.id));
if (posted.length > 200) posted = posted.slice(-200);  // Keep last 200
fs.writeFileSync(STATE_FILE, JSON.stringify(posted));
```

### Multi-Channel Posting

Post to different channels based on severity:

```typescript
// Critical finding
await pi.tools.post_discord({
  channel: "cve-critical",
  message: "🔴 CRITICAL: ..."
});

// Also notify findings channel
await pi.tools.post_discord({
  channel: "findings",
  message: "Cross-posted from #cve-critical ..."
});
```

### Rate Limiting (Tier 3+ Agents)

Increment rate counter after making requests:

```bash
# In run.sh or preflight.sh
TARGET_SAFE=$(echo "$TARGET" | tr '.' '_')
RATE_FILE="/tmp/rate-counters/${TARGET_SAFE}.count"

mkdir -p /tmp/rate-counters

# Increment
CURRENT=$(cat "$RATE_FILE" 2>/dev/null || echo 0)
echo $((CURRENT + 1)) > "$RATE_FILE"
```

### Error Recovery

Handle failures gracefully:

```typescript
execute: async (_id, params, _signal, onUpdate) => {
  try {
    const res = await fetch("https://api.example.com/data");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    return { content: [{ type: "text", text: JSON.stringify(data) }], details: {} };
  } catch (e: any) {
    // Log error but don't crash
    return {
      content: [{ type: "text", text: `ERROR: ${e.message}` }],
      details: { error: e.message }
    };
  }
}
```

---

## Common Issues

### "No webhook for #channel-name"

**Fix:** Add the channel to `webhooks.json` (see [WEBHOOKS.md](WEBHOOKS.md))

### "Target not in approved scope"

**Fix:** Add the target to `approved-scope.json` (see [GOVERNANCE-GUIDE.md](GOVERNANCE-GUIDE.md))

### Agent runs but produces no output

**Check:**
- Is the model responding? (Ollama connection)
- Are tools being called? (Check `last-run.log`)
- Are governance checks blocking? (Check `audit.log`)

### "Rate limit exceeded"

**Fix:** Wait for hourly reset, or manually reset counter:

```bash
rm /tmp/rate-counters/example_com.count
```

### TypeScript compilation errors

**Fix:** Check import syntax, type annotations, and API compatibility:

```bash
npx tsc --noEmit extension.ts
```

---

## Template Checklist

When building a new agent, ensure you have:

- [ ] Clear single-task focus
- [ ] Appropriate tier assignment
- [ ] Governance prompt included
- [ ] `check_opsec` tool implemented
- [ ] Discord posting configured
- [ ] State tracking for idempotency
- [ ] Audit logging enabled
- [ ] Manual test run successful
- [ ] Governance tests passed
- [ ] Cron schedule added
- [ ] Documentation updated

---

## Example: Complete Agent

See these reference implementations:

- **hackernews-agent** — Public API fetching, state tracking
- **agent-reviewer** — File reading, README generation, multi-channel posting
- **vpn-sentinel** (when built) — Pure bash, no AI model

Study their `extension.ts` and `run.sh` files for patterns.

---

## Next Steps

1. **Build the agent** using `new-agent.sh`
2. **Customize extension.ts** with your tools and workflow
3. **Test thoroughly** using the checklist
4. **Add to crontab** with appropriate schedule
5. **Monitor in Discord** for successful runs
6. **Update documentation** in your agent's README.md

---

**File:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/NEW-AGENT-GUIDE.md`
**See also:** [SWARM-ARCHITECTURE.md](SWARM-ARCHITECTURE.md), [GOVERNANCE-GUIDE.md](GOVERNANCE-GUIDE.md), [WEBHOOKS.md](WEBHOOKS.md)
**Maintained by:** rainkode
**Last updated:** 2026-02-23
