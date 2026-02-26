/**
 * Article Reviewer Agent Extension
 *
 * HOME: /app/pi-agents/content/article-reviewer/
 * JOB:  Fact-check one edited article. Verify every stat, CVE, claim.
 *       ZERO tolerance for fabricated data. Gate before publishing.
 *
 * Schedule: Every 6 hours (after article-editor)
 * Model: GLM-5 (via Ollama) — chosen for editorial precision
 * Tier: OBSERVE
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/article-reviewer";
const CONTENT_HOME = "/app/pi-agents/content";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "article-reviewer", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  // Custom tool: get next edited article for review
  pi.registerTool({
    name: "get_edited_article",
    label: "Get Edited Article",
    description: "Find the next article with status 'edited' that needs fact-checking review.",
    parameters: {
      type: "object" as const,
      properties: {},
      required: [] as string[]
    },
    execute: async () => {
      const fs = await import("fs");
      const path = await import("path");
      const outputDir = `${CONTENT_HOME}/article-writer/output`;
      try {
        const files = fs.readdirSync(outputDir).filter((f: string) => f.endsWith(".md")).sort().reverse();
        for (const file of files) {
          const content = fs.readFileSync(path.join(outputDir, file), "utf-8");
          const statusMatch = content.match(/^status:\s*"?edited"?\s*$/m);
          if (statusMatch) {
            return {
              content: [{ type: "text" as const, text: content }],
              details: { file, path: path.join(outputDir, file), slug: file.replace(/\.md$/, "") }
            };
          }
        }
        return { content: [{ type: "text" as const, text: "No edited articles found in queue." }], details: {} };
      } catch (e: any) {
        return { content: [{ type: "text" as const, text: `Error reading articles: ${e.message}` }], details: {} };
      }
    }
  });

  // Custom tool: save review verdict
  pi.registerTool({
    name: "save_reviewed",
    label: "Save Review Verdict",
    description: "Save the review verdict for an article. Updates article status and writes review notes.",
    parameters: {
      type: "object" as const,
      properties: {
        file_path: { type: "string" as const, description: "Path to the article file" },
        verdict: { type: "string" as const, description: "APPROVED, NEEDS_REVISION, or REJECTED" },
        review_notes: { type: "string" as const, description: "Detailed review notes — what was verified, what failed" },
        unverified_claims: { type: "string" as const, description: "JSON array of claims that could not be verified" },
        verified_facts: { type: "string" as const, description: "JSON array of facts that were successfully verified with sources" }
      },
      required: ["file_path", "verdict", "review_notes"] as string[]
    },
    execute: async (_id: string, params: any) => {
      const fs = await import("fs");
      try {
        let content = fs.readFileSync(params.file_path, "utf-8");

        // Update status based on verdict
        const newStatus = params.verdict === "APPROVED" ? "reviewed" :
                         params.verdict === "NEEDS_REVISION" ? "needs-revision" : "rejected";
        content = content.replace(/^status:\s*"?edited"?\s*$/m, `status: "${newStatus}"`);

        // Add review metadata to frontmatter
        const reviewBlock = `reviewed_by: "article-reviewer-agent"
review_date: "${new Date().toISOString()}"
review_verdict: "${params.verdict}"`;
        content = content.replace(/^---\s*$/m, `---\n${reviewBlock}`);

        fs.writeFileSync(params.file_path, content);

        // Write review log
        const logDir = `${AGENT_HOME}/state`;
        try { fs.mkdirSync(logDir, { recursive: true }); } catch {}
        const logEntry = `\n## ${new Date().toISOString()} — ${params.verdict}\nFile: ${params.file_path}\n${params.review_notes}\n`;
        fs.appendFileSync(`${logDir}/reviews.log`, logEntry);

        return {
          content: [{ type: "text" as const, text: `Review saved: ${params.verdict} for ${params.file_path}` }],
          details: { verdict: params.verdict, status: newStatus }
        };
      } catch (e: any) {
        return { content: [{ type: "text" as const, text: `Error saving review: ${e.message}` }], details: {} };
      }
    }
  });

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    return {
      systemPrompt: `You are the ARTICLE REVIEWER agent. You live at ${AGENT_HOME}.

IDENTITY:
  Name: article-reviewer
  Division: CONTENT
  Tier: OBSERVE
  Reports to: Orchestrator (Claude Opus)
  Commander: rainkode

${govPrompt}

YOUR ONE JOB: Fact-check one edited article before it can be published.

REVIEW METHODOLOGY:
1. Read the article thoroughly
2. Extract EVERY factual claim:
   - Statistics and percentages
   - CVE numbers and vulnerability details
   - Company names and product versions
   - Dates, timelines, and events
   - Technical specifications
3. Verify each claim:
   - CVEs: use research_cve tool — must return valid data
   - Statistics: use verify_stat tool — must find authoritative source
   - Products: use web_search — must confirm existence
   - Events: use web_search — must find news coverage
4. Flag anything unverifiable
5. Write verdict

HALLUCINATION DETECTION RULES:
- Round numbers (exactly 40%, 50%, etc.) are suspicious — verify harder
- CVE IDs that don't exist in NVD/Shodan = INSTANT REJECTION
- Quotes without attribution = flag for removal
- "Studies show..." without naming the study = flag
- Company names you can't find via web search = likely fabricated
- Statistics from "recent reports" without naming the report = flag

VERDICT CRITERIA:
- APPROVED: All major claims verified. Minor stylistic issues OK.
- NEEDS_REVISION: 1-3 unverifiable claims that can be fixed. Send back with specific notes.
- REJECTED: 4+ fabricated facts, fake CVEs, or systematically unreliable. Needs full rewrite.

AVAILABLE TOOLS: check_opsec, read_file, write_file, list_directory, save_state, post_discord, web_search, web_fetch, search_files, research_cve, research_cves_by_product, research_hackernews, verify_stat, research_cisa_kev, research_trending, read_cowork_context, write_cowork_context, get_edited_article, save_reviewed

Follow governance rules. Review ONE article, then STOP.`
    };
  });

  pi.on("session_start", async () => {
    console.error("[ARTICLE-REVIEWER] Agent loaded. Governed. Zero tolerance for fake data.");
  });
}
