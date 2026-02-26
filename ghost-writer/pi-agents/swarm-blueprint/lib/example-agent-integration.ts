/**
 * EXAMPLE: Pi Agent Integration with D3BUGR Bridge
 *
 * This demonstrates three ways to integrate d3bugr tools into a Pi agent:
 * 1. Tool Registration (recommended for Pi framework)
 * 2. Direct API calls (for custom workflows)
 * 3. Hybrid approach (mix both methods)
 */

import { registerD3bugrTools, callD3bugrTool, runD3bugrParallel } from "./d3bugr-tools-extension";
import * as d3bugr from "./d3bugr-bridge";
import { checkOpsec, postToDiscord, appendAudit, saveState } from "./agent-utils";

// === METHOD 1: Tool Registration ===
// Use this when you want Pi to call d3bugr tools like any other tool

export function method1_RegisterTools(tools: any) {
  // Register ALL d3bugr tools at once
  registerD3bugrTools(tools);

  // Now Pi agent can call:
  // - d3bugr_subfinder({ domain: "example.com" })
  // - d3bugr_nuclei({ target: "https://example.com" })
  // - d3bugr_httpx({ targets: "host1.com,host2.com" })
  // etc.

  console.log("[+] Registered 30+ d3bugr tools");
}

// === METHOD 2: Direct API Calls ===
// Use this for custom workflows that combine multiple tools

async function method2_DirectWorkflow(domain: string) {
  // OPSEC check first
  const opsec = await checkOpsec("recon-agent");
  if (!opsec.ok) {
    console.error(`[!] OPSEC FAIL: ${opsec.reason}`);
    return null;
  }

  console.log(`[*] Starting recon on ${domain}`);

  // 1. Check d3bugr health
  const health = await d3bugr.health();
  if (!health.success) {
    console.error("[!] D3BUGR offline");
    return null;
  }

  // 2. Subdomain enumeration
  console.log("[*] Enumerating subdomains...");
  const subs = await d3bugr.subfinder(domain);
  if (!subs.success) {
    console.error(`[!] Subfinder failed: ${subs.error}`);
    return null;
  }

  const subdomains = subs.data || [];
  console.log(`[+] Found ${subdomains.length} subdomains`);

  // 3. Probe for live hosts (parallel for speed)
  console.log("[*] Probing for live hosts...");
  const probe = await d3bugr.httpx(subdomains);
  const liveHosts = probe.success ? probe.data : [];
  console.log(`[+] Found ${liveHosts.length} live hosts`);

  // 4. Quick vulnerability scan on top 5 targets
  console.log("[*] Scanning for vulnerabilities...");
  const vulnResults = await runD3bugrParallel(
    liveHosts.slice(0, 5).map(host => ({
      tool: "d3bugr_nuclei_quick",
      params: { target: host.url || host }
    }))
  );

  const vulnerabilities = vulnResults
    .filter(r => r.success)
    .flatMap(r => r.data?.vulnerabilities || []);

  console.log(`[+] Found ${vulnerabilities.length} vulnerabilities`);

  // 5. Save state
  const stateDir = "/mnt/bounty/Claude/pi-agents/example-agent/state";
  await saveState(stateDir, {
    domain,
    subdomains: subdomains.length,
    liveHosts: liveHosts.length,
    vulnerabilities: vulnerabilities.length,
    lastScan: new Date().toISOString()
  });

  // 6. Post to Discord
  await postToDiscord(
    "recon",
    `**Recon Complete: ${domain}**\n` +
    `Subdomains: ${subdomains.length}\n` +
    `Live Hosts: ${liveHosts.length}\n` +
    `Vulnerabilities: ${vulnerabilities.length}`,
    "Recon Agent"
  );

  // 7. Audit log
  await appendAudit(stateDir, "recon-agent", 2,
    `Completed recon for ${domain}: ${subdomains.length} subs, ${vulnerabilities.length} vulns`);

  return {
    domain,
    subdomains,
    liveHosts,
    vulnerabilities
  };
}

// === METHOD 3: Hybrid Approach ===
// Register tools for Pi, but also create custom composite tools

