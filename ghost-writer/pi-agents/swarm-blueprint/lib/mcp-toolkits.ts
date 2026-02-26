/**
 * MCP Toolkits for Pi Agents
 *
 * Shared tool registration module. Each agent imports role-based functions
 * and gets MCP-equivalent tools registered via pi.registerTool().
 *
 * Usage:
 *   import { registerBaseTools, registerIntelTools, registerResearchTools } from "../swarm-blueprint/lib/mcp-toolkits";
 *   registerBaseTools(pi, "hackernews-agent");
 *   registerIntelTools(pi);
 *   registerResearchTools(pi);
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// === CONFIG ===
const D3BUGR_HOST = "https://d3bugr-production.up.railway.app";
const WEBHOOKS_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json";
const SUPABASE_CONFIG = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/supabase-config.env";

// === INTERNAL HELPERS ===

function toolResult(text: string, details: Record<string, any> = {}) {
  return { content: [{ type: "text" as const, text }], details };
}

function toolUpdate(text: string) {
  return { content: [{ type: "text" as const, text }], details: {} };
}

async function callD3bugr(endpoint: string, params: Record<string, any>, timeoutMs: number = 60000): Promise<any> {
  try {
    const res = await fetch(`${D3BUGR_HOST}/api/tools/${endpoint}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(params),
      signal: AbortSignal.timeout(timeoutMs)
    });
    if (!res.ok) return { success: false, error: `HTTP ${res.status}: ${res.statusText}` };
    return { success: true, data: await res.json() };
  } catch (e: any) {
    return { success: false, error: e.message || "Unknown error" };
  }
}

async function postChunked(webhookUrl: string, message: string, username: string, onUpdate?: any): Promise<string[]> {
  const chunks: string[] = [];
  if (message.length <= 1900) {
    chunks.push(message);
  } else {
    const lines = message.split("\n");
    let current = "";
    for (const line of lines) {
      if ((current + "\n" + line).length > 1850) {
        if (current) chunks.push(current);
        current = line;
      } else {
        current = current ? current + "\n" + line : line;
      }
    }
    if (current) chunks.push(current);
  }
  const toPost = chunks.slice(0, 5);
  const results: string[] = [];
  for (let i = 0; i < toPost.length; i++) {
    if (onUpdate) onUpdate(toolUpdate(`Posting ${i + 1}/${toPost.length}...`));
    try {
      const res = await fetch(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content: toPost[i], username })
      });
      if (res.status === 429) {
        const wait = parseInt(res.headers.get("retry-after") || "3") * 1000;
        await new Promise(r => setTimeout(r, wait));
        const retry = await fetch(webhookUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ content: toPost[i], username })
        });
        results.push(retry.ok ? `Chunk ${i + 1}: OK (retry)` : `Chunk ${i + 1}: ${retry.status}`);
      } else {
        results.push(res.ok ? `Chunk ${i + 1}: OK` : `Chunk ${i + 1}: ${res.status}`);
      }
      if (toPost.length > 1 && i < toPost.length - 1) await new Promise(r => setTimeout(r, 1000));
    } catch (e: any) {
      results.push(`Chunk ${i + 1}: ERROR ${e.message}`);
    }
  }
  return results;
}

async function loadSupabaseConfig(): Promise<{ url: string; key: string } | null> {
  const fs = await import("fs");
  try {
    const env = fs.readFileSync(SUPABASE_CONFIG, "utf-8");
    const url = env.match(/SUPABASE_URL="([^"]+)"/)?.[1] || "";
    const key = env.match(/SUPABASE_KEY="([^"]+)"/)?.[1] || "";
    if (!url || !key) return null;
    return { url, key };
  } catch { return null; }
}

async function loadRailwayToken(): Promise<string | null> {
  const fs = await import("fs");
  try {
    const config = JSON.parse(fs.readFileSync("/mnt/bounty/Claude/.claude/.claude.json", "utf-8"));
    // Search through MCP server configs for RAILWAY_TOKEN
    const mcpServers = config?.projects?.["/mnt/bounty/Claude"]?.mcpServers || {};
    for (const [, server] of Object.entries(mcpServers) as any[]) {
      if (server?.env?.RAILWAY_TOKEN) return server.env.RAILWAY_TOKEN;
    }
    return null;
  } catch { return null; }
}

// Web search helper (shared between Intel and Content tools)
async function ddgSearch(query: string, maxResults: number, onUpdate?: any): Promise<any> {
  if (onUpdate) onUpdate(toolUpdate(`Searching: ${query}`));
  const encoded = encodeURIComponent(query);
  try {
    const res = await fetch(`https://html.duckduckgo.com/html/?q=${encoded}`, {
      headers: { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" },
      signal: AbortSignal.timeout(15000)
    });
    const html = await res.text();
    const results: any[] = [];
    const blocks = html.split('class="result results_links');
    for (let i = 1; i < blocks.length && results.length < maxResults; i++) {
      const block = blocks[i];
      const urlMatch = block.match(/href="[^"]*uddg=([^&"]+)/);
      const titleMatch = block.match(/class="result__a"[^>]*>([\s\S]*?)<\/a>/);
      const snippetMatch = block.match(/class="result__snippet"[^>]*>([\s\S]*?)<\/a>/);
      if (urlMatch) {
        results.push({
          url: decodeURIComponent(urlMatch[1]),
          title: (titleMatch?.[1] || "").replace(/<[^>]+>/g, "").trim(),
          snippet: (snippetMatch?.[1] || "").replace(/<[^>]+>/g, "").trim()
        });
      }
    }
    if (results.length === 0) {
      const linkPattern = /uddg=([^&"]+)[^"]*"[^>]*>([^<]+)/g;
      let m;
      while ((m = linkPattern.exec(html)) && results.length < maxResults) {
        results.push({ url: decodeURIComponent(m[1]), title: m[2].trim(), snippet: "" });
      }
    }
    return toolResult(JSON.stringify({ count: results.length, results }, null, 2));
  } catch (e: any) {
    return toolResult(`Search error: ${e.message}`);
  }
}

// Web fetch helper (shared between Intel and Content tools)
async function fetchPage(url: string, maxChars: number): Promise<any> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0" },
      signal: AbortSignal.timeout(15000)
    });
    if (!res.ok) return toolResult(`HTTP ${res.status} ${res.statusText}`);
    let text = await res.text();
    text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
               .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
               .replace(/<[^>]+>/g, " ")
               .replace(/\s+/g, " ").trim();
    if (text.length > maxChars) text = text.substring(0, maxChars) + "...[truncated]";
    return toolResult(text, { url, length: text.length });
  } catch (e: any) {
    return toolResult(`Fetch error: ${e.message}`);
  }
}

// File search helper (shared between Content and Ops tools)
function searchFilesImpl(params: any): any {
  const fs = require("fs");
  const pathMod = require("path");
  const results: string[] = [];
  const max = params.max_results || 20;
  function walk(dir: string) {
    if (results.length >= max) return;
    try {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        if (results.length >= max) return;
        const fp = pathMod.join(dir, entry.name);
        if (entry.isDirectory() && !entry.name.startsWith(".") && entry.name !== "node_modules") walk(fp);
        else if (entry.isFile()) {
          let match = true;
          if (params.pattern) {
            const rx = new RegExp(params.pattern.replace(/\*/g, ".*").replace(/\?/g, "."), "i");
            match = rx.test(entry.name);
          }
          if (match && params.content) {
            try { match = fs.readFileSync(fp, "utf-8").includes(params.content); } catch { match = false; }
          }
          if (match) results.push(fp);
        }
      }
    } catch {}
  }
  walk(params.directory);
  return toolResult(results.join("\n"), { count: results.length });
}

