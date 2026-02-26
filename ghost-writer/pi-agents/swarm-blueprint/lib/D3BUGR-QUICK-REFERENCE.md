# D3BUGR Bridge — Quick Reference Card

## 🚀 Fast Start

### Shell (Bash)
```bash
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/d3bugr-bridge.sh
d3bugr_health                              # Check service
d3bugr_subfinder "example.com"             # Enum subdomains
d3bugr_nuclei_quick "https://example.com"  # Scan vulns
```

### TypeScript
```typescript
import * as d3bugr from "../swarm-blueprint/lib/d3bugr-bridge";
const health = await d3bugr.health();
const subs = await d3bugr.subfinder("example.com");
const vulns = await d3bugr.nucleiQuick("https://example.com");
```

### Pi Agent Extension
```typescript
import { registerD3bugrTools } from "../swarm-blueprint/lib/d3bugr-tools-extension";

export default function defineTools(tools: any) {
  registerD3bugrTools(tools);  // +30 tools instantly
}
```

## 📋 Common Tools

| Tool | Purpose | Example |
|------|---------|---------|
| `subfinder` | Enumerate subdomains | `d3bugr.subfinder("example.com")` |
| `httpx` | Probe HTTP services | `d3bugr.httpx("host1.com,host2.com")` |
| `nucleiQuick` | Fast vuln scan | `d3bugr.nucleiQuick("https://example.com")` |
| `nmapQuick` | Quick port scan | `d3bugr.nmapQuick("example.com")` |
| `dalfox` | XSS scanning | `d3bugr.dalfox("https://example.com/search?q=test")` |
| `sqlmapTest` | SQL injection test | `d3bugr.sqlmapTest("https://example.com/product?id=1")` |
| `ffuf` | Directory fuzzing | `d3bugr.ffuf("https://example.com/FUZZ", "common")` |
| `katana` | Web crawling | `d3bugr.katana("https://example.com", 2)` |
| `dnsLookup` | DNS queries | `d3bugr.dnsLookup("example.com", "A")` |
| `harvestQuick` | OSINT gathering | `d3bugr.harvestQuick("example.com")` |
| `shodanIp` | IP intel | `d3bugr.shodanIp("1.2.3.4")` |

## 🔥 One-Liners

### Full Domain Recon
```typescript
import { fullSubdomainRecon } from "./d3bugr-bridge";
const recon = await fullSubdomainRecon("example.com");
// Returns: { subdomains, liveHosts, vulnerabilities }
```

### Quick Web App Scan
```typescript
import { quickWebAppScan } from "./d3bugr-bridge";
const scan = await quickWebAppScan("https://example.com");
// Returns: { endpoints, technologies, vulnerabilities }
```

## 🛡️ OPSEC Pattern

```typescript
import { checkOpsec } from "./agent-utils";
import * as d3bugr from "./d3bugr-bridge";

const opsec = await checkOpsec("agent-name");
if (!opsec.ok) return;

const result = await d3bugr.subfinder("example.com");
if (!result.success) {
  console.error(result.error);
  return;
}
```

## 📊 Response Format

```typescript
{
  success: boolean,    // true if tool executed
  data?: any,         // tool results
  error?: string      // error message if failed
}
```

## 🔧 Batch Operations

### Sequential
```typescript
import { runBatch } from "./d3bugr-bridge";
const results = await runBatch([
  { fn: () => d3bugr.subfinder("example.com") },
  { fn: () => d3bugr.httpx("example.com") }
]);
```

### Parallel (faster)
```typescript
import { runParallel } from "./d3bugr-bridge";
const results = await runParallel([
  { fn: () => d3bugr.dnsLookup("example.com", "A") },
  { fn: () => d3bugr.dnsWhois("example.com") },
  { fn: () => d3bugr.shodanIp("1.2.3.4") }
]);
```

## 📁 File Locations

| File | Purpose | Size |
|------|---------|------|
| `d3bugr-bridge.sh` | Shell functions | 7.0K |
| `d3bugr-bridge.ts` | TypeScript API | 12K |
| `d3bugr-tools-extension.ts` | Pi tool registration | 14K |
| `D3BUGR-BRIDGE-README.md` | Full documentation | 11K |
| `example-agent-integration.ts` | Integration examples | 11K |
| `test-d3bugr-bridge.sh` | Health test script | 1.6K |

All files in: `/mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/`

## ✅ Health Check

```bash
# Shell
d3bugr_health  # Returns HTTP status code

# TypeScript
const health = await d3bugr.health();
console.log(health.success);  // true if online
```

## 🎯 Integration Methods

1. **Shell** — Source bridge, call functions
2. **Direct API** — Import bridge, use async functions
3. **Pi Registration** — Import extension, register all tools

Choose based on your agent's needs. See `D3BUGR-BRIDGE-README.md` for details.

## 🔗 Links

- Gateway: `https://d3bugr-production.up.railway.app`
- Health: `https://d3bugr-production.up.railway.app/health`
- Full Docs: `D3BUGR-BRIDGE-README.md`
- Examples: `example-agent-integration.ts`
- Test: `./test-d3bugr-bridge.sh`

## 💡 Pro Tips

- All tools run on Railway IPs (OPSEC safe)
- Always check health before operations
- Use parallel execution for independent queries
- Combine tools for custom workflows
- Check `example-agent-integration.ts` for patterns

---

**Quick Start**: `./test-d3bugr-bridge.sh` to verify setup
