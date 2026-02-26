# Discord Webhook Registry

> Central webhook configuration for the Pi Agent Swarm

## Overview

The webhook registry (`webhooks.json`) is the single source of truth for all Discord channel webhooks. Every agent reads this file to determine where to post its findings.

**Location:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json`

## Format

Each channel has:

- `channel_id` — Discord channel ID (for reference)
- `webhook_id` — Discord webhook ID
- `webhook_url` — Full webhook URL for posting

```json
{
  "channel-name": {
    "channel_id": "1234567890123456789",
    "webhook_id": "9876543210987654321",
    "webhook_url": "https://discord.com/api/webhooks/9876543210987654321/TOKEN"
  }
}
```

## Channel Directory

### OPSEC Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `vpn-status` | VPN connection heartbeats | vpn-sentinel |
| `opsec-alerts` | OPSEC warnings, security issues | opsec-guardian |
| `sentinel` | General sentinel alerts | Multiple sentinels |

### Intelligence Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `hackernews` | HackerNews security stories | hackernews-agent |
| `cve-critical` | Critical CVEs (CVSS >= 9.0) | cve-monitor |
| `cve-notable` | Notable CVEs (CVSS 7.0-8.9) | cve-monitor |
| `threat-intel` | Threat intelligence aggregation | threat-intel-aggregator |
| `exploit-db` | ExploitDB new exploits | exploit-db-watcher |

### Recon Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `asset-discovery` | New subdomains discovered | subdomain-enumerator |
| `recon-results` | Port scan results | port-scanner |
| `dns-intel` | DNS recon findings | dns-recon-agent |
| `scope-watch` | Scope changes on bug bounty programs | scope-watcher |

### Hunting Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `findings` | Confirmed vulnerabilities | vuln-scanner, multiple hunters |
| `exploits` | Exploitable findings (SQLi, XSS, SSRF, etc.) | sqli-hunter, xss-hunter, ssrf-prober, idor-checker |
| `reports` | Report drafts and bounty estimates | bounty-estimator |
| `targets` | Prioritized target list | bounty-triager, lead-tracker |

### Honeypot Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `captures` | BotHeaven credential captures | capture-monitor |
| `traps` | Honeypot trap hits | trap-monitor |
| `visitors` | Interesting human visitors | trap-monitor |
| `bots` | Bot/scanner traffic | trap-monitor |

### Swarm Tier (Meta)

| Channel | Purpose | Agents |
|---------|---------|--------|
| `agent-status` | Agent health checks | health-checker, all agents |
| `agent-reviews` | Ecosystem reviews | agent-reviewer |
| `agent-dispatch` | Dispatch commands | dispatcher |
| `agent-errors` | Agent failures | error-watcher |

### Infrastructure Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `d3bugr` | D3BUGR service health | d3bugr-monitor |
| `supabase` | Supabase backend status | supabase-monitor |
| `railway` | Railway deployments | railway-monitor |
| `ollama` | Ollama model availability | ollama-monitor |

### Analytics Tier

| Channel | Purpose | Agents |
|---------|---------|--------|
| `briefing` | Daily briefs, weekly summaries | lead-tracker, cve-scorer, technique-librarian |

### Command & Control

| Channel | Purpose | Agents |
|---------|---------|--------|
| `orchestrator` | Orchestrator commands and status | Manual / Claude Opus |

## Usage in Agent Code

### TypeScript Extension (extension.ts)

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const WEBHOOKS_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json";

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "post_discord",
    label: "Post to Discord",
    description: "Posts a message to a Discord channel via webhook",
    parameters: {
      type: "object" as const,
      properties: {
        channel: { type: "string" as const, description: "Channel name" },
        message: { type: "string" as const, description: "Message to post" }
      },
      required: ["channel", "message"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const webhooks = JSON.parse(fs.readFileSync(WEBHOOKS_PATH, "utf-8"));
      const webhook = webhooks[params.channel];

      if (!webhook) {
        return {
          content: [{ type: "text", text: `No webhook for #${params.channel}` }],
          details: {}
        };
      }

      const res = await fetch(webhook.webhook_url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          content: params.message,
          username: "Agent Name"
        })
      });

      return {
        content: [{ type: "text", text: res.ok ? "Posted" : `Failed: ${res.status}` }],
        details: {}
      };
    }
  });
}
```

### Bash Script

```bash
#!/bin/bash
# Post to Discord from bash

