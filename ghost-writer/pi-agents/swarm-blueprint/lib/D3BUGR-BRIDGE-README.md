# D3BUGR Bridge — Access 199+ Security Tools from Pi Agents

This library allows Pi agents to access the full d3bugr MCP toolkit without requiring direct MCP access. All tools run on Railway cloud infrastructure at `https://d3bugr-production.up.railway.app`.

## Files

- **d3bugr-bridge.sh** — Shell functions for bash scripts
- **d3bugr-bridge.ts** — Direct API functions for TypeScript
- **d3bugr-tools-extension.ts** — Pi tool registration system

## Usage Examples

### 1. Shell Scripts (Bash)

Source the bridge and call functions directly:

```bash
#!/bin/bash
source /mnt/bounty/Claude/pi-agents/swarm-blueprint/lib/d3bugr-bridge.sh

# Check d3bugr health
STATUS=$(d3bugr_health)
echo "D3BUGR status: $STATUS"

# Enumerate subdomains
SUBS=$(d3bugr_subfinder "example.com")
echo "$SUBS" | jq -r '.subdomains[]'

# Probe for live hosts
d3bugr_httpx "sub1.example.com,sub2.example.com"

# Quick vulnerability scan
d3bugr_nuclei_quick "https://example.com"

# Port scan
d3bugr_nmap "example.com" "top-100"

# XSS scan
d3bugr_dalfox "https://example.com/search?q=test"

# SQL injection test
d3bugr_sqlmap_test "https://example.com/product?id=123"

# Directory fuzzing
d3bugr_ffuf "https://example.com/FUZZ" "common"

# Web crawling
d3bugr_katana "https://example.com" 2

# DNS lookups
d3bugr_dns_lookup "example.com" "A"
d3bugr_dns_whois "example.com"

# OSINT harvesting
d3bugr_harvest_quick "example.com"

# Shodan queries
d3bugr_shodan_ip "1.2.3.4"
d3bugr_shodan_search "apache country:US"
```

### 2. TypeScript Direct API (d3bugr-bridge.ts)

Import functions and use async/await:

```typescript
import * as d3bugr from "../swarm-blueprint/lib/d3bugr-bridge";

async function scanDomain() {
  // Health check
  const health = await d3bugr.health();
  console.log("D3BUGR available:", health.success);

  // Subdomain enumeration
  const subs = await d3bugr.subfinder("example.com");
  if (subs.success) {
    console.log("Subdomains:", subs.data);
  }

  // HTTP probing
  const live = await d3bugr.httpx(subs.data || []);
  console.log("Live hosts:", live.data);

  // Quick vulnerability scan
  const vulns = await d3bugr.nucleiQuick("https://example.com");
  if (vulns.success && vulns.data?.vulnerabilities) {
    console.log("Vulnerabilities found:", vulns.data.vulnerabilities.length);
  }

  // Port scan
  const ports = await d3bugr.nmapQuick("example.com");
  console.log("Open ports:", ports.data?.ports);

  // XSS scan
  const xss = await d3bugr.dalfox("https://example.com/search?q=test");

  // SQL injection test
  const sqli = await d3bugr.sqlmapTest("https://example.com/product?id=123");

  // Directory fuzzing
  const dirs = await d3bugr.ffuf("https://example.com/FUZZ", "common");

  // Web crawling
  const crawl = await d3bugr.katana("https://example.com", 2);
  console.log("Endpoints discovered:", crawl.data?.endpoints);

  // DNS queries
  const dns = await d3bugr.dnsLookup("example.com", "A");
  const whois = await d3bugr.dnsWhois("example.com");

  // OSINT
  const osint = await d3bugr.harvestQuick("example.com");
  console.log("Emails found:", osint.data?.emails);
}

// Use pre-built workflows
async function quickRecon() {
  const recon = await d3bugr.fullSubdomainRecon("example.com");
  console.log({
    subdomains: recon.subdomains.length,
    liveHosts: recon.liveHosts.length,
    vulnerabilities: recon.vulnerabilities.length
  });
}
```

