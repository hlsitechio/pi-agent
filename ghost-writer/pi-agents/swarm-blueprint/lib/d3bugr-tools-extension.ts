/**
 * D3BUGR Tools Extension for Pi Agents
 *
 * Registers d3bugr MCP tools as Pi tools using HTTP API calls.
 * This allows Pi agents to access 199+ security tools without direct MCP access.
 *
 * All tools run on Railway cloud (https://d3bugr-production.up.railway.app)
 * and do not expose the local IP address.
 */

const D3BUGR_HOST = "https://d3bugr-production.up.railway.app";

interface D3BugrResponse {
  success: boolean;
  data?: any;
  error?: string;
}

// === CORE API CALLER ===

async function callD3bugr(tool: string, params: Record<string, any>): Promise<D3BugrResponse> {
  try {
    const response = await fetch(`${D3BUGR_HOST}/api/tools/${tool}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(params)
    });

    if (!response.ok) {
      return {
        success: false,
        error: `HTTP ${response.status}: ${response.statusText}`
      };
    }

    const data = await response.json();
    return { success: true, data };
  } catch (error: any) {
    return {
      success: false,
      error: error.message || "Unknown error"
    };
  }
}

// === TOOL DEFINITIONS ===

export const d3bugrTools = {
  /**
   * Subdomain enumeration using subfinder
   */
  d3bugr_subfinder: {
    description: "Enumerate subdomains for a target domain using subfinder",
    parameters: {
      type: "object",
      properties: {
        domain: {
          type: "string",
          description: "Target domain (e.g., example.com)"
        }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string }) => {
      return await callD3bugr("subfinder_scan", { domain: args.domain });
    }
  },

  /**
   * HTTP probing with httpx
   */
  d3bugr_httpx: {
    description: "Probe URLs/domains for HTTP services and extract metadata",
    parameters: {
      type: "object",
      properties: {
        targets: {
          type: "string",
          description: "Comma-separated list of URLs or domains to probe"
        }
      },
      required: ["targets"]
    },
    execute: async (args: { targets: string }) => {
      return await callD3bugr("httpx_probe", { targets: args.targets });
    }
  },

  /**
   * Vulnerability scanning with Nuclei
   */
  d3bugr_nuclei: {
    description: "Scan target for vulnerabilities using Nuclei templates",
    parameters: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Target URL or domain"
        },
        severity: {
          type: "string",
          description: "Severity filter (critical,high,medium,low,info)",
          default: "critical,high"
        }
      },
      required: ["target"]
    },
    execute: async (args: { target: string; severity?: string }) => {
      return await callD3bugr("nuclei_scan", {
        target: args.target,
        severity: args.severity || "critical,high"
      });
    }
  },

  /**
   * Quick Nuclei scan (critical/high only)
   */
  d3bugr_nuclei_quick: {
    description: "Quick Nuclei scan targeting only critical/high severity issues",
    parameters: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Target URL or domain"
        }
      },
      required: ["target"]
    },
    execute: async (args: { target: string }) => {
      return await callD3bugr("nuclei_quick", { target: args.target });
    }
  },

  /**
   * Port scanning with Nmap
   */
  d3bugr_nmap: {
    description: "Scan target ports using Nmap",
    parameters: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Target IP or domain"
        },
        ports: {
          type: "string",
          description: "Port specification (top-100, 1-1000, 80,443, etc.)",
          default: "top-100"
        }
      },
      required: ["target"]
    },
    execute: async (args: { target: string; ports?: string }) => {
      return await callD3bugr("nmap_scan", {
        target: args.target,
        ports: args.ports || "top-100"
      });
    }
  },

  /**
   * Quick Nmap scan (top 100 ports)
   */
  d3bugr_nmap_quick: {
    description: "Quick Nmap scan of top 100 ports",
    parameters: {
      type: "object",
      properties: {
        target: {
          type: "string",
          description: "Target IP or domain"
        }
      },
      required: ["target"]
    },
    execute: async (args: { target: string }) => {
      return await callD3bugr("nmap_quick", { target: args.target });
    }
  },

  /**
   * XSS scanning with Dalfox
   */
  d3bugr_dalfox: {
    description: "Scan for XSS vulnerabilities using Dalfox",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL with parameters"
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string }) => {
      return await callD3bugr("dalfox_xss_scan", { url: args.url });
    }
  },

  /**
   * SQL injection scanning with SQLMap
   */
  d3bugr_sqlmap: {
    description: "Test for SQL injection vulnerabilities using SQLMap",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL with parameters"
        },
        level: {
          type: "number",
          description: "Test level (1-5, higher = more thorough)",
          default: 1
        },
        risk: {
          type: "number",
          description: "Risk level (1-3, higher = more aggressive)",
          default: 1
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string; level?: number; risk?: number }) => {
      return await callD3bugr("sqlmap_scan", {
        url: args.url,
        batch: true,
        level: args.level || 1,
        risk: args.risk || 1
      });
    }
  },

  /**
   * Quick SQLMap test
   */
  d3bugr_sqlmap_test: {
    description: "Quick SQLMap test for obvious SQL injection issues",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL with parameters"
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string }) => {
      return await callD3bugr("sqlmap_test", { url: args.url });
    }
  },

  /**
   * Directory fuzzing with FFUF
   */
  d3bugr_ffuf: {
    description: "Fuzz directories and files using FFUF",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL (use FUZZ as placeholder)"
        },
        wordlist: {
          type: "string",
          description: "Wordlist name (common, medium, large, api, etc.)",
          default: "common"
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string; wordlist?: string }) => {
      return await callD3bugr("ffuf_scan", {
        url: args.url,
        wordlist: args.wordlist || "common"
      });
    }
  },

  /**
   * Directory fuzzing with Feroxbuster
   */
  d3bugr_feroxbuster: {
    description: "Recursive directory fuzzing using Feroxbuster",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target base URL"
        },
        wordlist: {
          type: "string",
          description: "Wordlist name (common, medium, large, etc.)",
          default: "common"
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string; wordlist?: string }) => {
      return await callD3bugr("feroxbuster_scan", {
        url: args.url,
        wordlist: args.wordlist || "common"
      });
    }
  },

  /**
   * Web crawling with Katana
   */
  d3bugr_katana: {
    description: "Crawl website and discover endpoints using Katana",
    parameters: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description: "Target URL to crawl"
        },
        depth: {
          type: "number",
          description: "Crawl depth (1-5)",
          default: 2
        }
      },
      required: ["url"]
    },
    execute: async (args: { url: string; depth?: number }) => {
      return await callD3bugr("katana_crawl", {
        url: args.url,
        depth: args.depth || 2
      });
    }
  },

  /**
   * DNS lookup
   */
  d3bugr_dns_lookup: {
    description: "Perform DNS lookups for various record types",
    parameters: {
      type: "object",
      properties: {
        domain: {
          type: "string",
          description: "Domain to query"
        },
        record_type: {
          type: "string",
          description: "DNS record type (A, AAAA, MX, TXT, NS, CNAME, etc.)",
          default: "A"
        }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string; record_type?: string }) => {
      return await callD3bugr("dns_lookup", {
        domain: args.domain,
        record_type: args.record_type || "A"
      });
    }
  },

  /**
   * WHOIS lookup
   */
  d3bugr_dns_whois: {
    description: "Retrieve WHOIS information for a domain",
    parameters: {
      type: "object",
      properties: {
        domain: {
          type: "string",
          description: "Domain to query"
        }
      },
      required: ["domain"]
    },
    execute: async (args: { domain: string }) => {
      return await callD3bugr("dns_whois", { domain: args.domain });
    }
  },

  /**
   * OSINT harvesting with theHarvester
   */
  d3bugr_harvest: {
    description: "Gather OSINT data (emails, subdomains, IPs) using theHarvester",
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
      return await callD3bugr("harvest", { domain: args.domain });
    }
  },

  /**
   * Quick OSINT harvest
   */
  d3bugr_harvest_quick: {
    description: "Quick OSINT harvest using fast sources only",
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
      return await callD3bugr("harvest_quick", { domain: args.domain });
    }
  },

  /**
   * Shodan IP lookup
   */
  d3bugr_shodan_ip: {
    description: "Look up IP address information on Shodan",
    parameters: {
      type: "object",
      properties: {
        ip: {
          type: "string",
          description: "IP address to lookup"
        }
      },
      required: ["ip"]
    },
    execute: async (args: { ip: string }) => {
      return await callD3bugr("shodan_ip_lookup", { ip: args.ip });
    }
  },

  /**
   * Shodan search
   */
  d3bugr_shodan_search: {
    description: "Search Shodan using custom queries",
    parameters: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Shodan search query"
        }
      },
      required: ["query"]
    },
    execute: async (args: { query: string }) => {
      return await callD3bugr("shodan_search", { query: args.query });
    }
  },

  /**
   * Health check
   */
  d3bugr_health: {
    description: "Check d3bugr service health and availability",
    parameters: {
      type: "object",
      properties: {}
    },
    execute: async () => {
      try {
        const response = await fetch(`${D3BUGR_HOST}/health`);
        return {
          success: response.ok,
          data: {
            status: response.status,
            available: response.ok
          }
        };
      } catch (error: any) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  }
};

// === REGISTRATION HELPER ===

/**
 * Register all d3bugr tools with a Pi agent
 *
 * Usage in agent extension:
 * ```typescript
 * import { registerD3bugrTools } from "../swarm-blueprint/lib/d3bugr-tools-extension";
 *
 * export default function defineTools(tools: any) {
 *   registerD3bugrTools(tools);
 *   // ... register other tools
 * }
 * ```
 */
export function registerD3bugrTools(toolsRegistry: any) {
  for (const [name, tool] of Object.entries(d3bugrTools)) {
    toolsRegistry[name] = tool;
  }
}

// === STANDALONE CALLER (for non-Pi usage) ===

/**
 * Call any d3bugr tool directly without Pi agent registration
 *
 * Usage:
 * ```typescript
 * import { callD3bugrTool } from "../swarm-blueprint/lib/d3bugr-tools-extension";
 *
 * const result = await callD3bugrTool("d3bugr_subfinder", { domain: "example.com" });
 * ```
 */
export async function callD3bugrTool(toolName: string, params: Record<string, any>): Promise<D3BugrResponse> {
  const tool = (d3bugrTools as any)[toolName];
  if (!tool) {
    return {
      success: false,
      error: `Tool ${toolName} not found`
    };
  }
  return await tool.execute(params);
}

// === BATCH OPERATIONS ===

/**
 * Run multiple d3bugr tools in sequence
 */
export async function runD3bugrBatch(operations: Array<{ tool: string; params: Record<string, any> }>): Promise<D3BugrResponse[]> {
  const results: D3BugrResponse[] = [];
  for (const op of operations) {
    const result = await callD3bugrTool(op.tool, op.params);
    results.push(result);
  }
  return results;
}

/**
 * Run multiple d3bugr tools in parallel
 */
export async function runD3bugrParallel(operations: Array<{ tool: string; params: Record<string, any> }>): Promise<D3BugrResponse[]> {
  const promises = operations.map(op => callD3bugrTool(op.tool, op.params));
  return await Promise.all(promises);
}
