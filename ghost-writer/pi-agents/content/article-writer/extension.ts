/**
 * Article Writer Agent Extension
 *
 * HOME: /app/pi-agents/content/article-writer/
 * JOB:  Write one high-quality article from the topic queue.
 *       ONE JOB. No deviation.
 *
 * Schedule: Every 8 hours
 * Model: GLM-4.7 (for technical depth)
 * Tier: OBSERVE
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/article-writer";
const CONTENT_HOME = "/app/pi-agents/content";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "article-writer", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    return {
      systemPrompt: `You are the ARTICLE WRITER agent. You live at ${AGENT_HOME}.

IDENTITY:
  Name: article-writer
  Division: CONTENT
  Tier: OBSERVE
  Reports to: Orchestrator (Claude Opus)
  Commander: rainkode

${govPrompt}

RESEARCH-FIRST PIPELINE:
- Before writing, you MUST research the topic using research tools
- Use research_hackernews to check community discussion
- Use research_cve to verify any vulnerability references
- Use verify_stat to confirm any statistics you plan to include
- Use research_cisa_kev for actively exploited vulnerabilities
- Write research findings to cowork context using write_cowork_context
- NEVER include a statistic you haven't verified
- NEVER reference a CVE you haven't confirmed exists

COWORK MODE:
- Read cowork context from previous agents using read_cowork_context
- Write your research notes for the next agent using write_cowork_context
- Include verified_facts with sources in your cowork notes

YOUR ONE JOB: Write one high-quality article from the topic queue.

WRITING VOICE:
- You are "rainkode" — a seasoned security researcher and tech enthusiast
- First person. Casual but expert. Opinionated.
- You've seen things. You have war stories. You share them.
- No corporate speak. No textbook tone.
- Think: "a blog post your hacker friend would actually read"

ANTI-SLOP RULES (CRITICAL):
- NEVER start with "In this article, we will explore..."
- NEVER use "It's important to note that..."
- NEVER use "In today's digital landscape..."
- NEVER use "Let's dive in..."
- NEVER use passive voice when active works
- NEVER pad content to reach word count — every sentence earns its place
- DO use: contractions, opinions, humor, real examples
- DO name specific tools, versions, CVEs
- DO include working code/commands

ARTICLE STRUCTURE:
1. Hook (2-3 sentences that grab attention)
2. Context (why now, why this matters)
3. Deep dive (3-5 sections with technical detail)
4. Actionable takeaways (bulleted list)
5. Sign-off (brief, memorable)

TARGET LENGTH: 1500-2500 words
OUTPUT FORMAT: Full markdown article

AVAILABLE TOOLS: check_opsec, read_file, write_file, list_directory, save_state, post_discord (any channel), web_search, web_fetch, search_files, get_next_topic, get_template, save_article

RULES:
- Check OPSEC first
- Pick ONE topic from the queue
- Write the FULL article (not an outline)
- Save it when done
- STOP after saving. Do not write more.`
    };
  });

  // Tool: Get Next Topic
  pi.registerTool({
    name: "get_next_topic",
    label: "Get Next Topic",
    description: "Gets the highest-scored pending topic from the queue.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async () => {
      const fs = await import("fs");
      const queuePath = `${CONTENT_HOME}/topics-queue.json`;

      try {
        const queue = JSON.parse(fs.readFileSync(queuePath, "utf-8"));
        const pending = queue.topics.filter((t: any) => t.status === "pending");

        if (pending.length === 0) {
          return { content: [{ type: "text", text: "NO PENDING TOPICS. Run trend-scanner first." }], details: {} };
        }

        // Sort by combined_score descending
        pending.sort((a: any, b: any) => (b.combined_score || 0) - (a.combined_score || 0));
        const topic = pending[0];

        // Mark as "writing"
        const idx = queue.topics.findIndex((t: any) => t.title === topic.title && t.status === "pending");
        if (idx >= 0) {
          queue.topics[idx].status = "writing";
          queue.topics[idx].writing_started = new Date().toISOString();
          fs.writeFileSync(queuePath, JSON.stringify(queue, null, 2));
        }

        return {
          content: [{ type: "text", text: JSON.stringify(topic, null, 2) }],
          details: { title: topic.title, category: topic.category }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR reading queue: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Get Template
  pi.registerTool({
    name: "get_template",
    label: "Get Template",
    description: "Loads the article template for the given category.",
    parameters: {
      type: "object" as const,
      properties: {
        category: { type: "string" as const, description: "Category: cybersecurity, ai-tech, devops-cloud, bug-bounty, privacy-opsec" }
      },
      required: ["category"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const templatePath = `${AGENT_HOME}/templates/${params.category}.md`;

      try {
        const template = fs.readFileSync(templatePath, "utf-8");
        return { content: [{ type: "text", text: template }], details: {} };
      } catch {
        return {
          content: [{ type: "text", text: "Template not found. Use default structure: Hook \u2192 Context \u2192 Deep Dive (3-5 sections) \u2192 Actionable Takeaways \u2192 Sign-off" }],
          details: {}
        };
      }
    }
  });

  // Tool: Save Article
  pi.registerTool({
    name: "save_article",
    label: "Save Article",
    description: "Saves the written article to output/ directory and updates the queue.",
    parameters: {
      type: "object" as const,
      properties: {
        title: { type: "string" as const, description: "Article title" },
        category: { type: "string" as const, description: "Article category" },
        content: { type: "string" as const, description: "Full article markdown content" },
        suggested_tags: { type: "string" as const, description: "Comma-separated tags" }
      },
      required: ["title", "content"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const date = new Date().toISOString().split("T")[0];
      const slug = params.title.toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .substring(0, 60);

      const filename = `${date}-${slug}.md`;
      const outputPath = `${AGENT_HOME}/output/${filename}`;

      // Build frontmatter
      const frontmatter = `---
title: "${params.title}"
category: "${params.category || "general"}"
tags: [${(params.suggested_tags || "").split(",").map((t: string) => `"${t.trim()}"`).join(", ")}]
date: "${new Date().toISOString()}"
status: "draft"
word_count: ${params.content.split(/\s+/).length}
author: "rainkode"
generated_by: "article-writer-agent"
---

`;

      fs.writeFileSync(outputPath, frontmatter + params.content);

      // Update queue status
      const queuePath = `${CONTENT_HOME}/topics-queue.json`;
      try {
        const queue = JSON.parse(fs.readFileSync(queuePath, "utf-8"));
        const idx = queue.topics.findIndex((t: any) => t.status === "writing");
        if (idx >= 0) {
          queue.topics[idx].status = "drafted";
          queue.topics[idx].draft_file = outputPath;
          queue.topics[idx].drafted_at = new Date().toISOString();
          fs.writeFileSync(queuePath, JSON.stringify(queue, null, 2));
        }
      } catch {}

      // Log
      const logLine = `[${new Date().toISOString()}] Wrote: ${filename} (${params.content.split(/\s+/).length} words)\n`;
      fs.appendFileSync(`${AGENT_HOME}/state/writer.log`, logLine);

      return {
        content: [{ type: "text", text: `Article saved: ${filename} (${params.content.split(/\s+/).length} words)` }],
        details: { file: outputPath, words: params.content.split(/\s+/).length }
      };
    }
  });

  pi.on("session_start", async () => {
    console.error("[ARTICLE-WRITER] Article Writer agent loaded. Governed. Division: CONTENT.");
  });
}
