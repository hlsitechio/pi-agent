# Pi Agent Swarm Architecture
> RainKode CyberOps — Full 24/7 Autonomous Operations
> Designed: 2026-02-23 | Last Updated: 2026-02-23

---

## Agent Lifecycle Classes

| Class | Symbol | Behavior | Example |
|-------|--------|----------|---------|
| **SENTINEL** | 🔴 | Never sleeps. Runs 24/7. Daemon loop. | VPN watchdog, capture monitor |
| **CRON** | 🕐 | Wakes on schedule, runs task, sleeps. | HackerNews every 30m, CVE check every 15m |
| **ON-DEMAND** | ⚡ | Orchestrator dispatches when needed. | Nmap scan, SQLi test, nuclei run |
| **REACTIVE** | 🔔 | Triggered by events (webhook, DB change, file). | New scope alert, capture notification |

---

## Model Assignment Strategy

| Model | Cost | Use Case | Agents |
|-------|------|----------|--------|
| **MiniMax M2.5** (Ollama) | FREE | Analysis, triage, intel processing | 21 Pi-powered agents |
| **NONE** (pure bash) | FREE | Health checks, monitors, infra | 12 bash-only agents |
| **Claude Opus** (Orchestrator) | $$$$ | Exploitation, complex chains | Manual — the human's weapon |

**Rule: Ollama (free) for ALL automated agents. Anthropic models only for orchestrator-dispatched critical tasks.**

---

## THE SWARM — Complete Agent Registry (33 Agents)

---

### TIER 0: OBSERVE — Intel Collection & Passive Surveillance

These agents watch the world. They pull data from external feeds, detect new CVEs, track exploit releases, and monitor scope changes. No interaction with targets.

| # | Agent | Model | Class | Schedule | Lines | Description |
|---|-------|-------|-------|----------|-------|-------------|
| 1 | `hackernews-agent` | Pi (MiniMax M2.5) | CRON 🕐 | `*/30 * * * *` (every 30m) | 259 | Scrapes HackerNews for security-relevant stories, filters by keywords, posts to Discord |
| 2 | `cve-monitor` | Pi (MiniMax M2.5) | CRON 🕐 | `*/15 * * * *` (every 15m) | 331 | Polls NVD/MITRE for new CVEs matching in-scope technologies |
| 3 | `cve-master` | Pi (MiniMax M2.5) | CRON 🕐 | `5,20,35,50 * * * *` (offset 15m) | 413 | Deep CVE analysis — enriches raw CVEs with CVSS, affected products, exploitability |
| 4 | `exploit-db-watcher` | Pi (MiniMax M2.5) | CRON 🕐 | `0 * * * *` (every hour) | 257 | Monitors Exploit-DB for new public exploits matching scope |
| 5 | `scope-watcher` | Pi (MiniMax M2.5) | CRON 🕐 | `0 */6 * * *` (every 6h) | 449 | Watches HackerOne/Intigriti for scope changes — new assets trigger recon chain |
| 6 | `threat-intel-aggregator` | Pi (MiniMax M2.5) | CRON 🕐 | `0 */2 * * *` (every 2h) | 354 | Aggregates threat intel from multiple OSINT feeds into unified format |
| 7 | `capture-monitor` | NONE (bash) | CRON 🕐 | `*/10 * * * *` (every 10m) | 132 | BotHeaven credential capture tracker — monitors honeypot for new captures |
| 8 | `trap-monitor` | NONE (bash) | CRON 🕐 | `*/10 * * * *` (every 10m) | 163 | BotHeaven honeypot trap hit tracker — detects and logs attacker interactions |

---

### TIER 1: MONITOR — Swarm Health, OPSEC & Analytics

These agents keep the swarm alive and safe. OPSEC agents run first — if they go red, everything pauses. Infrastructure monitors watch services. Analytics agents process intel from Tier 0.

