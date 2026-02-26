/**
 * Shared Agent Utilities — imported by all Pi agent extensions
 *
 * Provides: webhook posting, opsec checking, state management,
 * governance prompt loading, Discord formatting
 */

const WEBHOOKS_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/webhooks.json";
const GOV_PROMPT_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/governance-prompt.txt";
const SCOPE_PATH = "/mnt/bounty/Claude/pi-agents/swarm-blueprint/approved-scope.json";

// === WEBHOOK MANAGEMENT ===

export async function loadWebhooks(): Promise<Record<string, { channel_id: string; webhook_id: string; webhook_url: string }>> {
  const fs = await import("fs");
  return JSON.parse(fs.readFileSync(WEBHOOKS_PATH, "utf-8"));
}

export async function getWebhookUrl(channel: string): Promise<string | null> {
  const webhooks = await loadWebhooks();
  return webhooks[channel]?.webhook_url || null;
}

// === DISCORD POSTING ===

export async function postToDiscord(
  channel: string,
  message: string,
  username: string,
  maxMessages: number = 5
): Promise<string[]> {
  const url = await getWebhookUrl(channel);
  if (!url) return [`ERROR: No webhook for #${channel}`];

  // Chunk messages at 1900 chars (leave buffer for Discord's 2000 limit)
  const chunks = chunkMessage(message, 1900);
  const toPost = chunks.slice(0, maxMessages);
  const results: string[] = [];

  for (let i = 0; i < toPost.length; i++) {
    let retries = 0;
    const maxRetries = 3;
    let success = false;

    while (retries < maxRetries && !success) {
      try {
        const res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ content: toPost[i], username })
        });

        if (res.status === 429) {
          // Rate limited — wait and retry
          const retryAfter = parseInt(res.headers.get("retry-after") || "2") * 1000;
          const remaining = res.headers.get("x-ratelimit-remaining");
          console.error(`[RATE-LIMIT] 429 received. Retry-After: ${retryAfter}ms, Remaining: ${remaining || "N/A"}`);
          await sleep(retryAfter);
          retries++;
          continue;
        }

        // Check rate limit headers proactively
        const remaining = res.headers.get("x-ratelimit-remaining");
        if (remaining && parseInt(remaining) < 5) {
          console.error(`[RATE-LIMIT] Low remaining requests: ${remaining}`);
        }

        if (res.ok) {
          results.push(retries > 0 ? `Chunk ${i + 1}: OK (retry ${retries})` : `Chunk ${i + 1}: OK`);
          success = true;
        } else {
          results.push(`Chunk ${i + 1}: FAILED ${res.status}`);
          success = true; // Don't retry non-rate-limit failures
        }

      } catch (e: any) {
        retries++;
        if (retries >= maxRetries) {
          results.push(`Chunk ${i + 1}: ERROR ${e.message} (failed after ${maxRetries} retries)`);
        } else {
          // Exponential backoff: 1s, 2s, 4s
          const backoff = Math.pow(2, retries - 1) * 1000;
          console.error(`[NETWORK-ERROR] Retry ${retries}/${maxRetries} after ${backoff}ms: ${e.message}`);
          await sleep(backoff);
        }
      }
    }

    if (toPost.length > 1 && i < toPost.length - 1) await sleep(1000);
  }

  return results;
}

function chunkMessage(message: string, maxLen: number): string[] {
  if (message.length <= maxLen) return [message];
  const lines = message.split("\n");
  const chunks: string[] = [];
  let current = "";
  for (const line of lines) {
    if ((current + "\n" + line).length > maxLen) {
      if (current) chunks.push(current);
      current = line;
    } else {
      current = current ? current + "\n" + line : line;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

// === OPSEC CHECKING ===

export async function checkOpsec(agentName: string): Promise<{ ok: boolean; reason: string }> {
  const fs = await import("fs");
  if (fs.existsSync("/tmp/swarm-halt"))
    return { ok: false, reason: "SWARM HALTED — global kill switch active" };
  if (fs.existsSync(`/tmp/agent-kill-${agentName}`))
    return { ok: false, reason: `AGENT KILLED — ${agentName} terminated by supervisor` };
  if (fs.existsSync("/tmp/opsec-red"))
    return { ok: false, reason: "OPSEC RED — VPN disconnected" };
  return { ok: true, reason: "ALL CLEAR" };
}

// === GOVERNANCE ===

export async function loadGovernancePrompt(): Promise<string> {
  const fs = await import("fs");
  try { return fs.readFileSync(GOV_PROMPT_PATH, "utf-8"); } catch { return ""; }
}

export async function loadScope(): Promise<{ domains: string[]; wildcards: string[]; excluded: string[] }> {
  const fs = await import("fs");
  try {
    const scope = JSON.parse(fs.readFileSync(SCOPE_PATH, "utf-8"));
    return {
      domains: scope.domains || [],
      wildcards: scope.wildcards || [],
      excluded: scope.excluded || []
    };
  } catch {
    return { domains: [], wildcards: [], excluded: [] };
  }
}

export function buildIdentityBlock(name: string, level: number, tier: string, permissions: string): string {
  return `IDENTITY:
  Name: ${name}
  Level: ${level}
  Tier: ${tier}
  Reports to: Orchestrator (Claude Opus)
  Commander: rainkode
  Permissions: ${permissions}`;
}

// === STATE MANAGEMENT ===

export async function saveState(stateDir: string, data: Record<string, any>): Promise<void> {
  const fs = await import("fs");
  try { fs.mkdirSync(stateDir, { recursive: true }); } catch {}
  const state = { ...data, timestamp: new Date().toISOString() };
  fs.writeFileSync(`${stateDir}/last-run.json`, JSON.stringify(state, null, 2));
}

export async function loadState(stateDir: string): Promise<Record<string, any> | null> {
  const fs = await import("fs");
  try {
    return JSON.parse(fs.readFileSync(`${stateDir}/last-run.json`, "utf-8"));
  } catch {
    return null;
  }
}

export async function appendLog(stateDir: string, message: string): Promise<void> {
  const fs = await import("fs");
  const timestamp = new Date().toISOString();
  fs.appendFileSync(`${stateDir}/last-run.log`, `[${timestamp}] ${message}\n`);
}

export async function appendAudit(stateDir: string, agentName: string, tier: number, action: string): Promise<void> {
  const fs = await import("fs");
  const timestamp = new Date().toISOString();
  fs.appendFileSync(`${stateDir}/audit.log`, `[${timestamp}] [TIER-${tier}] [${agentName}] ${action}\n`);
}

// === DEDUP TRACKING ===

export async function loadTrackedIds(filePath: string): Promise<string[]> {
  const fs = await import("fs");
  try { return JSON.parse(fs.readFileSync(filePath, "utf-8")); } catch { return []; }
}

export async function saveTrackedIds(filePath: string, ids: string[], maxSize: number = 500): Promise<void> {
  const fs = await import("fs");
  const trimmed = ids.length > maxSize ? ids.slice(-maxSize) : ids;
  fs.writeFileSync(filePath, JSON.stringify(trimmed));
}

// === HELPERS ===

function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}
