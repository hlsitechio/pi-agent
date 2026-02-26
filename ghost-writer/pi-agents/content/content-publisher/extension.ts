/**
 * Content Publisher Agent Extension
 * Division: CONTENT
 * JOB: Publish approved articles directly to dev.to
 * Pipeline: research → write → edit → review → publish (dev.to)
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/content-publisher";
const CONTENT_HOME = "/app/pi-agents/content";
const WRITER_OUTPUT = "/app/pi-agents/content/article-writer/output";
const PUBLISHED_DIR = "/app/pi-agents/content/published";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "content-publisher", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    // Ensure published dir exists
    try { fs.mkdirSync(PUBLISHED_DIR, { recursive: true }); } catch {}

    return {
      systemPrompt: `You are the CONTENT PUBLISHER agent. Division: CONTENT.

${govPrompt}

COWORK MODE:
- Read cowork context to check review verdict
- ONLY publish articles with review_verdict: "APPROVED"
- Post to Ghost Writer CrowByte OPS Discord channels

YOUR ONE JOB: Publish approved articles to dev.to and archive them locally.

WORKFLOW:
1. check_opsec — if halted, stop.
2. get_publishable — list articles ready for publishing (status: "edited" + review approved)
3. For each publishable article:
   a. Read cowork context — verify review_verdict is "APPROVED"
   b. publish_devto — publish directly to dev.to
   c. archive_article — move to published/ with dev.to URL metadata
   d. post_discord channel="gw-published" — article title + dev.to URL
   e. post_discord channel="gw-devto-links" — just the dev.to URL
4. update_tracker with summary
5. post_discord channel="gw-pipeline-status" — pipeline run complete
6. STOP.

RULES:
- NEVER publish articles without review_verdict: "APPROVED"
- Respect max_daily_posts limit (1/day on dev.to)
- Max 4 tags per article on dev.to
- Log every publication
- ALWAYS post to Discord when done`
    };
  });

  // ── Get publishable articles ──
  pi.registerTool({
    name: "get_publishable",
    label: "Get Publishable Articles",
    description: "Lists edited articles ready for publication.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async () => {
      const fs = await import("fs");
      const path = await import("path");
      try {
        const files = fs.readdirSync(WRITER_OUTPUT).filter((f: string) => f.endsWith(".md"));
        const publishable: any[] = [];
        for (const file of files) {
          const content = fs.readFileSync(path.join(WRITER_OUTPUT, file), "utf-8");
          if (content.includes('status: "edited"') || content.includes('status: "reviewed"') || content.includes('status: "seo_ready"') || content.includes("status: edited")) {
            const titleMatch = content.match(/title:\s*"?([^"\n]+)"?/);
            const tagsMatch = content.match(/tags:\s*\[([^\]]+)\]/);
            publishable.push({
              file,
              title: titleMatch ? titleMatch[1].trim() : "Untitled",
              tags: tagsMatch ? tagsMatch[1].trim() : ""
            });
          }
        }
        return {
          content: [{ type: "text", text: JSON.stringify({ count: publishable.length, articles: publishable }, null, 2) }],
          details: { count: publishable.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR: ${e.message}` }], details: {} };
      }
    }
  });

  // ── Publish to dev.to ──
  pi.registerTool({
    name: "publish_devto",
    label: "Publish to dev.to",
    description: "Publishes an article directly to dev.to. Returns the live URL.",
    parameters: {
      type: "object" as const,
      properties: {
        file: { type: "string" as const, description: "Article filename from output/" },
        title: { type: "string" as const, description: "Article title" },
        tags: { type: "string" as const, description: "Comma-separated tags (max 4)" },
        series: { type: "string" as const, description: "Optional series name" }
      },
      required: ["file", "title"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const path = await import("path");

      // Load dev.to config
      const config = JSON.parse(fs.readFileSync(`${CONTENT_HOME}/platforms.json`, "utf-8"));
      const devto = config.devto;
      if (!devto?.enabled || !devto?.api_key) {
        return { content: [{ type: "text", text: "dev.to not configured in platforms.json" }], details: {} };
      }

      // Read article — strip frontmatter
      const fullContent = fs.readFileSync(path.join(WRITER_OUTPUT, params.file), "utf-8");
      const bodyMatch = fullContent.match(/---[\s\S]*?---\n([\s\S]*)/);
      const body = bodyMatch ? bodyMatch[1].trim() : fullContent;

      const tags = (params.tags || "security,webdev")
        .split(",").map((t: string) => t.trim().toLowerCase().replace(/[^a-z0-9]/g, ""))
        .filter(Boolean).slice(0, 4);

      try {
        const res = await fetch(`${devto.api_url}/articles`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "api-key": devto.api_key },
          body: JSON.stringify({
            article: {
              title: params.title,
              body_markdown: body,
              published: true,
              tags,
              ...(params.series ? { series: params.series } : {})
            }
          })
        });

        if (res.ok) {
          const data = await res.json() as any;
          const url = data.url || data.canonical_url || "published";
          const logLine = `[${new Date().toISOString()}] devto: ${params.title} — ${url}\n`;
          try { fs.appendFileSync(`${AGENT_HOME}/state/publish.log`, logLine); } catch {}
          return { content: [{ type: "text", text: JSON.stringify({ success: true, url, id: data.id, slug: data.slug }, null, 2) }], details: { url } };
        } else {
          const errText = await res.text();
          return { content: [{ type: "text", text: `dev.to error: ${res.status} ${errText}` }], details: {} };
        }
      } catch (e: any) {
        return { content: [{ type: "text", text: `dev.to error: ${e.message}` }], details: {} };
      }
    }
  });

  // ── Archive published article ──
  pi.registerTool({
    name: "archive_article",
    label: "Archive Published Article",
    description: "Moves a published article from output/ to published/ with metadata.",
    parameters: {
      type: "object" as const,
      properties: {
        file: { type: "string" as const, description: "Article filename" },
        devto_url: { type: "string" as const, description: "The dev.to URL" }
      },
      required: ["file", "devto_url"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const path = await import("path");
      try {
        fs.mkdirSync(PUBLISHED_DIR, { recursive: true });
        const src = path.join(WRITER_OUTPUT, params.file);
        let content = fs.readFileSync(src, "utf-8");

        // Update status and add published metadata
        content = content.replace(/status:\s*"?(edited|reviewed|seo_ready)"?/, 'status: "published"');
        const meta = `\n<!-- PUBLISHED: ${new Date().toISOString()} -->\n<!-- DEVTO_URL: ${params.devto_url} -->\n`;
        content = meta + content;

        const dest = path.join(PUBLISHED_DIR, params.file);
        fs.writeFileSync(dest, content);
        fs.unlinkSync(src); // Remove from output/

        return { content: [{ type: "text", text: `Archived: ${params.file} → published/` }], details: {} };
      } catch (e: any) {
        return { content: [{ type: "text", text: `Archive error: ${e.message}` }], details: {} };
      }
    }
  });

  // ── Update tracker ──
  pi.registerTool({
    name: "update_tracker",
    label: "Update Tracker",
    description: "Updates the published-tracker.json with publication results.",
    parameters: {
      type: "object" as const,
      properties: {
        summary: { type: "string" as const, description: "Publication summary" }
      },
      required: ["summary"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const trackerPath = `${CONTENT_HOME}/published-tracker.json`;
      try {
        let tracker: any = {};
        try { tracker = JSON.parse(fs.readFileSync(trackerPath, "utf-8")); } catch {}
        tracker.last_publish_run = new Date().toISOString();
        tracker.last_summary = params.summary;
        tracker.total_published = (tracker.total_published || 0) + 1;
        if (!tracker.history) tracker.history = [];
        tracker.history.push({ date: new Date().toISOString(), summary: params.summary });
        fs.writeFileSync(trackerPath, JSON.stringify(tracker, null, 2));
        return { content: [{ type: "text", text: `Tracker updated: ${params.summary}` }], details: {} };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR: ${e.message}` }], details: {} };
      }
    }
  });

  pi.on("session_start", async () => {
    console.error("[CONTENT-PUBLISHER] Direct-to-devto publisher loaded. Division: CONTENT.");
  });
}