| # | Agent | Model | Class | Schedule | Lines | Description |
|---|-------|-------|-------|----------|-------|-------------|
| 9 | `vpn-sentinel` | NONE (bash) | SENTINEL 🔴 | `*/5 * * * *` (every 5m) | 133 | VPN connection watchdog — if DOWN, alerts #opsec-alerts, pauses all hunting agents |
| 10 | `opsec-guardian` | NONE (bash) | SENTINEL 🔴 | `*/10 * * * *` (every 10m) | 327 | System security posture monitor — checks IP exposure, DNS leaks, sets /tmp/opsec-red flag |
| 11 | `rate-monitor` | NONE (bash) | SENTINEL 🔴 | `*/5 * * * *` (every 5m) | 177 | Tracks request rates per target domain — prevents rate-limit tripping and WAF bans |
| 12 | `health-checker` | NONE (bash) | CRON 🕐 | `*/10 * * * *` (every 10m) | 104 | Swarm heartbeat monitor — checks all agent state files, reports dead agents to Discord |
| 13 | `error-watcher` | NONE (bash) | CRON 🕐 | `*/15 * * * *` (every 15m) | 114 | Agent log file monitor — scans cron.log files for errors, alerts on repeated failures |
| 14 | `agent-reviewer` | Pi (MiniMax M2.5) | CRON 🕐 | `0 */6 * * *` (every 6h) | 354 | Reviews agent code quality and output — flags stale agents, suggests improvements |
| 15 | `dispatcher` | NONE (bash) | REACTIVE 🔔 | On trigger | 116 | Command queue processor — reads /state/queue/*.json, dispatches agents on demand |
| 16 | `d3bugr-monitor` | NONE (bash) | CRON 🕐 | `*/10 * * * *` (every 10m) | 110 | Monitors D3BUGR Railway service health and response time |
| 17 | `ollama-monitor` | NONE (bash) | CRON 🕐 | `*/15 * * * *` (every 15m) | 162 | Monitors Ollama service health and model availability |
| 18 | `railway-monitor` | NONE (bash) | CRON 🕐 | `*/30 * * * *` (every 30m) | 140 | Monitors Railway services (d3bugr, nmap, nuclei) for uptime and response |
| 19 | `supabase-monitor` | NONE (bash) | CRON 🕐 | `*/30 * * * *` (every 30m) | 99 | Monitors Supabase project health and database connectivity |
| 20 | `news-analyst` | Pi (MiniMax M2.5) | CRON 🕐 | `15 * * * *` (hourly at :15) | 406 | Deep analysis of HackerNews intel — extracts techniques, correlates with scope |
| 21 | `bounty-triager` | Pi (MiniMax M2.5) | CRON 🕐 | `30 */2 * * *` (every 2h at :30) | 512 | Triages incoming intel — ranks by bounty potential, assigns priority, routes to chains |
| 22 | `cve-scorer` | Pi (MiniMax M2.5) | CRON 🕐 | `0 0 * * 0` (weekly Sun midnight) | 483 | Bulk CVE scoring — re-evaluates all tracked CVEs against current scope |
| 23 | `lead-tracker` | Pi (MiniMax M2.5) | CRON 🕐 | `0 6 * * *` (daily at 6 AM) | 408 | Morning brief generator — summarizes overnight findings, top leads, action items |
| 24 | `technique-librarian` | Pi (MiniMax M2.5) | CRON 🕐 | `0 1 * * 0` (weekly Sun 1 AM) | 417 | Catalogs attack techniques from CVEs and exploits — builds reference library |
| 25 | `bounty-estimator` | Pi (MiniMax M2.5) | CRON 🕐 | `0 */4 * * *` (every 4h) | 533 | Estimates bounty payouts for leads — factors program history, severity, impact |

---

### TIER 2: RECON — Active Reconnaissance

These agents touch targets. They enumerate subdomains, scan ports, and resolve DNS. VPN MUST be active (checked via /tmp/opsec-red flag). Dispatched by chain triggers or on-demand.

| # | Agent | Model | Class | Schedule | Lines | Description |
|---|-------|-------|-------|----------|-------|-------------|
| 26 | `subdomain-enumerator` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 364 | Enumerates subdomains via passive sources + brute — feeds port-scanner |
| 27 | `port-scanner` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 420 | Scans discovered hosts for open ports — uses Railway nmap service |
| 28 | `dns-recon-agent` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 468 | DNS reconnaissance — zone transfers, record enumeration, subdomain takeover checks |

---

### TIER 3: SCAN — Vulnerability Scanning

Active vulnerability detection. Runs nuclei templates and custom checks against discovered services. Requires VPN + valid scope.

| # | Agent | Model | Class | Schedule | Lines | Description |
|---|-------|-------|-------|----------|-------|-------------|
| 29 | `vuln-scanner` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 400 | Runs nuclei vulnerability templates against port-scanner output |

---

### TIER 4: EXPLOIT — Exploitation & Proof-of-Concept

These agents attempt to prove vulnerabilities. They craft payloads, test injection points, and validate findings. High-risk operations — require OPSEC green + scope lock + VPN.

| # | Agent | Model | Class | Schedule | Lines | Description |
|---|-------|-------|-------|----------|-------|-------------|
| 30 | `sqli-hunter` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 402 | SQL injection detection and exploitation — tests parameterized endpoints |
| 31 | `xss-hunter` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 400 | XSS vulnerability detection — reflected, stored, and DOM-based payloads |
| 32 | `ssrf-prober` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 440 | SSRF detection — probes for internal network access via URL parameters |
| 33 | `idor-checker` | Pi (MiniMax M2.5) | ON-DEMAND ⚡ | Chain trigger | 490 | IDOR vulnerability detection — tests access control on object references |

---

## Execution Chains (Pipelines)

Chains define how agents trigger each other. When an upstream agent produces output, it writes a trigger file to `/tmp/swarm-triggers/` that activates the next agent in the chain.

### Pipeline 1: CVE Pipeline
```
cve-monitor → cve-master → bounty-triager → bounty-estimator
```
**Flow:** Detect new CVE → Deep analysis & enrichment → Triage for bounty relevance → Estimate payout value

### Pipeline 2: News Pipeline
```
hackernews-agent → news-analyst → technique-librarian
```
**Flow:** Detect security news → Deep analysis & technique extraction → Catalog into reference library

### Pipeline 3: Scope Pipeline
```
scope-watcher → subdomain-enumerator → port-scanner → vuln-scanner
```
**Flow:** Detect scope change → Enumerate new subdomains → Port scan discovered hosts → Vulnerability scan open services

### Pipeline 4: Exploit Pipeline
```
exploit-db-watcher → bounty-triager
```
**Flow:** Detect new public exploit → Triage for bounty relevance against in-scope targets

### Pipeline 5: Threat Pipeline
```
threat-intel-aggregator → bounty-triager
```
**Flow:** Aggregate threat intel feeds → Triage for bounty relevance

**Trigger method:** File-based (`/tmp/swarm-triggers/`)

---

## Governance & OPSEC

All agents run through `preflight-governance.sh` before execution:

1. **OPSEC Check** — If `/tmp/opsec-red` exists, Tier 2+ agents abort immediately
2. **VPN Check** — Tier 2+ agents verify VPN is active before touching targets
3. **Scope Lock** — Tier 4 agents verify target is in approved scope (`approved-scope.json`)
4. **Rate Limiting** — `rate-monitor` tracks requests per domain, pauses agents if threshold exceeded
5. **Kill Switch** — `/tmp/swarm-halt` stops ALL agents immediately

### Tier Governance Matrix

| Tier | OPSEC Required | VPN Required | Scope Lock | Rate Limited |
|------|---------------|--------------|------------|--------------|
| 0 OBSERVE | No | No | No | No |
| 1 MONITOR | Partial (OPSEC agents exempt) | No | No | No |
| 2 RECON | Yes | Yes | Yes | Yes |
| 3 SCAN | Yes | Yes | Yes | Yes |
| 4 EXPLOIT | Yes | Yes | Yes (strict) | Yes |

---

## Swarm Statistics

| Metric | Value |
|--------|-------|
| **Total Agents** | 33 |
| **Pi-Powered (MiniMax M2.5)** | 21 |
| **Bash-Only (NONE)** | 12 |
| **Total Lines of Code** | 10,337 |
| **Cron Entries** | 24 |
| **On-Demand Agents** | 8 (dispatcher + recon/scan/exploit) |
| **Reactive Agents** | 1 (dispatcher) |
| **Execution Chains** | 5 pipelines |
| **Tier 0 (OBSERVE)** | 8 agents |
| **Tier 1 (MONITOR)** | 17 agents |
| **Tier 2 (RECON)** | 3 agents |
| **Tier 3 (SCAN)** | 1 agent |
| **Tier 4 (EXPLOIT)** | 4 agents |

### Cron Schedule Density

```
Every 5 min:   vpn-sentinel, rate-monitor                           (2 agents)
Every 10 min:  opsec-guardian, health-checker, d3bugr-monitor,
               capture-monitor, trap-monitor                        (5 agents)