WEBHOOKS_FILE="/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json"
CHANNEL="hackernews"
MESSAGE="Test message from bash"

WEBHOOK_URL=$(jq -r ".\"$CHANNEL\".webhook_url" "$WEBHOOKS_FILE")

if [ "$WEBHOOK_URL" = "null" ] || [ -z "$WEBHOOK_URL" ]; then
  echo "[-] No webhook found for #$CHANNEL"
  exit 1
fi

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"$MESSAGE\", \"username\": \"Bash Agent\"}"
```

## Manual Posting (curl)

```bash
# Post to #hackernews
curl -X POST \
  "https://discord.com/api/webhooks/1475643097823182869/aqR6eGh0DIdLVXsR6hBTxVHCv5RynThyFZnERxw_WvB2xo7lpVLh2jNuj_I2aKMgOSLw" \
  -H "Content-Type: application/json" \
  -d '{"content": "# Test Message\nThis is a **test** from curl", "username": "Manual Post"}'
```

## Discord Markdown Support

Discord webhooks support markdown formatting:

```markdown
# Heading 1
## Heading 2
**Bold text**
*Italic text*
__Underline__
~~Strikethrough~~
`inline code`
```
```
code block
```
```
> Blockquote
- Bullet list
1. Numbered list
[Link text](https://example.com)
```

## Rate Limits

Discord webhook rate limits:

- **30 messages per minute** per webhook
- **2000 characters** per message
- **10 embeds** per message (not commonly used by agents)

If you need to post more:
- Split long messages into chunks (see existing agents for chunking logic)
- Add 1-second delays between posts
- Stay under 5 messages per agent run (governance rule)

## Message Chunking Example

```typescript
// Auto-chunk messages over 2000 chars
function chunkMessage(message: string): string[] {
  if (message.length <= 1950) return [message];

  const chunks: string[] = [];
  const lines = message.split("\n");
  let current = "";

  for (const line of lines) {
    if ((current + "\n" + line).length > 1900) {
      chunks.push(current);
      current = line;
    } else {
      current = current ? current + "\n" + line : line;
    }
  }
  if (current) chunks.push(current);

  return chunks.slice(0, 5); // Max 5 per governance
}
```

## Adding a New Channel

1. Create the channel in Discord (RainClawd server)
2. Create a webhook for the channel:
   - Channel Settings → Integrations → Webhooks → New Webhook
3. Add the webhook to `webhooks.json`:

```json
{
  "new-channel": {
    "channel_id": "YOUR_CHANNEL_ID",
    "webhook_id": "YOUR_WEBHOOK_ID",
    "webhook_url": "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_TOKEN"
  }
}
```

4. Update agents to use the new channel

## Security Notes

- **Webhook URLs are secrets** — do not commit to public repos
- This file is in the private bounty drive at `/mnt/bounty/Claude/`
- Webhook tokens can be rotated in Discord if compromised
- All posts are logged in agent audit trails

## Troubleshooting

### "No webhook found"
- Check channel name spelling in `webhooks.json`
- Verify the channel exists in the JSON file

### "Failed: 404"
- Webhook was deleted in Discord
- Recreate webhook and update `webhooks.json`

### "Failed: 429"
- Rate limit exceeded
- Add delays between posts
- Reduce message frequency

### Message not appearing
- Check Discord channel permissions
- Verify webhook URL is correct
- Check for empty/null messages

---

**File:** `/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json`
**Maintained by:** rainkode
**Last updated:** 2026-02-23
