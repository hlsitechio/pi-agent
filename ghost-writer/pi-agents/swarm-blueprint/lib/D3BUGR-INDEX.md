# D3BUGR Bridge — File Index

Quick navigation for the d3bugr bridge extension library.

## Start Here

🚀 **New to d3bugr bridge?** Start with:
1. [D3BUGR-QUICK-REFERENCE.md](./D3BUGR-QUICK-REFERENCE.md) — Fast start guide
2. [test-d3bugr-bridge.sh](./test-d3bugr-bridge.sh) — Verify setup
3. [example-agent-integration.ts](./example-agent-integration.ts) — See integration examples

## Files by Purpose

### Core Libraries (Use These)

| File | Purpose | When to Use |
|------|---------|-------------|
| [d3bugr-bridge.sh](./d3bugr-bridge.sh) | Shell function library | Bash scripts, cron jobs |
| [d3bugr-bridge.ts](./d3bugr-bridge.ts) | TypeScript direct API | Custom workflows, standalone scripts |
| [d3bugr-tools-extension.ts](./d3bugr-tools-extension.ts) | Pi tool registration | Native Pi agent integration |

### Documentation (Read These)

| File | Purpose | When to Read |
|------|---------|--------------|
| [D3BUGR-QUICK-REFERENCE.md](./D3BUGR-QUICK-REFERENCE.md) | Quick reference card | Need fast syntax lookup |
| [D3BUGR-BRIDGE-README.md](./D3BUGR-BRIDGE-README.md) | Comprehensive guide | Need detailed examples |
| [D3BUGR-INTEGRATION-SUMMARY.md](./D3BUGR-INTEGRATION-SUMMARY.md) | Complete task summary | Need full overview |

### Examples & Testing (Try These)

| File | Purpose | When to Use |
|------|---------|-------------|
| [example-agent-integration.ts](./example-agent-integration.ts) | Integration patterns | Building new agent |
| [test-d3bugr-bridge.sh](./test-d3bugr-bridge.sh) | Health validation | Verifying setup |

## Quick Links by Task

### "I want to add d3bugr to my bash script"
→ Read: [d3bugr-bridge.sh](./d3bugr-bridge.sh)
→ Example:
```bash
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/d3bugr-bridge.sh
d3bugr_subfinder "example.com"
```

### "I want to add d3bugr to my TypeScript code"
→ Read: [d3bugr-bridge.ts](./d3bugr-bridge.ts)
→ Example:
```typescript
import * as d3bugr from "../swarm-blueprint/lib/d3bugr-bridge";
await d3bugr.subfinder("example.com");
```

### "I want to add d3bugr to my Pi agent"
→ Read: [d3bugr-tools-extension.ts](./d3bugr-tools-extension.ts)
→ Example:
```typescript
import { registerD3bugrTools } from "../swarm-blueprint/lib/d3bugr-tools-extension";
export default function defineTools(tools: any) {
  registerD3bugrTools(tools);
}
```

### "I want to see complete integration examples"
→ Read: [example-agent-integration.ts](./example-agent-integration.ts)
→ Contains: 3 integration methods, custom composite tools, real workflows

### "I need quick syntax reference"
→ Read: [D3BUGR-QUICK-REFERENCE.md](./D3BUGR-QUICK-REFERENCE.md)
→ Contains: Common tools table, one-liners, OPSEC patterns

### "I need detailed documentation"
→ Read: [D3BUGR-BRIDGE-README.md](./D3BUGR-BRIDGE-README.md)
→ Contains: Full tool catalog, usage examples, error handling

### "I want to verify my setup"
→ Run: [test-d3bugr-bridge.sh](./test-d3bugr-bridge.sh)
→ Tests: Health check, function exports, service availability

## Available Tools by Category

### Reconnaissance
- `subfinder` — Subdomain enumeration
- `httpx` — HTTP probing
- `katana` — Web crawling
- `harvest` — OSINT gathering

### Vulnerability Scanning
- `nuclei` — Template-based scanning
- `nucleiQuick` — Fast scan
- `nucleiCves` — CVE detection
- `nucleiTech` — Technology detection
- `nucleiExposures` — Exposure detection
- `nucleiMisconfigs` — Misconfiguration detection
- `nikto` — Web server scanning