// ════════════════════════════════════════════════════════════
// SECTION A: BASE TOOLS (6) — ALL agents
// ════════════════════════════════════════════════════════════

export function registerBaseTools(pi: ExtensionAPI, agentName: string, options?: { exclude?: string[], home?: string }) {
  const skip = new Set(options?.exclude || []);
  const AGENT_HOME = options?.home || `/mnt/bounty/Claude/pi-agents/${agentName}`;
  const STATE_DIR = `${AGENT_HOME}/state`;

  if (!skip.has("check_opsec")) pi.registerTool({
    name: "check_opsec",
    label: "Check OPSEC",
    description: "Checks governance flags (swarm-halt, agent-kill, opsec-red). If any flag is set, abort all operations immediately.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async () => {
      const fs = await import("fs");
      if (fs.existsSync("/tmp/swarm-halt")) return toolResult("SWARM HALTED — abort");
      if (fs.existsSync(`/tmp/agent-kill-${agentName}`)) return toolResult(`AGENT KILLED — ${agentName} terminated`);
      if (fs.existsSync("/tmp/opsec-red")) return toolResult("OPSEC RED — VPN down, abort");
      return toolResult("OPSEC GREEN — proceed");
    }
  });

  if (!skip.has("read_file")) pi.registerTool({
    name: "read_file",
    label: "Read File",
    description: "Reads a file from disk. Use absolute paths. Returns content (max 10000 chars by default).",
    parameters: {
      type: "object" as const,
      properties: {
        path: { type: "string" as const, description: "Absolute file path to read" },
        max_chars: { type: "number" as const, description: "Max chars to return (default 10000)" }
      },
      required: ["path"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      try {
        let content = fs.readFileSync(params.path, "utf-8");
        const max = params.max_chars || 10000;
        if (content.length > max) content = content.substring(0, max) + `\n...[truncated at ${max} chars, total: ${content.length}]`;
        return toolResult(content, { path: params.path, size: content.length });
      } catch (e: any) {
        return toolResult(`ERROR reading ${params.path}: ${e.message}`);
      }
    }
  });

  if (!skip.has("write_file")) pi.registerTool({
    name: "write_file",
    label: "Write File",
    description: "Writes content to a file. Creates parent directories if needed.",
    parameters: {
      type: "object" as const,
      properties: {
        path: { type: "string" as const, description: "Absolute file path to write" },
        content: { type: "string" as const, description: "Content to write" }
      },
      required: ["path", "content"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      const pathMod = await import("path");
      try {
        fs.mkdirSync(pathMod.dirname(params.path), { recursive: true });
        fs.writeFileSync(params.path, params.content);
        return toolResult(`Written: ${params.path} (${params.content.length} chars)`);
      } catch (e: any) {
        return toolResult(`ERROR writing ${params.path}: ${e.message}`);
      }
    }
  });

  if (!skip.has("list_directory")) pi.registerTool({
    name: "list_directory",
    label: "List Directory",
    description: "Lists files and directories at a given path with sizes.",
    parameters: {
      type: "object" as const,
      properties: {
        path: { type: "string" as const, description: "Directory path to list" }
      },
      required: ["path"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      const pathMod = await import("path");
      try {
        const entries = fs.readdirSync(params.path, { withFileTypes: true });
        const listing = entries.map((e: any) => {
          try {
            const stat = fs.statSync(pathMod.join(params.path, e.name));
            return `${e.isDirectory() ? "d" : "-"} ${String(stat.size).padStart(8)} ${e.name}`;
          } catch {
            return `? ${" ".repeat(8)} ${e.name}`;
          }
        }).join("\n");
        return toolResult(listing, { count: entries.length, path: params.path });
      } catch (e: any) {
        return toolResult(`ERROR listing ${params.path}: ${e.message}`);
      }
    }
  });

  if (!skip.has("save_state")) pi.registerTool({
    name: "save_state",
    label: "Save State",
    description: "Saves run state to the agent's state directory. Writes last-run.json and appends to run.log.",
    parameters: {
      type: "object" as const,
      properties: {
        summary: { type: "string" as const, description: "Brief run summary" },
        extra_json: { type: "string" as const, description: "Optional JSON string of additional state data" }
      },
      required: ["summary"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      try { fs.mkdirSync(STATE_DIR, { recursive: true }); } catch {}
      const state: any = { last_run: new Date().toISOString(), summary: params.summary };
      if (params.extra_json) { try { Object.assign(state, JSON.parse(params.extra_json)); } catch {} }
      fs.writeFileSync(`${STATE_DIR}/last-run.json`, JSON.stringify(state, null, 2));
      fs.appendFileSync(`${STATE_DIR}/run.log`, `[${state.last_run}] ${params.summary}\n`);
      return toolResult(`State saved: ${params.summary}`);
    }
  });

  if (!skip.has("post_discord")) pi.registerTool({
    name: "post_discord",
    label: "Post to Discord",
    description: "Posts a message to a Discord channel via webhook. Auto-chunks long messages (max 5 chunks). Channels: hackernews, cve-alerts, threat-intel, news, findings, exploits, reports, agent-status, etc.",
    parameters: {
      type: "object" as const,
      properties: {
        channel: { type: "string" as const, description: "Channel name from webhooks.json" },
        message: { type: "string" as const, description: "Discord markdown message to post" },
        username: { type: "string" as const, description: "Bot display name (default: agent name)" }
      },
      required: ["channel", "message"] as string[]
    },
    execute: async (_id: string, params: any, _signal: any, onUpdate: any) => {
      const fs = await import("fs");
      try {
        const webhooks = JSON.parse(fs.readFileSync(WEBHOOKS_PATH, "utf-8"));
        const wh = webhooks[params.channel];
        if (!wh) return toolResult(`ERROR: No channel config for #${params.channel}`);
        const username = params.username || agentName;

        // Ghost Writer channels use bot token posting (no webhooks needed)
        if (wh.post_via === "bot_token") {
          const config = JSON.parse(fs.readFileSync("/mnt/bounty/Claude/.claude/.claude.json", "utf-8"));
          const botToken = config?.mcpServers?.discord?.env?.DISCORD_TOKEN;
          if (!botToken) return toolResult("ERROR: Bot token not found for bot_token posting");

          // Chunk and post via bot API
          const chunks: string[] = [];
          const msg = params.message;
          if (msg.length <= 1900) { chunks.push(msg); }
          else {
            const lines = msg.split("\n");
            let current = "";
            for (const line of lines) {
              if ((current + "\n" + line).length > 1850) {
                if (current) chunks.push(current);
                current = line;
              } else { current = current ? current + "\n" + line : line; }
            }
            if (current) chunks.push(current);
          }
          const toPost = chunks.slice(0, 5);
          const results: string[] = [];
          for (let i = 0; i < toPost.length; i++) {
            if (onUpdate) onUpdate(toolUpdate(`Posting ${i + 1}/${toPost.length} via bot...`));
            try {
              const res = await fetch(`https://discord.com/api/v10/channels/${wh.channel_id}/messages`, {
                method: "POST",
                headers: { "Authorization": `Bot ${botToken}`, "Content-Type": "application/json" },
                body: JSON.stringify({ content: toPost[i] })
              });
              if (res.status === 429) {
                const wait = parseInt(res.headers.get("retry-after") || "3") * 1000;
                await new Promise(r => setTimeout(r, wait));
                const retry = await fetch(`https://discord.com/api/v10/channels/${wh.channel_id}/messages`, {
                  method: "POST",
                  headers: { "Authorization": `Bot ${botToken}`, "Content-Type": "application/json" },
                  body: JSON.stringify({ content: toPost[i] })
                });
                results.push(retry.ok ? `Chunk ${i + 1}: OK (retry)` : `Chunk ${i + 1}: ${retry.status}`);
              } else {
                results.push(res.ok ? `Chunk ${i + 1}: OK` : `Chunk ${i + 1}: ${res.status}`);
              }
              if (toPost.length > 1 && i < toPost.length - 1) await new Promise(r => setTimeout(r, 1000));
            } catch (e: any) { results.push(`Chunk ${i + 1}: ERROR ${e.message}`); }
          }
          return toolResult(results.join("\n"));
        }

        // Standard webhook posting for RainClawd channels
        if (!wh.webhook_url) return toolResult(`ERROR: No webhook for #${params.channel}`);
        const results = await postChunked(wh.webhook_url, params.message, username, onUpdate);
        return toolResult(results.join("\n"));
      } catch (e: any) {
        return toolResult(`ERROR posting to Discord: ${e.message}`);
      }
    }
  });
}

// ════════════════════════════════════════════════════════════
// SECTION B: INTEL TOOLS (6) — web search, CVE, DNS, Shodan
// ════════════════════════════════════════════════════════════

export function registerIntelTools(pi: ExtensionAPI) {

  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description: "Searches the web via DuckDuckGo. Returns top results with titles, URLs, and snippets.",
    parameters: {
      type: "object" as const,
      properties: {
        query: { type: "string" as const, description: "Search query" },
        max_results: { type: "number" as const, description: "Max results (default 5, max 10)" }
      },
      required: ["query"] as string[]
    },
    execute: async (_id: string, params: any, _signal: any, onUpdate: any) => {
      return ddgSearch(params.query, Math.min(params.max_results || 5, 10), onUpdate);
    }
  });

  pi.registerTool({
    name: "web_fetch",
    label: "Fetch Web Page",
    description: "Fetches a URL and extracts readable text (strips HTML, scripts, styles). Max 8000 chars.",
    parameters: {
      type: "object" as const,
      properties: {
        url: { type: "string" as const, description: "URL to fetch" },
        max_chars: { type: "number" as const, description: "Max chars (default 8000)" }
      },
      required: ["url"] as string[]
    },
    execute: async (_id: string, params: any) => {
      return fetchPage(params.url, params.max_chars || 8000);
    }
  });

  pi.registerTool({
    name: "cve_lookup",
    label: "CVE Lookup",
    description: "Looks up CVE details (description, CVSS, affected products) via Shodan CVE database.",
    parameters: {
      type: "object" as const,
      properties: { cve_id: { type: "string" as const, description: "CVE ID (e.g., CVE-2024-1234)" } },
      required: ["cve_id"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("shodan_cve_lookup", { cve_id: params.cve_id });
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  pi.registerTool({
    name: "dns_lookup",
    label: "DNS Lookup",
    description: "DNS lookup for A, AAAA, MX, TXT, NS, CNAME, SOA records.",
    parameters: {
      type: "object" as const,
      properties: {
        domain: { type: "string" as const, description: "Domain to query" },
        record_type: { type: "string" as const, description: "Record type: A, AAAA, MX, TXT, NS, CNAME (default: A)" }
      },
      required: ["domain"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("dns_lookup", { domain: params.domain, record_type: params.record_type || "A" });
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  pi.registerTool({
    name: "shodan_ip",
    label: "Shodan IP Lookup",
    description: "IP intelligence from Shodan: open ports, services, vulnerabilities, OS, location.",
    parameters: {
      type: "object" as const,
      properties: { ip: { type: "string" as const, description: "IP address to lookup" } },
      required: ["ip"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("shodan_ip_lookup", { ip: params.ip });
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  pi.registerTool({
    name: "shodan_search",
    label: "Shodan Search",
    description: "Search Shodan for internet-connected devices using Shodan query syntax.",
    parameters: {
      type: "object" as const,
      properties: { query: { type: "string" as const, description: "Shodan query (e.g., 'apache org:google')" } },
      required: ["query"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("shodan_search", { query: params.query });
      return toolResult(JSON.stringify(result, null, 2));
    }
  });
}

// ════════════════════════════════════════════════════════════
// SECTION C: RECON TOOLS (6)
// ════════════════════════════════════════════════════════════

export function registerReconTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "subfinder", label: "Subdomain Enumeration", description: "Enumerate subdomains for a target domain using subfinder.", parameters: { type: "object" as const, properties: { domain: { type: "string" as const, description: "Target domain" } }, required: ["domain"] as string[] }, execute: async (_id: string, params: any, _s: any, onUpdate: any) => { if (onUpdate) onUpdate(toolUpdate(`Enumerating: ${params.domain}`)); return toolResult(JSON.stringify(await callD3bugr("subfinder_scan", { domain: params.domain }, 120000), null, 2)); } });
  pi.registerTool({ name: "httpx", label: "HTTP Probe", description: "Probe URLs/domains for live HTTP services.", parameters: { type: "object" as const, properties: { targets: { type: "string" as const, description: "Comma-separated URLs or domains" } }, required: ["targets"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("httpx_probe", { targets: params.targets }, 120000), null, 2)); } });
  pi.registerTool({ name: "harvest_quick", label: "Quick OSINT Harvest", description: "Quick OSINT: subdomains, emails, IPs from fast sources.", parameters: { type: "object" as const, properties: { domain: { type: "string" as const, description: "Target domain" } }, required: ["domain"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("harvest_quick", { domain: params.domain }, 90000), null, 2)); } });
  pi.registerTool({ name: "dns_whois", label: "WHOIS Lookup", description: "WHOIS registration data: registrar, dates, nameservers.", parameters: { type: "object" as const, properties: { domain: { type: "string" as const, description: "Domain to query" } }, required: ["domain"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("dns_whois", { domain: params.domain }), null, 2)); } });
  pi.registerTool({ name: "katana", label: "Web Crawler", description: "Crawl website, discover endpoints, params, JS files.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "Target URL" }, depth: { type: "number" as const, description: "Crawl depth 1-5 (default 2)" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("katana_crawl", { url: params.url, depth: params.depth || 2 }, 120000), null, 2)); } });
  pi.registerTool({ name: "nmap_quick", label: "Quick Port Scan", description: "Scan top 100 ports with Nmap.", parameters: { type: "object" as const, properties: { target: { type: "string" as const, description: "Target IP or domain" } }, required: ["target"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("nmap_quick", { target: params.target }, 120000), null, 2)); } });
}

// ════════════════════════════════════════════════════════════
// SECTION D: SCAN TOOLS (4)
// ════════════════════════════════════════════════════════════

export function registerScanTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "nuclei_quick", label: "Quick Vuln Scan", description: "Nuclei scan — critical/high severity templates.", parameters: { type: "object" as const, properties: { target: { type: "string" as const, description: "Target URL/domain" } }, required: ["target"] as string[] }, execute: async (_id: string, params: any, _s: any, onUpdate: any) => { if (onUpdate) onUpdate(toolUpdate(`Scanning: ${params.target}`)); return toolResult(JSON.stringify(await callD3bugr("nuclei_quick", { target: params.target }, 180000), null, 2)); } });
  pi.registerTool({ name: "nuclei_tech", label: "Tech Detection", description: "Detect technologies, frameworks, CMS on target.", parameters: { type: "object" as const, properties: { target: { type: "string" as const, description: "Target URL/domain" } }, required: ["target"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("nuclei_tech", { target: params.target }, 120000), null, 2)); } });
  pi.registerTool({ name: "nuclei_cves", label: "CVE Scan", description: "Scan for known CVEs with Nuclei templates.", parameters: { type: "object" as const, properties: { target: { type: "string" as const, description: "Target URL/domain" }, year: { type: "string" as const, description: "CVE year filter" } }, required: ["target"] as string[] }, execute: async (_id: string, params: any) => { const p: any = { target: params.target }; if (params.year) p.year = params.year; return toolResult(JSON.stringify(await callD3bugr("nuclei_cves", p, 300000), null, 2)); } });
  pi.registerTool({ name: "nuclei_exposures", label: "Exposure Scan", description: "Scan for info leaks, debug endpoints, exposed configs.", parameters: { type: "object" as const, properties: { target: { type: "string" as const, description: "Target URL/domain" } }, required: ["target"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("nuclei_exposures", { target: params.target }, 180000), null, 2)); } });
}

// ════════════════════════════════════════════════════════════
// SECTION E: HUNTER TOOLS (4)
// ════════════════════════════════════════════════════════════

export function registerHunterTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "sqlmap_test", label: "SQLi Test", description: "Quick SQL injection test on URL with parameters.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "Target URL with params" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("sqlmap_test", { url: params.url }, 120000), null, 2)); } });
  pi.registerTool({ name: "dalfox_xss", label: "XSS Scan", description: "XSS vulnerability scan with Dalfox.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "Target URL with params" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("dalfox_xss_scan", { url: params.url }, 120000), null, 2)); } });
  pi.registerTool({ name: "ffuf", label: "Directory Fuzz", description: "Fuzz directories/files with FFUF.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "URL with FUZZ placeholder" }, wordlist: { type: "string" as const, description: "Wordlist: common, medium, large, api" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("ffuf_scan", { url: params.url, wordlist: params.wordlist || "common" }, 180000), null, 2)); } });
  pi.registerTool({ name: "feroxbuster", label: "Recursive Dir Fuzz", description: "Recursive directory fuzzing with Feroxbuster.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "Target base URL" }, wordlist: { type: "string" as const, description: "Wordlist: common, medium, large" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await callD3bugr("feroxbuster_scan", { url: params.url, wordlist: params.wordlist || "common" }, 180000), null, 2)); } });
}

// ════════════════════════════════════════════════════════════
// SECTION F: CONTENT TOOLS (3)
// ════════════════════════════════════════════════════════════

export function registerContentTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "web_search", label: "Web Search", description: "Search the web via DuckDuckGo.", parameters: { type: "object" as const, properties: { query: { type: "string" as const, description: "Search query" }, max_results: { type: "number" as const, description: "Max results (default 5)" } }, required: ["query"] as string[] }, execute: async (_id: string, params: any, _s: any, onUpdate: any) => { return ddgSearch(params.query, Math.min(params.max_results || 5, 10), onUpdate); } });
  pi.registerTool({ name: "web_fetch", label: "Fetch Web Page", description: "Fetch URL, extract readable text (max 8000 chars).", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "URL to fetch" }, max_chars: { type: "number" as const, description: "Max chars" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { return fetchPage(params.url, params.max_chars || 8000); } });
  pi.registerTool({ name: "search_files", label: "Search Files", description: "Search files by name pattern or content in a directory tree.", parameters: { type: "object" as const, properties: { directory: { type: "string" as const, description: "Root dir to search" }, pattern: { type: "string" as const, description: "Filename pattern (*.md, *report*)" }, content: { type: "string" as const, description: "Text to find in files" }, max_results: { type: "number" as const, description: "Max results (default 20)" } }, required: ["directory"] as string[] }, execute: async (_id: string, params: any) => { return searchFilesImpl(params); } });
}

// ════════════════════════════════════════════════════════════
// SECTION G: OPS TOOLS (3)
// ════════════════════════════════════════════════════════════

export function registerOpsTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "d3bugr_health", label: "D3BUGR Health", description: "Check d3bugr Railway service health.", parameters: { type: "object" as const, properties: {}, required: [] as string[] }, execute: async () => { try { const res = await fetch(`${D3BUGR_HOST}/health`, { signal: AbortSignal.timeout(10000) }); const data = await res.json().catch(() => ({})); return toolResult(JSON.stringify({ status: res.status, ok: res.ok, ...data }, null, 2)); } catch (e: any) { return toolResult(`D3BUGR OFFLINE: ${e.message}`); } } });
  pi.registerTool({ name: "search_files", label: "Search Files", description: "Search files by name/content in directory tree.", parameters: { type: "object" as const, properties: { directory: { type: "string" as const, description: "Root dir" }, pattern: { type: "string" as const, description: "Filename pattern" }, content: { type: "string" as const, description: "Text to find" }, max_results: { type: "number" as const, description: "Max results" } }, required: ["directory"] as string[] }, execute: async (_id: string, params: any) => { return searchFilesImpl(params); } });
  pi.registerTool({ name: "http_health_check", label: "HTTP Health Check", description: "Probe any URL for status, response time, headers.", parameters: { type: "object" as const, properties: { url: { type: "string" as const, description: "URL to check" }, timeout_ms: { type: "number" as const, description: "Timeout ms (default 10000)" } }, required: ["url"] as string[] }, execute: async (_id: string, params: any) => { const start = Date.now(); try { const res = await fetch(params.url, { signal: AbortSignal.timeout(params.timeout_ms || 10000) }); const hdrs: Record<string, string> = {}; res.headers.forEach((v, k) => { hdrs[k] = v; }); return toolResult(JSON.stringify({ url: params.url, status: res.status, ok: res.ok, ms: Date.now() - start, server: hdrs["server"] || "?" }, null, 2)); } catch (e: any) { return toolResult(JSON.stringify({ url: params.url, status: 0, ok: false, error: e.message, ms: Date.now() - start }, null, 2)); } } });
}

// ════════════════════════════════════════════════════════════
// SECTION H: SUPABASE TOOLS (4)
// ════════════════════════════════════════════════════════════

export function registerSupabaseTools(pi: ExtensionAPI) {
  pi.registerTool({ name: "supabase_query", label: "Supabase Query", description: "Query a table using PostgREST filters. Read-only.", parameters: { type: "object" as const, properties: { table: { type: "string" as const, description: "Table name" }, select: { type: "string" as const, description: "Columns (default: *)" }, filter: { type: "string" as const, description: "PostgREST filter (e.g., status=eq.active)" }, limit: { type: "number" as const, description: "Max rows (default 50)" } }, required: ["table"] as string[] }, execute: async (_id: string, params: any) => { const cfg = await loadSupabaseConfig(); if (!cfg) return toolResult("ERROR: Supabase config not found"); let url = `${cfg.url}/rest/v1/${params.table}?select=${encodeURIComponent(params.select || "*")}&limit=${params.limit || 50}`; if (params.filter) for (const f of params.filter.split(",")) url += `&${f.trim()}`; try { const res = await fetch(url, { headers: { apikey: cfg.key, Authorization: `Bearer ${cfg.key}` }, signal: AbortSignal.timeout(15000) }); if (!res.ok) return toolResult(`Supabase: HTTP ${res.status}`); return toolResult(JSON.stringify(await res.json(), null, 2)); } catch (e: any) { return toolResult(`Supabase: ${e.message}`); } } });
  pi.registerTool({ name: "supabase_insert", label: "Supabase Insert", description: "Insert row into a table. Data as JSON string.", parameters: { type: "object" as const, properties: { table: { type: "string" as const, description: "Table name" }, data: { type: "string" as const, description: "JSON row data" } }, required: ["table", "data"] as string[] }, execute: async (_id: string, params: any) => { const cfg = await loadSupabaseConfig(); if (!cfg) return toolResult("ERROR: Supabase config not found"); let row; try { row = JSON.parse(params.data); } catch { return toolResult("ERROR: Invalid JSON"); } try { const res = await fetch(`${cfg.url}/rest/v1/${params.table}`, { method: "POST", headers: { apikey: cfg.key, Authorization: `Bearer ${cfg.key}`, "Content-Type": "application/json", Prefer: "return=representation" }, body: JSON.stringify(row), signal: AbortSignal.timeout(15000) }); if (!res.ok) return toolResult(`Insert: HTTP ${res.status}`); return toolResult(`Inserted: ${JSON.stringify(await res.json())}`); } catch (e: any) { return toolResult(`Insert: ${e.message}`); } } });
  pi.registerTool({ name: "supabase_list_tables", label: "List Tables", description: "List all public Supabase tables.", parameters: { type: "object" as const, properties: {}, required: [] as string[] }, execute: async () => { const cfg = await loadSupabaseConfig(); if (!cfg) return toolResult("ERROR: Supabase config not found"); try { const res = await fetch(`${cfg.url}/rest/v1/`, { headers: { apikey: cfg.key, Authorization: `Bearer ${cfg.key}` }, signal: AbortSignal.timeout(10000) }); const data = await res.json(); const tables = data.paths ? Object.keys(data.paths).map((p: string) => p.replace("/", "")).filter(Boolean) : []; return toolResult(JSON.stringify({ tables }, null, 2)); } catch (e: any) { return toolResult(`Error: ${e.message}`); } } });
  pi.registerTool({ name: "supabase_get_logs", label: "Supabase Logs", description: "Get recent Supabase project logs.", parameters: { type: "object" as const, properties: { type: { type: "string" as const, description: "Log type: api, auth, postgres" } }, required: [] as string[] }, execute: async (_id: string, params: any) => { const cfg = await loadSupabaseConfig(); if (!cfg) return toolResult("ERROR: Supabase config not found"); return toolResult(`Logs endpoint requires service-role key. Use Supabase dashboard for ${params.type || "api"} logs.`); } });
}

// ════════════════════════════════════════════════════════════
// SECTION I: RAILWAY TOOLS (2)
// ════════════════════════════════════════════════════════════

export function registerRailwayTools(pi: ExtensionAPI) {
  const RAILWAY_GQL = "https://backboard.railway.app/graphql/v2";

  async function railwayGql(query: string, variables: Record<string, any> = {}): Promise<any> {
    const token = await loadRailwayToken();
    if (!token) return { error: "Railway token not found" };
    try {
      const res = await fetch(RAILWAY_GQL, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify({ query, variables }), signal: AbortSignal.timeout(15000) });
      if (!res.ok) return { error: `HTTP ${res.status}` };
      return await res.json();
    } catch (e: any) { return { error: e.message }; }
  }

  pi.registerTool({ name: "railway_service_status", label: "Railway Status", description: "Check Railway service/project status.", parameters: { type: "object" as const, properties: { project_id: { type: "string" as const, description: "Project ID (omit to list all)" } }, required: [] as string[] }, execute: async (_id: string, params: any) => { if (params.project_id) { return toolResult(JSON.stringify(await railwayGql(`query($id:String!){project(id:$id){name services{edges{node{id name}}} environments{edges{node{id name}}}}}`, { id: params.project_id }), null, 2)); } else { return toolResult(JSON.stringify(await railwayGql(`query{me{projects{edges{node{id name updatedAt}}}}}`), null, 2)); } } });
  pi.registerTool({ name: "railway_service_logs", label: "Railway Logs", description: "Fetch recent logs from a Railway deployment.", parameters: { type: "object" as const, properties: { deployment_id: { type: "string" as const, description: "Deployment ID" }, limit: { type: "number" as const, description: "Max lines (default 50)" } }, required: ["deployment_id"] as string[] }, execute: async (_id: string, params: any) => { return toolResult(JSON.stringify(await railwayGql(`query($id:String!,$l:Int!){deploymentLogs(deploymentId:$id,limit:$l){timestamp message severity}}`, { id: params.deployment_id, l: params.limit || 50 }), null, 2)); } });
}

// ════════════════════════════════════════════════════════════
// SECTION J: RESEARCH TOOLS (7) — Content research + fact-checking
// ════════════════════════════════════════════════════════════

export function registerResearchTools(pi: ExtensionAPI) {

  // CVE lookup via Shodan/d3bugr
  pi.registerTool({
    name: "research_cve",
    label: "Research CVE",
    description: "Look up a CVE ID for article research. Returns description, CVSS score, affected products, references. Use to VERIFY CVE numbers before including in articles.",
    parameters: {
      type: "object" as const,
      properties: {
        cve_id: { type: "string" as const, description: "CVE ID (e.g., CVE-2024-1234)" }
      },
      required: ["cve_id"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("shodan_cve_lookup", { cve_id: params.cve_id });
      if (!result.success) return toolResult(`CVE lookup failed: ${result.error}. DO NOT use this CVE in the article without verification.`);
      return toolResult(JSON.stringify({ verified: true, ...result.data }, null, 2));
    }
  });

  // Search CVEs by product
  pi.registerTool({
    name: "research_cves_by_product",
    label: "CVEs by Product",
    description: "Find real CVEs affecting a specific product/vendor. Use for article research to find VERIFIED vulnerabilities.",
    parameters: {
      type: "object" as const,
      properties: {
        product: { type: "string" as const, description: "Product name (e.g., 'apache', 'nginx', 'wordpress')" },
        count: { type: "number" as const, description: "Max CVEs to return (default 10)" }
      },
      required: ["product"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const result = await callD3bugr("shodan_cves_by_product", { product: params.product, count: params.count || 10 });
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  // HackerNews security posts
  pi.registerTool({
    name: "research_hackernews",
    label: "HackerNews Search",
    description: "Search HackerNews for security-related discussions. Great for finding trending topics, community reactions, and real-world impact stories.",
    parameters: {
      type: "object" as const,
      properties: {
        query: { type: "string" as const, description: "Search query (e.g., 'XSS 2026', 'supply chain attack')" },
        max_results: { type: "number" as const, description: "Max results (default 10)" }
      },
      required: ["query"] as string[]
    },
    execute: async (_id: string, params: any) => {
      try {
        const q = encodeURIComponent(params.query);
        const max = params.max_results || 10;
        const res = await fetch(`https://hn.algolia.com/api/v1/search?query=${q}&tags=story&hitsPerPage=${max}`, {
          signal: AbortSignal.timeout(15000)
        });
        if (!res.ok) return toolResult(`HN API error: ${res.status}`);
        const data = await res.json();
        const stories = (data.hits || []).map((h: any) => ({
          title: h.title,
          url: h.url || `https://news.ycombinator.com/item?id=${h.objectID}`,
          points: h.points,
          comments: h.num_comments,
          date: h.created_at,
          hn_url: `https://news.ycombinator.com/item?id=${h.objectID}`
        }));
        return toolResult(JSON.stringify({ count: stories.length, stories }, null, 2));
      } catch (e: any) {
        return toolResult(`HN search error: ${e.message}`);
      }
    }
  });

  // Verify a statistic against web sources
  pi.registerTool({
    name: "verify_stat",
    label: "Verify Statistic",
    description: "Search the web to verify a specific statistic or claim before including it in an article. Returns search results that can confirm or deny the claim.",
    parameters: {
      type: "object" as const,
      properties: {
        claim: { type: "string" as const, description: "The statistic or claim to verify (e.g., 'XSS accounts for 40% of web attacks in 2026')" },
        source_hint: { type: "string" as const, description: "Optional: expected source (e.g., 'OWASP', 'Verizon DBIR')" }
      },
      required: ["claim"] as string[]
    },
    execute: async (_id: string, params: any, _s: any, onUpdate: any) => {
      const query = params.source_hint
        ? `${params.claim} ${params.source_hint} site:*.org OR site:*.gov`
        : `${params.claim} statistics source`;
      const results = await ddgSearch(query, 5, onUpdate);
      return toolResult(JSON.stringify({
        claim: params.claim,
        verification_note: "Review these sources. Only include the stat if at least one authoritative source confirms it.",
        ...JSON.parse(results.content[0].text)
      }, null, 2));
    }
  });

  // Fetch CISA KEV (Known Exploited Vulnerabilities)
  pi.registerTool({
    name: "research_cisa_kev",
    label: "CISA KEV Feed",
    description: "Fetch CISA Known Exploited Vulnerabilities catalog. These are CONFIRMED actively exploited CVEs — gold standard for article references.",
    parameters: {
      type: "object" as const,
      properties: {
        max_results: { type: "number" as const, description: "Max recent entries (default 20)" }
      },
      required: [] as string[]
    },
    execute: async (_id: string, params: any) => {
      try {
        const res = await fetch("https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json", {
          signal: AbortSignal.timeout(15000)
        });
        if (!res.ok) return toolResult(`CISA KEV fetch failed: ${res.status}`);
        const data = await res.json();
        const vulns = (data.vulnerabilities || [])
          .sort((a: any, b: any) => new Date(b.dateAdded).getTime() - new Date(a.dateAdded).getTime())
          .slice(0, params.max_results || 20)
          .map((v: any) => ({
            cve: v.cveID,
            vendor: v.vendorProject,
            product: v.product,
            name: v.vulnerabilityName,
            description: v.shortDescription,
            date_added: v.dateAdded,
            due_date: v.dueDate,
            known_ransomware: v.knownRansomwareCampaignUse
          }));
        return toolResult(JSON.stringify({ total_in_catalog: data.vulnerabilities?.length, returned: vulns.length, vulnerabilities: vulns }, null, 2));
      } catch (e: any) {
        return toolResult(`CISA KEV error: ${e.message}`);
      }
    }
  });

  // Research trending security topics
  pi.registerTool({
    name: "research_trending",
    label: "Trending Security Topics",
    description: "Search multiple sources for trending security topics. Combines web search with HN data for topic validation.",
    parameters: {
      type: "object" as const,
      properties: {
        topic: { type: "string" as const, description: "Broad topic area (e.g., 'cloud security', 'API vulnerabilities', 'ransomware')" }
      },
      required: ["topic"] as string[]
    },
    execute: async (_id: string, params: any, _s: any, onUpdate: any) => {
      // Parallel: web search + HN search
      const [webResults, hnResults] = await Promise.all([
        ddgSearch(`${params.topic} 2026 latest`, 5, onUpdate),
        (async () => {
          try {
            const q = encodeURIComponent(params.topic);
            const res = await fetch(`https://hn.algolia.com/api/v1/search_by_date?query=${q}&tags=story&hitsPerPage=5`, { signal: AbortSignal.timeout(15000) });
            return res.ok ? await res.json() : { hits: [] };
          } catch { return { hits: [] }; }
        })()
      ]);
      const hn = (hnResults.hits || []).map((h: any) => ({ title: h.title, points: h.points, date: h.created_at }));
      return toolResult(JSON.stringify({
        topic: params.topic,
        web_results: JSON.parse(webResults.content[0].text),
        hackernews: { count: hn.length, stories: hn },
        note: "Cross-reference findings. Topics appearing on BOTH web and HN are confirmed trending."
      }, null, 2));
    }
  });

  // Cowork context reader — read research notes from previous pipeline stages
  pi.registerTool({
    name: "read_cowork_context",
    label: "Read Cowork Context",
    description: "Read the shared cowork context file for the current article. Contains research notes, fact-check results, and editor comments from previous pipeline stages.",
    parameters: {
      type: "object" as const,
      properties: {
        article_slug: { type: "string" as const, description: "Article slug/filename to get context for" }
      },
      required: ["article_slug"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      const coworkPath = `/mnt/bounty/Claude/pi-agents/content/cowork/${params.article_slug}.json`;
      try {
        const data = fs.readFileSync(coworkPath, "utf-8");
        return toolResult(data);
      } catch {
        return toolResult(JSON.stringify({ status: "no_cowork_context", note: "No previous pipeline context found. You are the first agent to work on this article." }));
      }
    }
  });

  // Cowork context writer — append notes for next pipeline stage
  pi.registerTool({
    name: "write_cowork_context",
    label: "Write Cowork Context",
    description: "Append your research notes, findings, or review comments to the shared cowork context file. The NEXT agent in the pipeline will read this.",
    parameters: {
      type: "object" as const,
      properties: {
        article_slug: { type: "string" as const, description: "Article slug/filename" },
        agent_name: { type: "string" as const, description: "Your agent name" },
        notes: { type: "string" as const, description: "Your notes, findings, or review comments" },
        verified_facts: { type: "string" as const, description: "JSON array of verified facts with sources" },
        flags: { type: "string" as const, description: "Any warnings or flags for the next agent" }
      },
      required: ["article_slug", "agent_name", "notes"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      const coworkDir = "/mnt/bounty/Claude/pi-agents/content/cowork";
      const coworkPath = `${coworkDir}/${params.article_slug}.json`;
      try { fs.mkdirSync(coworkDir, { recursive: true }); } catch {}

      let existing: any = { stages: [] };
      try { existing = JSON.parse(fs.readFileSync(coworkPath, "utf-8")); } catch {}

      existing.stages.push({
        agent: params.agent_name,
        timestamp: new Date().toISOString(),
        notes: params.notes,
        verified_facts: params.verified_facts ? JSON.parse(params.verified_facts) : [],
        flags: params.flags || null
      });
      existing.last_updated = new Date().toISOString();

      fs.writeFileSync(coworkPath, JSON.stringify(existing, null, 2));
      return toolResult(`Cowork context updated for ${params.article_slug}. ${existing.stages.length} stages recorded.`);
    }
  });
}

// ════════════════════════════════════════════════════════════
// SECTION K: GHOST CMS TOOLS (3) — Publishing to Ghost blog
// ════════════════════════════════════════════════════════════

const GHOST_CONFIG_PATH = "/mnt/bounty/Claude/pi-agents/content/ghost-config/ghost-api.env";

async function loadGhostConfig(): Promise<{ url: string; adminKey: string; contentKey: string } | null> {
  const fs = await import("fs");
  try {
    const env = fs.readFileSync(GHOST_CONFIG_PATH, "utf-8");
    const url = env.match(/GHOST_URL="([^"]+)"/)?.[1] || "";
    const adminKey = env.match(/GHOST_ADMIN_KEY="([^"]+)"/)?.[1] || "";
    const contentKey = env.match(/GHOST_CONTENT_KEY="([^"]+)"/)?.[1] || "";
    if (!url || !adminKey) return null;
    return { url, adminKey, contentKey };
  } catch { return null; }
}

async function ghostAdminRequest(method: string, endpoint: string, body?: any): Promise<any> {
  const cfg = await loadGhostConfig();
  if (!cfg) return { error: "Ghost config not found" };

  const [id, secret] = cfg.adminKey.split(":");
  // Create JWT for Ghost Admin API
  const crypto = await import("crypto");
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT", kid: id })).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({ iat: now, exp: now + 300, aud: "/admin/" })).toString("base64url");
  const sig = crypto.createHmac("sha256", Buffer.from(secret, "hex")).update(`${header}.${payload}`).digest("base64url");
  const token = `${header}.${payload}.${sig}`;

  try {
    const opts: any = {
      method,
      headers: { Authorization: `Ghost ${token}`, "Content-Type": "application/json" },
      signal: AbortSignal.timeout(30000)
    };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(`${cfg.url}/ghost/api/admin/${endpoint}`, opts);
    if (!res.ok) return { error: `HTTP ${res.status}`, body: await res.text().catch(() => "") };
    return await res.json();
  } catch (e: any) {
    return { error: e.message };
  }
}

export function registerGhostTools(pi: ExtensionAPI) {

  pi.registerTool({
    name: "ghost_publish",
    label: "Publish to Ghost",
    description: "Publish an article to Ghost CMS. Takes markdown content and creates a published post.",
    parameters: {
      type: "object" as const,
      properties: {
        title: { type: "string" as const, description: "Article title" },
        markdown: { type: "string" as const, description: "Full article content in markdown" },
        tags: { type: "string" as const, description: "Comma-separated tags (e.g., 'security,xss,web')" },
        featured: { type: "boolean" as const, description: "Feature this post (default false)" },
        status: { type: "string" as const, description: "Post status: draft or published (default draft)" }
      },
      required: ["title", "markdown"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const tags = (params.tags || "").split(",").map((t: string) => ({ name: t.trim() })).filter((t: any) => t.name);
      // Ghost 5.x requires mobiledoc format — wrap markdown in a markdown card
      const mobiledoc = JSON.stringify({
        version: "0.3.1",
        markups: [],
        atoms: [],
        cards: [["markdown", { markdown: params.markdown }]],
        sections: [[10, 0]]
      });
      const result = await ghostAdminRequest("POST", "posts/", {
        posts: [{
          title: params.title,
          mobiledoc,
          tags,
          featured: params.featured || false,
          status: params.status || "draft"
        }]
      });
      if (result.error) return toolResult(`Ghost publish error: ${JSON.stringify(result)}`);
      const post = result.posts?.[0];
      if (post) return toolResult(JSON.stringify({ id: post.id, slug: post.slug, url: post.url, status: post.status, title: post.title }, null, 2));
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  pi.registerTool({
    name: "ghost_list_posts",
    label: "List Ghost Posts",
    description: "List recent posts from Ghost CMS.",
    parameters: {
      type: "object" as const,
      properties: {
        limit: { type: "number" as const, description: "Max posts (default 10)" },
        status: { type: "string" as const, description: "Filter by status: draft, published, all (default all)" }
      },
      required: [] as string[]
    },
    execute: async (_id: string, params: any) => {
      const status = params.status || "all";
      const limit = params.limit || 10;
      const result = await ghostAdminRequest("GET", `posts/?limit=${limit}&filter=status:${status}&fields=id,title,slug,status,published_at,updated_at`);
      if (result.error) return toolResult(`Ghost error: ${JSON.stringify(result)}`);
      return toolResult(JSON.stringify(result, null, 2));
    }
  });

  pi.registerTool({
    name: "ghost_site_info",
    label: "Ghost Site Info",
    description: "Get Ghost CMS site information — title, version, URL.",
    parameters: {
      type: "object" as const,
      properties: {},
      required: [] as string[]
    },
    execute: async () => {
      const result = await ghostAdminRequest("GET", "site/");
      return toolResult(JSON.stringify(result, null, 2));
    }
  });
}
