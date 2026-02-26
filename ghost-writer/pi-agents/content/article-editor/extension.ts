/**
 * Article Editor Agent Extension
 * Division: CONTENT
 * JOB: Review and improve drafted articles for quality and human voice.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/article-editor";
const CONTENT_HOME = "/app/pi-agents/content";
const WRITER_OUTPUT = "/app/pi-agents/content/article-writer/output";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "article-editor", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    return {
      systemPrompt: `You are the ARTICLE EDITOR agent. Division: CONTENT.

${govPrompt}

COWORK MODE:
- Read cowork context from writer using read_cowork_context
- Check what facts the writer verified
- If you see unverified claims, flag them
- Write your edit notes to cowork context using write_cowork_context

YOUR ONE JOB: Take a drafted article and make it publication-ready.

AVAILABLE TOOLS: check_opsec, read_file, write_file, list_directory, save_state, post_discord (any channel), get_draft, save_edited

EDITING CHECKLIST:
1. TONE: Does it sound like a real person wrote it? Add "I", opinions, personality.
2. SLOP CHECK: Kill these phrases:
   - "In this article, we will..."
   - "It's important to note..."
   - "In today's digital landscape..."
   - "Let's dive in/deep dive into..."
   - "Without further ado..."
   - Any phrase that screams "AI wrote this"
3. STRUCTURE: Hook → Context → Deep Dive → Takeaways → Sign-off
4. PARAGRAPHS: Max 3-4 sentences each. Break walls of text.
5. CODE: Are examples real and working? Specific tools/versions?
6. ACCURACY: Any claims that need verification?
7. LENGTH: 1500-2500 words. Cut fluff, not substance.
8. HEADERS: Clear, engaging. Not generic.

OUTPUT: The full edited article in markdown.`
    };
  });

  pi.registerTool({
    name: "get_draft",
    label: "Get Draft",
    description: "Loads the latest unedited article draft from the writer's output.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async () => {
      const fs = await import("fs");
      const path = await import("path");

      try {
        const files = fs.readdirSync(WRITER_OUTPUT)
          .filter((f: string) => f.endsWith(".md"))
          .sort()
          .reverse();

        for (const file of files) {
          const content = fs.readFileSync(path.join(WRITER_OUTPUT, file), "utf-8");
          if (content.includes('status: "draft"')) {
            return {
              content: [{ type: "text", text: `FILE: ${file}\n\n${content}` }],
              details: { file }
            };
          }
        }

        return { content: [{ type: "text", text: "NO UNEDITED DRAFTS FOUND. Run article-writer first." }], details: {} };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR: ${e.message}` }], details: {} };
      }
    }
  });

  pi.registerTool({
    name: "save_edited",
    label: "Save Edited",
    description: "Saves the edited article, updating its status to 'edited'.",
    parameters: {
      type: "object" as const,
      properties: {
        original_file: { type: "string" as const, description: "Original draft filename" },
        content: { type: "string" as const, description: "Full edited article markdown" },
        edit_notes: { type: "string" as const, description: "Brief notes on what was changed" }
      },
      required: ["original_file", "content"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const path = await import("path");
      const originalPath = path.join(WRITER_OUTPUT, params.original_file);

      // Update status in content
      let edited = params.content.replace('status: "draft"', 'status: "edited"');

      // Add edit metadata
      const editMeta = `edited_at: "${new Date().toISOString()}"
edit_notes: "${(params.edit_notes || "Reviewed and improved").replace(/"/g, "'")}"
`;
      edited = edited.replace('status: "edited"', `status: "edited"\n${editMeta}`);

      fs.writeFileSync(originalPath, edited);

      const logLine = `[${new Date().toISOString()}] Edited: ${params.original_file} — ${params.edit_notes || "standard review"}\n`;
      fs.appendFileSync(`${AGENT_HOME}/state/editor.log`, logLine);

      return {
        content: [{ type: "text", text: `Article edited and saved: ${params.original_file}` }],
        details: { file: params.original_file }
      };
    }
  });

  pi.on("session_start", async () => {
    console.error("[ARTICLE-EDITOR] Article Editor agent loaded. Governed. Division: CONTENT.");
  });
}