### Web Application
- `dalfox` — XSS scanning
- `sqlmap` — SQL injection testing
- `ffuf` — Directory fuzzing
- `feroxbuster` — Recursive fuzzing
- `arjun` — Parameter discovery

### Port Scanning
- `nmap` — Port scanning
- `nmapQuick` — Fast port scan

### DNS & Network
- `dnsLookup` — DNS queries
- `dnsWhois` — WHOIS lookup
- `dnsReverse` — Reverse DNS
- `dnsZoneTransfer` — Zone transfer
- `dnsDnssec` — DNSSEC validation

### Intelligence
- `shodanIp` — IP intelligence
- `shodanSearch` — Shodan queries
- `shodanCve` — CVE searches
- `shodanDns` — DNS lookups

### Secret Scanning
- `trufflehogGithub` — GitHub secrets
- `trufflehogS3` — S3 bucket secrets
- `trufflehogDocker` — Docker image secrets

### Browser Automation
- `cdpConnect` — Connect to URL
- `cdpScreenshot` — Capture screenshots
- `cdpExecute` — Execute JavaScript
- `cdpCookies` — Extract cookies
- `cdpLocalStorage` — Extract storage
- `cdpWebrtcLeak` — WebRTC leak test
- `cdpFingerprint` — Browser fingerprinting

### WinRM
- `winrmRecon` — WinRM reconnaissance
- `winrmCheck` — Availability check
- `winrmExec` — Command execution

### Geolock
- `geolockCreate` — Create session
- `geolockSessions` — List sessions
- `geolockResults` — Get results

## Response Format

All tools return:
```typescript
{
  success: boolean,
  data?: any,
  error?: string
}
```

## Gateway Information

- **URL**: https://d3bugr-production.up.railway.app
- **Health**: https://d3bugr-production.up.railway.app/health
- **Status**: Check with `d3bugr_health` (shell) or `d3bugr.health()` (TypeScript)

## File Statistics

| File | Size | Lines | Purpose |
|------|------|-------|---------|
| d3bugr-bridge.sh | 7.0K | 309 | Shell bridge |
| d3bugr-bridge.ts | 12K | 426 | TypeScript bridge |
| d3bugr-tools-extension.ts | 14K | 502 | Pi registration |
| D3BUGR-BRIDGE-README.md | 11K | 457 | Full docs |
| D3BUGR-INTEGRATION-SUMMARY.md | 11K | 440 | Task summary |
| D3BUGR-QUICK-REFERENCE.md | 5.2K | 188 | Quick reference |
| example-agent-integration.ts | 11K | 448 | Integration examples |
| test-d3bugr-bridge.sh | 1.6K | 79 | Health test |
| **TOTAL** | **72K** | **2,849** | **8 files** |

## Common Workflows

### Full Domain Reconnaissance
```typescript
import { fullSubdomainRecon } from "./d3bugr-bridge";
const recon = await fullSubdomainRecon("example.com");
```

### Quick Web Application Scan
```typescript
import { quickWebAppScan } from "./d3bugr-bridge";
const scan = await quickWebAppScan("https://example.com");
```

### Batch Operations
```typescript
import { runParallel } from "./d3bugr-bridge";
const results = await runParallel([
  { fn: () => d3bugr.dnsLookup("example.com", "A") },
  { fn: () => d3bugr.dnsWhois("example.com") },
  { fn: () => d3bugr.shodanIp("1.2.3.4") }
]);
```

## Support

- **Test Setup**: Run `./test-d3bugr-bridge.sh`
- **Check Service**: Run `d3bugr_health` or `d3bugr.health()`
- **Monitor**: Check `/mnt/bounty/Claude/pi-agents/d3bugr-monitor/state/last-run.json`

## Related Files

- **Agent Utils**: [agent-utils.ts](./agent-utils.ts) — OPSEC, Discord, state management
- **Chain Trigger**: [chain-trigger.sh](./chain-trigger.sh) — Agent chaining

---

**Location**: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/`
**Tasks**: T076-T079
**Status**: ✅ COMPLETE
**Gateway**: https://d3bugr-production.up.railway.app