### 3. Pi Tool Registration (d3bugr-tools-extension.ts)

Register d3bugr tools so Pi agents can use them natively:

```typescript
import { registerD3bugrTools } from "../swarm-blueprint/lib/d3bugr-tools-extension";

export default function defineTools(tools: any) {
  // Register all d3bugr tools
  registerD3bugrTools(tools);

  // Now Pi agent can use them like any other tool
  // Example: agent calls d3bugr_subfinder({ domain: "example.com" })
}
```

Or call tools directly without registration:

```typescript
import { callD3bugrTool, runD3bugrBatch, runD3bugrParallel } from "../swarm-blueprint/lib/d3bugr-tools-extension";

// Single tool call
const result = await callD3bugrTool("d3bugr_subfinder", { domain: "example.com" });

// Batch execution (sequential)
const batchResults = await runD3bugrBatch([
  { tool: "d3bugr_subfinder", params: { domain: "example.com" } },
  { tool: "d3bugr_nuclei_quick", params: { target: "https://example.com" } }
]);

// Parallel execution
const parallelResults = await runD3bugrParallel([
  { tool: "d3bugr_dns_lookup", params: { domain: "example.com", record_type: "A" } },
  { tool: "d3bugr_dns_whois", params: { domain: "example.com" } },
  { tool: "d3bugr_shodan_ip", params: { ip: "1.2.3.4" } }
]);
```

## Available Tools

### Reconnaissance
- `subfinder` — Subdomain enumeration
- `httpx` — HTTP probing and metadata extraction
- `katana` — Web crawling and endpoint discovery
- `harvest` / `harvestQuick` — OSINT data gathering

### Vulnerability Scanning
- `nuclei` / `nucleiQuick` — Template-based vulnerability scanning
- `nucleiCves` — CVE-specific scanning
- `nucleiTech` — Technology detection
- `nucleiExposures` — Exposed service detection
- `nucleiMisconfigs` — Misconfiguration detection

### Port Scanning
- `nmap` / `nmapQuick` — Port scanning and service detection

### Web Application Testing
- `dalfox` — XSS vulnerability scanning
- `sqlmap` / `sqlmapTest` — SQL injection testing
- `ffuf` — Fast directory/file fuzzing
- `feroxbuster` — Recursive directory discovery
- `nikto` — Web server scanning
- `arjun` — Parameter discovery

### DNS & Network
- `dnsLookup` — DNS record queries
- `dnsWhois` — Domain WHOIS information
- `dnsReverse` — Reverse DNS lookup
- `dnsZoneTransfer` — Zone transfer attempts
- `dnsDnssec` — DNSSEC validation

### Shodan Integration
- `shodanIp` — IP intelligence lookup
- `shodanSearch` — Custom Shodan queries
- `shodanCve` — CVE-specific searches
- `shodanDns` — DNS record lookups

### Secret Scanning
- `trufflehogGithub` — Scan GitHub repos for secrets
- `trufflehogS3` — Scan S3 buckets
- `trufflehogDocker` — Scan Docker images

### Browser Automation (CDP)
- `cdpConnect` — Connect to URL via Chrome
- `cdpScreenshot` — Capture screenshots
- `cdpExecute` — Execute JavaScript
- `cdpCookies` — Extract cookies
- `cdpLocalStorage` — Extract localStorage
- `cdpWebrtcLeak` — Test for WebRTC IP leaks
- `cdpFingerprint` — Browser fingerprinting

### WinRM Exploitation
- `winrmRecon` — WinRM service reconnaissance
- `winrmCheck` — Check WinRM availability
- `winrmExec` — Execute commands via WinRM

### Geolock Testing
- `geolockCreate` — Create geo-restricted test session
- `geolockSessions` — List active sessions
- `geolockResults` — Get session results

## Response Format

All functions return a consistent response structure:

```typescript
{
  success: boolean;
  data?: any;          // Tool-specific results
  error?: string;      // Error message if failed
}
```

## Error Handling