Every 15 min:  cve-monitor, cve-master (offset), error-watcher,
               ollama-monitor                                       (4 agents)
Every 30 min:  hackernews-agent, supabase-monitor, railway-monitor  (3 agents)
Hourly:        exploit-db-watcher, news-analyst                     (2 agents)
Every 2h:      threat-intel-aggregator, bounty-triager              (2 agents)
Every 4h:      bounty-estimator                                     (1 agent)
Every 6h:      scope-watcher, agent-reviewer                        (2 agents)
Daily:         lead-tracker (6 AM)                                  (1 agent)
Weekly:        cve-scorer (Sun 00:00), technique-librarian (Sun 01:00) (2 agents)
```

### Cost Profile

```
Ollama (local):     21 agents × FREE = $0/month
Bash-only:          12 agents × FREE = $0/month
────────────────────────────────────────────────
Automated swarm:    $0/month
Claude Opus:        Orchestrator-only (manual dispatch)
```

---

## Infrastructure Dependencies

| Service | Purpose | Monitored By |
|---------|---------|--------------|
| **Ollama** (local) | LLM inference for Pi agents | `ollama-monitor` |
| **Railway** (cloud) | d3bugr, nmap, nuclei services | `railway-monitor`, `d3bugr-monitor` |
| **Supabase** (cloud) | Database, findings storage | `supabase-monitor` |
| **Discord** (webhooks) | Alert channels, status posts | All agents via `webhooks.json` |
| **NordVPN** | OPSEC — all target-facing traffic | `vpn-sentinel` |
| **BotHeaven** (honeypot) | Credential captures, trap hits | `capture-monitor`, `trap-monitor` |

---

## File Structure

```
/mnt/bounty/Claude/pi-agents/
├── swarm-blueprint/               # Architecture, governance, configs
│   ├── SWARM-ARCHITECTURE.md      # This file
│   ├── GOVERNANCE.md              # Governance rules
│   ├── GOVERNANCE-GUIDE.md        # Governance implementation guide
│   ├── NEW-AGENT-GUIDE.md         # How to add new agents
│   ├── WEBHOOKS.md                # Discord webhook documentation
│   ├── chain-config.json          # Pipeline definitions
│   ├── webhooks.json              # Discord webhook URLs
│   ├── approved-scope.json        # Approved target scope
│   ├── preflight-governance.sh    # Governance pre-flight checks
│   ├── swarm-crontab.conf         # Master crontab
│   ├── install-crontab.sh         # Crontab installer
│   ├── cron-health-check.sh       # Cron health verification
│   └── generate-readmes.sh        # README generator for agents
│
├── {agent-name}/                  # Each agent directory
│   ├── run.sh                     # Entry point (all agents)
│   ├── extension.ts               # Pi logic (Pi-powered agents only)
│   └── state/                     # Runtime state
│       ├── last-run.log           # Latest execution output
│       ├── cron.log               # Cron execution history
│       └── *.json                 # Agent-specific state files
```

---

> *"33 agents. Zero dollars. Full spectrum coverage."*
> — RainKode CyberOps Swarm v2
