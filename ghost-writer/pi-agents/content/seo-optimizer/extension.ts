/**
 * SEO Optimizer Agent Extension
 * Division: CONTENT
 * JOB: Optimize edited articles for search engine performance.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/seo-optimizer";
const CONTENT_HOME = "/app/pi-agents/content";
const EDITOR_OUTPUT = "/app/pi-agents/content/article-writer/output";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "seo-optimizer", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    return {
      systemPrompt: `You are the SEO OPTIMIZER agent. Division: CONTENT.

${govPrompt}

YOUR ONE JOB: Take an edited article and optimize it for search engines.

AVAILABLE TOOLS: check_opsec, read_file, write_file, list_directory, save_state, post_discord (any channel), web_search, web_fetch, search_files, get_edited_articles, optimize_seo, save_optimized

SEO OPTIMIZATION CHECKLIST:
1. META DESCRIPTION: 150-160 characters, includes primary keyword, compelling call-to-action
2. KEYWORDS: Extract 5-10 primary keywords from content (natural, not stuffed)
3. TITLE OPTIMIZATION:
   - Under 60 characters
   - Include primary keyword near the beginning
   - Use power words (How, Why, Ultimate, Guide, Best, etc.)
   - Add numbers where relevant (5 Ways, 10 Tips, etc.)
4. HEADER STRUCTURE:
   - Proper H2/H3 hierarchy
   - Headers include variations of target keywords
   - Natural, reader-friendly (not keyword-stuffed)
5. INTERNAL LINKS: 3-5 suggestions for linking to related topics
   - Context: where to place the link
   - Anchor text: natural, descriptive
   - Target: related article topic (not URL, just topic)
6. EXTERNAL LINKS: 2-3 authoritative sources
   - High-quality, reputable sites
   - Add value to reader
   - Natural anchor text
7. SCHEMA MARKUP: Suggest appropriate schema type
   - Article: news, blog posts, research
   - HowTo: tutorials, guides, instructions
   - FAQPage: question-based content
   - Include key fields for the schema type

OUTPUT: The optimized article with SEO metadata in frontmatter.`
    };
  });

  pi.registerTool({
    name: "get_edited_articles",
    label: "Get Edited Articles",
    description: "Loads the latest article with status 'edited' that needs SEO optimization.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async () => {
      const fs = await import("fs");
      const path = await import("path");

      try {
        const files = fs.readdirSync(EDITOR_OUTPUT)
          .filter((f: string) => f.endsWith(".md"))
          .sort()
          .reverse();

        for (const file of files) {
          const content = fs.readFileSync(path.join(EDITOR_OUTPUT, file), "utf-8");
          if (content.includes('status: "edited"') || content.includes('status: "reviewed"')) {
            return {
              content: [{ type: "text", text: `FILE: ${file}\n\n${content}` }],
              details: { file }
            };
          }
        }

        return { content: [{ type: "text", text: "NO EDITED ARTICLES FOUND. Run article-editor first." }], details: {} };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR: ${e.message}` }], details: {} };
      }
    }
  });

  pi.registerTool({
    name: "optimize_seo",
    label: "Optimize SEO",
    description: "Apply SEO optimizations to article content.",
    parameters: {
      type: "object" as const,
      properties: {
        content: { type: "string" as const, description: "Full article content to optimize" },
        meta_description: { type: "string" as const, description: "SEO meta description (150-160 chars)" },
        keywords: { type: "string" as const, description: "Comma-separated keywords" },
        optimized_title: { type: "string" as const, description: "SEO-optimized title (under 60 chars)" }
      },
      required: ["content", "meta_description", "keywords"] as string[]
    },
    execute: async (_id, params) => {
      // This is a pass-through tool that validates the optimization
      // The actual content transformation happens in the agent's logic
      const descLength = params.meta_description.length;
      if (descLength < 150 || descLength > 160) {
        return {
          content: [{ type: "text", text: `WARNING: Meta description is ${descLength} chars (should be 150-160). Please adjust.` }],
          details: { valid: false }
        };
      }

      return {
        content: [{ type: "text", text: "SEO optimizations validated. Ready to save." }],
        details: { valid: true }
      };
    }
  });

  pi.registerTool({
    name: "save_optimized",
    label: "Save Optimized",
    description: "Saves the SEO-optimized article, updating its status to 'seo_ready'.",
    parameters: {
      type: "object" as const,
      properties: {
        original_file: { type: "string" as const, description: "Original article filename" },
        content: { type: "string" as const, description: "Full optimized article markdown" },
        meta_description: { type: "string" as const, description: "SEO meta description" },
        keywords: { type: "string" as const, description: "Comma-separated keywords" },
        optimized_title: { type: "string" as const, description: "SEO-optimized title" },
        internal_links: { type: "string" as const, description: "Internal link suggestions (JSON array)" },
        external_links: { type: "string" as const, description: "External link suggestions (JSON array)" },
        schema_type: { type: "string" as const, description: "Suggested schema type (Article/HowTo/FAQPage)" }
      },
      required: ["original_file", "content", "meta_description", "keywords"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const path = await import("path");
      const originalPath = path.join(EDITOR_OUTPUT, params.original_file);

      // Update status and add SEO metadata
      let optimized = params.content.replace(/status: "(edited|reviewed)"/, 'status: "seo_ready"');

      // Add SEO metadata to frontmatter
      const seoMeta = `seo_optimized_at: "${new Date().toISOString()}"
meta_description: "${params.meta_description.replace(/"/g, "'")}"
keywords: [${params.keywords.split(",").map((k: string) => `"${k.trim()}"`).join(", ")}]
${params.optimized_title ? `seo_title: "${params.optimized_title.replace(/"/g, "'")}"` : ""}
${params.schema_type ? `schema_type: "${params.schema_type}"` : ""}
${params.internal_links ? `internal_links: ${params.internal_links}` : ""}
${params.external_links ? `external_links: ${params.external_links}` : ""}
`;

      optimized = optimized.replace('status: "seo_ready"', `status: "seo_ready"\n${seoMeta}`);

      fs.writeFileSync(originalPath, optimized);

      const logLine = `[${new Date().toISOString()}] SEO optimized: ${params.original_file} — keywords: ${params.keywords}\n`;
      fs.appendFileSync(`${AGENT_HOME}/state/seo.log`, logLine);

      return {
        content: [{ type: "text", text: `Article SEO optimized and saved: ${params.original_file}` }],
        details: { file: params.original_file }
      };
    }
  });

  pi.on("session_start", async () => {
    console.error("[SEO-OPTIMIZER] SEO Optimizer agent loaded. Governed. Division: CONTENT.");
  });
}