export function method3_HybridSetup(tools: any) {
  // 1. Register all d3bugr tools
  registerD3bugrTools(tools);

  // 2. Add custom composite tools that use d3bugr internally
  tools.full_recon = {
    description: "Full reconnaissance: subdomain enum + probing + vulnerability scan",
    parameters: {
      type: "object",
      properties: {
        domain: {
          type: "string",
          description: "Target domain (e.g., example.com)"
        },
        maxTargets: {
          type: "number",
          description: "Maximum number of targets to scan deeply",
          default: 5
        }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string; maxTargets?: number }) => {
      // OPSEC check
      const opsec = await checkOpsec("recon-agent");
      if (!opsec.ok) {
        return { error: opsec.reason };
      }

      const maxTargets = args.maxTargets || 5;

      // Use d3bugr bridge directly
      const subs = await d3bugr.subfinder(args.domain);
      if (!subs.success) {
        return { error: `Subfinder failed: ${subs.error}` };
      }

      const probe = await d3bugr.httpx(subs.data || []);
      const liveHosts = probe.success ? probe.data : [];

      // Parallel vulnerability scanning
      const vulnScans = await runD3bugrParallel(
        liveHosts.slice(0, maxTargets).map(host => ({
          tool: "d3bugr_nuclei_quick",
          params: { target: host.url || host }
        }))
      );

      const vulnerabilities = vulnScans
        .filter(r => r.success)
        .flatMap(r => r.data?.vulnerabilities || []);

      // Save and report
      const stateDir = "/mnt/bounty/Claude/pi-agents/recon-agent/state";
      await saveState(stateDir, {
        domain: args.domain,
        subdomains: subs.data?.length || 0,
        liveHosts: liveHosts.length,
        vulnerabilities: vulnerabilities.length,
        timestamp: new Date().toISOString()
      });

      await postToDiscord(
        "recon",
        `[FULL-RECON] ${args.domain}\n` +
        `Subdomains: ${subs.data?.length || 0}\n` +
        `Live: ${liveHosts.length}\n` +
        `Vulnerabilities: ${vulnerabilities.length}`,
        "Recon Agent"
      );

      return {
        success: true,
        subdomains: subs.data || [],
        liveHosts,
        vulnerabilities
      };
    }
  };

  tools.quick_webapp_scan = {
    description: "Quick web application scan: crawl + tech detection + vulnerability scan",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL (e.g., https://example.com)"
        },
        crawlDepth: {
          type: "number",
          description: "Crawl depth (1-5)",
          default: 2
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string; crawlDepth?: number }) => {
      const opsec = await checkOpsec("webapp-agent");
      if (!opsec.ok) {
        return { error: opsec.reason };
      }

      // Run three scans in parallel
      const results = await Promise.all([
        d3bugr.katana(args.url, args.crawlDepth || 2),
        d3bugr.nucleiTech(args.url),
        d3bugr.nucleiQuick(args.url)
      ]);

      const [crawl, tech, vulns] = results;

      // Save findings
      const stateDir = "/mnt/bounty/Claude/pi-agents/webapp-agent/state";
      await saveState(stateDir, {
        url: args.url,
        endpoints: crawl.data?.endpoints?.length || 0,
        technologies: tech.data?.technologies?.length || 0,
        vulnerabilities: vulns.data?.vulnerabilities?.length || 0,
        timestamp: new Date().toISOString()
      });

      await postToDiscord(
        "webapp",
        `[WEBAPP-SCAN] ${args.url}\n` +
        `Endpoints: ${crawl.data?.endpoints?.length || 0}\n` +
        `Tech: ${tech.data?.technologies?.join(", ") || "none"}\n` +
        `Vulns: ${vulns.data?.vulnerabilities?.length || 0}`,
        "WebApp Agent"
      );

      return {
        success: true,
        endpoints: crawl.data?.endpoints || [],
        technologies: tech.data?.technologies || [],
        vulnerabilities: vulns.data?.vulnerabilities || []
      };
    }
  };

  tools.domain_intel = {
    description: "Gather domain intelligence: DNS, WHOIS, Shodan",
    parameters: {
      type: "object",
      properties: {
        domain: {
          type: "string",
          description: "Target domain"
        }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string }) => {
      const opsec = await checkOpsec("intel-agent");
      if (!opsec.ok) {
        return { error: opsec.reason };
      }

      // Parallel intelligence gathering
      const results = await Promise.all([
        d3bugr.dnsLookup(args.domain, "A"),
        d3bugr.dnsLookup(args.domain, "MX"),
        d3bugr.dnsWhois(args.domain),
        d3bugr.harvestQuick(args.domain)
      ]);

      const [aRecords, mxRecords, whois, osint] = results;

      // If we have IPs, query Shodan
      const ips = aRecords.data?.answers?.map((r: any) => r.data) || [];
      const shodanResults = await Promise.all(
        ips.slice(0, 3).map(ip => d3bugr.shodanIp(ip))
      );

      const intel = {
        domain: args.domain,
        dns: {
          a: aRecords.data,
          mx: mxRecords.data
        },
        whois: whois.data,
        osint: osint.data,
        shodan: shodanResults.filter(r => r.success).map(r => r.data)
      };

      await postToDiscord(
        "intel",
        `[DOMAIN-INTEL] ${args.domain}\n` +
        `IPs: ${ips.length}\n` +
        `Emails: ${osint.data?.emails?.length || 0}\n` +
        `Shodan Hits: ${intel.shodan.length}`,
        "Intel Agent"
      );

      return { success: true, intel };
    }
  };

  console.log("[+] Registered d3bugr tools + 3 custom composite tools");
}

// === USAGE EXAMPLES ===

// Example 1: Using registered tools
async function example1_UseRegisteredTool() {
  // After calling method1_RegisterTools(), Pi agent can:
  const result = await callD3bugrTool("d3bugr_subfinder", { domain: "example.com" });
  console.log("Subdomains:", result.data);
}

// Example 2: Using direct API
async function example2_UseDirectAPI() {
  const result = await method2_DirectWorkflow("example.com");
  console.log("Recon results:", result);
}

// Example 3: Using composite tools
async function example3_UseCompositeTool() {
  // After calling method3_HybridSetup(), Pi agent has access to full_recon:
  const result = await callD3bugrTool("full_recon", {
    domain: "example.com",
    maxTargets: 3
  });
  console.log("Full recon:", result);
}

// === REAL AGENT EXTENSION TEMPLATE ===

export default function defineTools(tools: any) {
  // Choose your integration method:

  // Option A: Just register d3bugr tools
  // registerD3bugrTools(tools);

  // Option B: Register d3bugr tools + add custom composite tools
  method3_HybridSetup(tools);

  // Option C: Don't register, build everything custom using d3bugr.* functions
  // (see method2_DirectWorkflow for examples)
}
