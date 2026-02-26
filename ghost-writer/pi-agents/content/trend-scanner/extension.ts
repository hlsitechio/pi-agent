/**
 * Trend Scanner Agent Extension
 *
 * HOME: /app/pi-agents/content/trend-scanner/
 * JOB:  Scan trending topics in cybersecurity & technology for article ideas.
 *       ONE JOB. No deviation.
 *
 * Schedule: Every 6 hours
 * Model: GLM-4.7 (for research breadth)
 * Tier: OBSERVE
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { registerBaseTools, registerContentTools, registerResearchTools } from "../../swarm-blueprint/lib/mcp-toolkits";

const AGENT_HOME = "/app/pi-agents/content/trend-scanner";
const CONTENT_HOME = "/app/pi-agents/content";
const HN_STATE = "/app/pi-agents/hackernews-agent/state/posted-ids.json";

export default function (pi: ExtensionAPI) {
  registerBaseTools(pi, "trend-scanner", { home: AGENT_HOME });
  registerContentTools(pi);
  registerResearchTools(pi);

  pi.on("before_agent_start", async () => {
    const fs = await import("fs");
    let govPrompt = "";
    try { govPrompt = fs.readFileSync("/app/pi-agents/swarm-blueprint/governance-prompt.txt", "utf-8"); } catch {}

    return {
      systemPrompt: `You are the TREND SCANNER agent. You live at ${AGENT_HOME}.

IDENTITY:
  Name: trend-scanner
  Division: CONTENT
  Tier: OBSERVE (no network scanning, only public data)
  Reports to: Orchestrator (Claude Opus)
  Commander: rainkode

${govPrompt}

YOUR ONE JOB: Find trending cybersecurity and technology topics that would make great articles.

DATA SOURCES (scan ALL):
- HackerNews: Top stories via API
- CISA KEV: Recently exploited CVEs
- Reddit: r/netsec, r/cybersecurity, r/programming (via old.reddit.com JSON)
- GitHub Trending: Popular repos from last 7 days
- Lobsters: Hottest tech stories
- Bleeping Computer: Latest security news
- The Hacker News: Security news feed
- Krebs on Security: Security intelligence

CROSS-REFERENCE RULE:
If the same topic appears across 3+ sources = +2 trending_score bonus
If topic appears on 2 sources = +1 trending_score bonus

TOPIC CATEGORIES (with target weights):
- Cybersecurity (35%): CVEs, attack techniques, defense strategies, tool releases
- AI & Technology (25%): New models, frameworks, industry shifts
- DevOps & Cloud (15%): Kubernetes, cloud security, CI/CD
- Bug Bounty (15%): Methodology, tools, industry news
- Privacy & OPSEC (10%): Encryption, VPNs, threat models

SCORING CRITERIA (VIRALITY-FIRST):
- virality_score (1-10): How explosive is this right now? HN 500+ points = 10, 200+ = 8, 100+ = 6. Reddit 1k+ upvotes = 10.
- recency (1-10): Published in last 6 hours = 10, 12hrs = 8, 24hrs = 6, 48hrs = 4, older = 2
- trending_score (1-10): How hot is this topic across ALL sources?
- monetization_potential (1-10): Will readers engage/pay for this?
- competition (1-10): How many articles already exist? (lower = less competition = better)
- combined_score = virality * 0.30 + recency * 0.25 + trending * 0.20 + monetization * 0.15 + (10 - competition) * 0.10

VIRALITY SIGNALS (prioritize these):
- HN front page with 300+ points = MUST PICK
- Reddit r/netsec or r/programming with 500+ upvotes = MUST PICK
- Same topic on 3+ sources within 24hrs = MUST PICK
- Major CVE with CISA KEV addition = MUST PICK
- Big tech company security incident = MUST PICK
- AI security breakthrough/failure = HIGH PRIORITY

TIMING RULE: Articles about topics < 24hrs old get MAXIMUM priority. The goal is to be FIRST to publish a quality take. Speed = traffic = money.

DIVERSITY RULE:
Don't pick 5 articles about the same CVE/topic. Ensure topic variety across categories.

OUTPUT FORMAT (for each topic):
{
  "title": "Suggested article title",
  "category": "cybersecurity|ai-tech|devops-cloud|bug-bounty|privacy-opsec",
  "angle": "Unique angle to take",
  "key_points": ["point1", "point2", "point3"],
  "trending_score": 8,
  "monetization_potential": 7,
  "competition": 4,
  "combined_score": 8.0,
  "source_urls": ["https://..."],
  "suggested_platforms": ["medium", "devto"]
}

AVAILABLE TOOLS: check_opsec, read_file, write_file, list_directory, save_state, post_discord (any channel), web_search, web_fetch, search_files, scan_hackernews, scan_tech_trends, scan_reddit, scan_github_trending, scan_lobsters, scan_rss_feeds, save_topics

WORKFLOW:
1. check_opsec — if RED, stop.
2. Scan ALL sources (HN, CISA KEV, Reddit, GitHub, Lobsters, RSS)
3. Score and select top 5 topics
4. save_topics with JSON array
5. post_discord with channel="ghost-trends" and formatted digest of your top 5 trending topics
6. STOP.

DISCORD FORMAT:
📈 **Trending Topics Scan** — [timestamp]
1. **[Title]** (score: X) [CATEGORY]
   → Angle: [unique angle] | Sources: [HN, Reddit, etc.]
2. ...
(Include cross-reference highlights if topic appears on 3+ sources)

RULES:
- Always check OPSEC first
- Max 5 topics per scan
- Skip topics already in the queue (check existing)
- Prefer topics with a UNIQUE ANGLE (not generic overviews)
- ALWAYS post_discord after save_topics
- When done, STOP.`
    };
  });

  // Tool: Scan HackerNews
  pi.registerTool({
    name: "scan_hackernews",
    label: "Scan HackerNews",
    description: "Gets top 50 stories from HackerNews API with virality scoring. Stories sorted by score descending. Includes age in hours and virality tier.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Fetching HN top 50 stories with virality scoring..." }], details: {} });

      try {
        const res = await fetch("https://hacker-news.firebaseio.com/v0/topstories.json");
        const ids = (await res.json() as number[]).slice(0, 50);
        const now = Math.floor(Date.now() / 1000);

        const stories = await Promise.all(
          ids.map(async (id) => {
            try {
              const r = await fetch(`https://hacker-news.firebaseio.com/v0/item/${id}.json`);
              const item = await r.json() as any;
              const ageHours = Math.round((now - (item.time || now)) / 3600);
              const score = item.score || 0;
              const virality = score >= 500 ? "🔥 VIRAL" : score >= 300 ? "⚡ HOT" : score >= 150 ? "📈 TRENDING" : score >= 50 ? "📊 RISING" : "📉 LOW";
              return {
                id: item.id,
                title: item.title || "Untitled",
                url: item.url || `https://news.ycombinator.com/item?id=${item.id}`,
                score,
                comments: item.descendants || 0,
                age_hours: ageHours,
                virality
              };
            } catch { return null; }
          })
        );

        const valid = stories.filter(s => s !== null).sort((a: any, b: any) => b.score - a.score);
        const viral = valid.filter((s: any) => s.score >= 150);
        return {
          content: [{ type: "text", text: JSON.stringify({
            total: valid.length,
            viral_count: viral.length,
            top_stories: valid.slice(0, 20),
            note: "PRIORITIZE: viral/hot stories < 24hrs old. These are guaranteed traffic."
          }, null, 2) }],
          details: { count: valid.length, viral: viral.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `ERROR fetching HN: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Scan Tech Trends
  pi.registerTool({
    name: "scan_tech_trends",
    label: "Scan Tech Trends",
    description: "Checks recent CVEs and security advisories for trending topics. Returns structured data.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Checking recent CVEs and advisories..." }], details: {} });

      try {
        // Check CISA KEV for recent additions
        const kevRes = await fetch("https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json", {
          signal: AbortSignal.timeout(10000)
        });
        const kev = await kevRes.json() as any;
        const recentVulns = (kev.vulnerabilities || []).slice(0, 10).map((v: any) => ({
          cveID: v.cveID,
          vendor: v.vendorProject,
          product: v.product,
          name: v.vulnerabilityName,
          dateAdded: v.dateAdded
        }));

        return {
          content: [{ type: "text", text: JSON.stringify({
            cisa_kev_recent: recentVulns,
            note: "Use these as potential article topics about actively exploited vulnerabilities"
          }, null, 2) }],
          details: { kev_count: recentVulns.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `Trends check partial: ${e.message}. Use HN data for topics.` }], details: {} };
      }
    }
  });

  // Tool: Scan Reddit
  pi.registerTool({
    name: "scan_reddit",
    label: "Scan Reddit",
    description: "Scans r/netsec, r/cybersecurity, r/programming for hot posts. Returns top posts from each subreddit.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Scanning Reddit..." }], details: {} });

      const subreddits = ["netsec", "cybersecurity", "programming"];
      const allPosts: any[] = [];

      try {
        for (const sub of subreddits) {
          const res = await fetch(`https://old.reddit.com/r/${sub}/hot.json?limit=10`, {
            signal: AbortSignal.timeout(10000),
            headers: { "User-Agent": "Mozilla/5.0 (compatible; trend-scanner/1.0)" }
          });
          const data = await res.json() as any;

          for (const post of (data.data?.children || [])) {
            const p = post.data;
            allPosts.push({
              source: "reddit",
              subreddit: sub,
              title: p.title,
              url: p.url,
              score: p.score,
              comments: p.num_comments,
              created: p.created_utc
            });
          }
        }

        return {
          content: [{ type: "text", text: JSON.stringify({ count: allPosts.length, posts: allPosts }, null, 2) }],
          details: { count: allPosts.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `Reddit scan partial: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Scan GitHub Trending
  pi.registerTool({
    name: "scan_github_trending",
    label: "Scan GitHub Trending",
    description: "Fetches trending repositories from the past 7 days on GitHub.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Scanning GitHub trending..." }], details: {} });

      try {
        const weekAgo = new Date();
        weekAgo.setDate(weekAgo.getDate() - 7);
        const dateStr = weekAgo.toISOString().split('T')[0];

        const res = await fetch(
          `https://api.github.com/search/repositories?q=created:>${dateStr}&sort=stars&order=desc&per_page=20`,
          {
            signal: AbortSignal.timeout(10000),
            headers: { "User-Agent": "Mozilla/5.0 (compatible; trend-scanner/1.0)" }
          }
        );
        const data = await res.json() as any;

        const repos = (data.items || []).map((r: any) => ({
          source: "github",
          name: r.full_name,
          description: r.description,
          url: r.html_url,
          stars: r.stargazers_count,
          language: r.language,
          topics: r.topics || []
        }));

        return {
          content: [{ type: "text", text: JSON.stringify({ count: repos.length, repos }, null, 2) }],
          details: { count: repos.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `GitHub scan failed: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Scan Lobsters
  pi.registerTool({
    name: "scan_lobsters",
    label: "Scan Lobsters",
    description: "Fetches hottest stories from Lobste.rs tech community.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Scanning Lobste.rs..." }], details: {} });

      try {
        const res = await fetch("https://lobste.rs/hottest.json", {
          signal: AbortSignal.timeout(10000)
        });
        const stories = await res.json() as any[];

        const formatted = stories.slice(0, 15).map((s: any) => ({
          source: "lobsters",
          title: s.title,
          url: s.url,
          score: s.score,
          comments: s.comment_count,
          tags: s.tags || []
        }));

        return {
          content: [{ type: "text", text: JSON.stringify({ count: formatted.length, stories: formatted }, null, 2) }],
          details: { count: formatted.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `Lobsters scan failed: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Scan RSS Feeds
  pi.registerTool({
    name: "scan_rss_feeds",
    label: "Scan RSS Feeds",
    description: "Fetches latest posts from Bleeping Computer, The Hacker News, and Krebs on Security via RSS.",
    parameters: { type: "object" as const, properties: {}, required: [] as string[] },
    execute: async (_id, _params, _signal, onUpdate) => {
      onUpdate({ content: [{ type: "text", text: "Scanning security RSS feeds..." }], details: {} });

      const feeds = [
        { name: "BleepingComputer", url: "https://www.bleepingcomputer.com/feed/" },
        { name: "TheHackerNews", url: "https://feeds.feedburner.com/TheHackersNews" },
        { name: "KrebsOnSecurity", url: "https://krebsonsecurity.com/feed/" }
      ];

      const allItems: any[] = [];

      try {
        for (const feed of feeds) {
          try {
            const res = await fetch(feed.url, {
              signal: AbortSignal.timeout(10000),
              headers: { "User-Agent": "Mozilla/5.0 (compatible; trend-scanner/1.0)" }
            });
            const xml = await res.text();

            // Basic RSS parsing (extract titles and links)
            const titleMatches = xml.matchAll(/<title><!\[CDATA\[(.*?)\]\]><\/title>|<title>(.*?)<\/title>/g);
            const linkMatches = xml.matchAll(/<link>(.*?)<\/link>|<link href="(.*?)"/g);

            const titles = Array.from(titleMatches).map(m => m[1] || m[2]).filter(Boolean).slice(1, 11); // Skip feed title
            const links = Array.from(linkMatches).map(m => m[1] || m[2]).filter(Boolean).slice(1, 11);

            for (let i = 0; i < Math.min(titles.length, links.length); i++) {
              allItems.push({
                source: feed.name.toLowerCase(),
                title: titles[i],
                url: links[i]
              });
            }
          } catch (e: any) {
            onUpdate({ content: [{ type: "text", text: `${feed.name} failed: ${e.message}` }], details: {} });
          }
        }

        return {
          content: [{ type: "text", text: JSON.stringify({ count: allItems.length, items: allItems }, null, 2) }],
          details: { count: allItems.length }
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `RSS scan partial: ${e.message}` }], details: {} };
      }
    }
  });

  // Tool: Save Topics
  pi.registerTool({
    name: "save_topics",
    label: "Save Topics",
    description: "Saves scored topics to the content queue. Input: JSON string of topics array.",
    parameters: {
      type: "object" as const,
      properties: {
        topics_json: { type: "string" as const, description: "JSON string of topics array with scores" }
      },
      required: ["topics_json"] as string[]
    },
    execute: async (_id, params) => {
      const fs = await import("fs");
      const queuePath = `${CONTENT_HOME}/topics-queue.json`;

      let queue: any = { last_updated: new Date().toISOString(), topics: [] };
      try { queue = JSON.parse(fs.readFileSync(queuePath, "utf-8")); } catch {}

      let newTopics: any[] = [];
      try { newTopics = JSON.parse(params.topics_json); } catch {
        return { content: [{ type: "text", text: "ERROR: Invalid JSON for topics" }], details: {} };
      }

      // Add new topics with status
      for (const topic of newTopics) {
        topic.status = "pending";
        topic.added_at = new Date().toISOString();
        topic.scanned_by = "trend-scanner";
        queue.topics.push(topic);
      }

      // Keep only last 50 topics
      if (queue.topics.length > 50) {
        queue.topics = queue.topics.slice(-50);
      }

      queue.last_updated = new Date().toISOString();
      fs.writeFileSync(queuePath, JSON.stringify(queue, null, 2));

      // Log
      const logLine = `[${new Date().toISOString()}] Added ${newTopics.length} topics to queue (total: ${queue.topics.length})\n`;
      fs.appendFileSync(`${AGENT_HOME}/state/scan.log`, logLine);

      return {
        content: [{ type: "text", text: `Saved ${newTopics.length} topics. Queue total: ${queue.topics.length}` }],
        details: { added: newTopics.length, total: queue.topics.length }
      };
    }
  });

  pi.on("session_start", async () => {
    console.error("[TREND-SCANNER] Trend Scanner agent loaded. Governed. Division: CONTENT.");
  });
}