```typescript
const result = await d3bugr.subfinder("example.com");

if (!result.success) {
  console.error("D3BUGR error:", result.error);
  return;
}

console.log("Success:", result.data);
```

## Workflow Helpers

Pre-built reconnaissance workflows:

```typescript
import { fullSubdomainRecon, quickWebAppScan } from "../swarm-blueprint/lib/d3bugr-bridge";

// Full subdomain recon (enum → probe → scan)
const recon = await fullSubdomainRecon("example.com");

// Quick web app assessment (crawl + tech detect + vuln scan)
const webapp = await quickWebAppScan("https://example.com");
```

## Batch Operations

Execute multiple tools efficiently:

```typescript
import { runBatch, runParallel } from "../swarm-blueprint/lib/d3bugr-bridge";

// Sequential execution
const batchResults = await runBatch([
  { fn: () => d3bugr.subfinder("example.com") },
  { fn: () => d3bugr.httpx("example.com") }
]);

// Parallel execution (faster)
const parallelResults = await runParallel([
  { fn: () => d3bugr.dnsLookup("example.com", "A") },
  { fn: () => d3bugr.dnsWhois("example.com") },
  { fn: () => d3bugr.shodanIp("1.2.3.4") }
]);
```

## Integration with Pi Agents

### Agent Extension Example

```typescript
import { registerD3bugrTools } from "../swarm-blueprint/lib/d3bugr-tools-extension";
import { checkOpsec, postToDiscord, appendAudit } from "../swarm-blueprint/lib/agent-utils";

export default function defineTools(tools: any) {
  // Register d3bugr tools
  registerD3bugrTools(tools);

  // Custom tool that uses d3bugr
  tools.recon_domain = {
    description: "Full domain reconnaissance using d3bugr tools",
    parameters: {
      type: "object",
      properties: {
        domain: { type: "string", description: "Target domain" }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string }) => {
      // OPSEC check
      const opsec = await checkOpsec("recon-agent");
      if (!opsec.ok) {
        return { error: opsec.reason };
      }

      // Call d3bugr tools
      const subs = await tools.d3bugr_subfinder.execute({ domain: args.domain });
      const probe = await tools.d3bugr_httpx.execute({ targets: subs.data?.join(",") });

      // Post results to Discord
      await postToDiscord("recon",
        `[RECON] ${args.domain}\nSubdomains: ${subs.data?.length || 0}\nLive: ${probe.data?.length || 0}`,
        "Recon Agent"
      );

      // Audit log
      await appendAudit("/mnt/bounty/Claude/pi-agents/recon-agent/state", "recon-agent", 2,
        `Scanned ${args.domain}: ${subs.data?.length || 0} subdomains`);

      return {
        subdomains: subs.data || [],
        liveHosts: probe.data || []
      };
    }
  };
}
```

## OPSEC Notes

- All d3bugr tools run on **Railway cloud infrastructure**
- Scans originate from **Railway IPs**, not your local IP
- No local tool installation required
- Safe for use behind VPN (your IP is never exposed to targets)
- Rate limiting is handled by the d3bugr service

## Health Monitoring

Check d3bugr availability before running operations:

```bash
# Shell
STATUS=$(d3bugr_health)
if [ "$STATUS" = "200" ]; then
  echo "D3BUGR online"
else
  echo "D3BUGR offline: $STATUS"
fi
```

```typescript
// TypeScript
const health = await d3bugr.health();
if (!health.success) {
  console.error("D3BUGR unavailable:", health.error);
  process.exit(1);
}
```

## API Endpoint

All tools communicate with:
```
https://d3bugr-production.up.railway.app/api/tools/{tool_name}
```

Health check:
```
https://d3bugr-production.up.railway.app/health
```

## Support

For d3bugr infrastructure issues, check:
- Railway dashboard: https://railway.app/
- d3bugr monitor agent: `/mnt/bounty/Claude/pi-agents/d3bugr-monitor/`
- Last known status: `/mnt/bounty/Claude/pi-agents/d3bugr-monitor/state/last-run.json`
