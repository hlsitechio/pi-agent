/**
 * D3BUGR Bridge — Direct API access for TypeScript/Node.js
 *
 * This module provides direct function calls to d3bugr tools via HTTP API.
 * Use this when you want simple async functions instead of Pi tool registration.
 *
 * Usage:
 * ```typescript
 * import * as d3bugr from "../swarm-blueprint/lib/d3bugr-bridge";
 *
 * const subdomains = await d3bugr.subfinder("example.com");
 * const scan = await d3bugr.nuclei("https://example.com");
 * ```
 */

const D3BUGR_HOST = "https://d3bugr-production.up.railway.app";

interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
}

// === CORE API CALLER ===

async function call<T = any>(endpoint: string, params: Record<string, any>): Promise<ApiResponse<T>> {
  try {
    const response = await fetch(`${D3BUGR_HOST}/api/tools/${endpoint}`, {
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

// === SUBDOMAIN ENUMERATION ===

export async function subfinder(domain: string): Promise<ApiResponse<string[]>> {
  return await call<string[]>("subfinder_scan", { domain });
}

// === HTTP PROBING ===

export async function httpx(targets: string | string[]): Promise<ApiResponse> {
  const targetStr = Array.isArray(targets) ? targets.join(",") : targets;
  return await call("httpx_probe", { targets: targetStr });
}

// === VULNERABILITY SCANNING ===

export async function nuclei(target: string, severity: string = "critical,high"): Promise<ApiResponse> {
  return await call("nuclei_scan", { target, severity });
}

export async function nucleiQuick(target: string): Promise<ApiResponse> {
  return await call("nuclei_quick", { target });
}

export async function nucleiCves(target: string): Promise<ApiResponse> {
  return await call("nuclei_cves", { target });
}

export async function nucleiTech(target: string): Promise<ApiResponse> {
  return await call("nuclei_tech", { target });
}

export async function nucleiExposures(target: string): Promise<ApiResponse> {
  return await call("nuclei_exposures", { target });
}

export async function nucleiMisconfigs(target: string): Promise<ApiResponse> {
  return await call("nuclei_misconfigs", { target });
}

// === PORT SCANNING ===

export async function nmap(target: string, ports: string = "top-100"): Promise<ApiResponse> {
  return await call("nmap_scan", { target, ports });
}

export async function nmapQuick(target: string): Promise<ApiResponse> {
  return await call("nmap_quick", { target });
}

// === XSS SCANNING ===

export async function dalfox(url: string): Promise<ApiResponse> {
  return await call("dalfox_xss_scan", { url });
}

// === SQL INJECTION ===

export async function sqlmap(url: string, level: number = 1, risk: number = 1): Promise<ApiResponse> {
  return await call("sqlmap_scan", { url, batch: true, level, risk });
}

export async function sqlmapTest(url: string): Promise<ApiResponse> {
  return await call("sqlmap_test", { url });
}

export async function sqlmapStatus(taskId: string): Promise<ApiResponse> {
  return await call("sqlmap_status", { task_id: taskId });
}

export async function sqlmapResult(taskId: string): Promise<ApiResponse> {
  return await call("sqlmap_result", { task_id: taskId });
}

// === DIRECTORY FUZZING ===

export async function ffuf(url: string, wordlist: string = "common"): Promise<ApiResponse> {
  return await call("ffuf_scan", { url, wordlist });
}

export async function feroxbuster(url: string, wordlist: string = "common"): Promise<ApiResponse> {
  return await call("feroxbuster_scan", { url, wordlist });
}

// === WEB CRAWLING ===

export async function katana(url: string, depth: number = 2): Promise<ApiResponse> {
  return await call("katana_crawl", { url, depth });
}

// === WEB APPLICATION SCANNING ===

export async function nikto(url: string): Promise<ApiResponse> {
  return await call("nikto_scan", { url });
}

export async function arjun(url: string): Promise<ApiResponse> {
  return await call("arjun_scan", { url });
}

// === DNS ENUMERATION ===

export async function dnsLookup(domain: string, recordType: string = "A"): Promise<ApiResponse> {
  return await call("dns_lookup", { domain, record_type: recordType });
}

export async function dnsWhois(domain: string): Promise<ApiResponse> {
  return await call("dns_whois", { domain });
}

export async function dnsReverse(ip: string): Promise<ApiResponse> {
  return await call("dns_reverse", { ip });
}

export async function dnsZoneTransfer(domain: string): Promise<ApiResponse> {
  return await call("dns_zone_transfer", { domain });
}

export async function dnsDnssec(domain: string): Promise<ApiResponse> {
  return await call("dns_dnssec", { domain });
}

// === OSINT / HARVESTING ===

export async function harvest(domain: string): Promise<ApiResponse> {
  return await call("harvest", { domain });
}

export async function harvestQuick(domain: string): Promise<ApiResponse> {
  return await call("harvest_quick", { domain });
}

export async function harvestSubdomains(domain: string): Promise<ApiResponse> {
  return await call("harvest_subdomains", { domain });
}

export async function harvestEmails(domain: string): Promise<ApiResponse> {
  return await call("harvest_emails", { domain });
}

// === SHODAN INTEGRATION ===

export async function shodanIp(ip: string): Promise<ApiResponse> {
  return await call("shodan_ip_lookup", { ip });
}

export async function shodanSearch(query: string): Promise<ApiResponse> {
  return await call("shodan_search", { query });
}

export async function shodanCve(cveId: string): Promise<ApiResponse> {
  return await call("shodan_cve_lookup", { cve_id: cveId });
}

export async function shodanDns(domain: string): Promise<ApiResponse> {
  return await call("shodan_dns_lookup", { domain });
}

// === SECRET SCANNING ===

export async function trufflehogGithub(repo: string): Promise<ApiResponse> {
  return await call("trufflehog_github", { repo });
}

export async function trufflehogS3(bucket: string): Promise<ApiResponse> {
  return await call("trufflehog_s3", { bucket });
}

export async function trufflehogDocker(image: string): Promise<ApiResponse> {
  return await call("trufflehog_docker", { image });
}

// === WINRM EXPLOITATION ===

export async function winrmRecon(target: string): Promise<ApiResponse> {
  return await call("winrm_recon", { target });
}

export async function winrmCheck(target: string): Promise<ApiResponse> {
  return await call("winrm_check", { target });
}

export async function winrmExec(target: string, command: string, username?: string, password?: string): Promise<ApiResponse> {
  return await call("winrm_exec", { target, command, username, password });
}

// === BROWSER AUTOMATION (CDP) ===

export async function cdpConnect(url: string): Promise<ApiResponse> {
  return await call("cdp_connect", { url });
}

export async function cdpScreenshot(url: string): Promise<ApiResponse> {
  return await call("cdp_screenshot", { url });
}

export async function cdpExecute(url: string, javascript: string): Promise<ApiResponse> {
  return await call("cdp_execute", { url, javascript });
}

export async function cdpCookies(url: string): Promise<ApiResponse> {
  return await call("cdp_cookies", { url });
}

export async function cdpLocalStorage(url: string): Promise<ApiResponse> {
  return await call("cdp_localstorage", { url });
}

export async function cdpWebrtcLeak(): Promise<ApiResponse> {
  return await call("cdp_webrtc_leak", {});
}

export async function cdpFingerprint(url: string): Promise<ApiResponse> {
  return await call("cdp_fingerprint", { url });
}

// === GEOLOCK TESTING ===

export async function geolockCreate(url: string, allowedCountries: string[]): Promise<ApiResponse> {
  return await call("geolock_create", { url, allowed_countries: allowedCountries });
}

export async function geolockSessions(): Promise<ApiResponse> {
  return await call("geolock_sessions", {});
}

export async function geolockResults(sessionId: string): Promise<ApiResponse> {
  return await call("geolock_results", { session_id: sessionId });
}

// === HEALTH & STATUS ===

export async function health(): Promise<ApiResponse> {
  try {
    const response = await fetch(`${D3BUGR_HOST}/health`);
    return {
      success: response.ok,
      data: {
        status: response.status,
        available: response.ok,
        timestamp: new Date().toISOString()
      }
    };
  } catch (error: any) {
    return {
      success: false,
      error: error.message
    };
  }
}

export async function status(): Promise<ApiResponse> {
  try {
    const response = await fetch(`${D3BUGR_HOST}/health`);
    const data = await response.json();
    return { success: true, data };
  } catch (error: any) {
    return {
      success: false,
      error: error.message
    };
  }
}

export async function listTools(): Promise<ApiResponse<string[]>> {
  try {
    const response = await fetch(`${D3BUGR_HOST}/api/tools`);
    const data = await response.json();
    return { success: true, data };
  } catch (error: any) {
    return {
      success: false,
      error: error.message
    };
  }
}

// === BATCH OPERATIONS ===

/**
 * Run multiple operations in sequence
 */
export async function runBatch(operations: Array<{ fn: () => Promise<ApiResponse> }>): Promise<ApiResponse[]> {
  const results: ApiResponse[] = [];
  for (const op of operations) {
    const result = await op.fn();
    results.push(result);
  }
  return results;
}

/**
 * Run multiple operations in parallel
 */
export async function runParallel(operations: Array<{ fn: () => Promise<ApiResponse> }>): Promise<ApiResponse[]> {
  const promises = operations.map(op => op.fn());
  return await Promise.all(promises);
}

// === RECONNAISSANCE WORKFLOWS ===

/**
 * Full subdomain reconnaissance workflow
 */
export async function fullSubdomainRecon(domain: string): Promise<{
  subdomains: string[];
  liveHosts: any[];
  vulnerabilities: any[];
}> {
  // 1. Enumerate subdomains
  const subResult = await subfinder(domain);
  const subdomains = subResult.success ? subResult.data || [] : [];

  // 2. Probe for live hosts
  const httpxResult = await httpx(subdomains);
  const liveHosts = httpxResult.success ? httpxResult.data || [] : [];

  // 3. Quick vulnerability scan on live hosts
  const vulnerabilities = [];
  for (const host of liveHosts.slice(0, 5)) {
    const vulnResult = await nucleiQuick(host.url || host);
    if (vulnResult.success && vulnResult.data) {
      vulnerabilities.push(...(vulnResult.data.vulnerabilities || []));
    }
  }

  return { subdomains, liveHosts, vulnerabilities };
}

/**
 * Quick web app assessment
 */
export async function quickWebAppScan(url: string): Promise<{
  endpoints: string[];
  vulnerabilities: any[];
  technologies: any[];
}> {
  const results = await runParallel([
    { fn: () => katana(url, 2) },
    { fn: () => nucleiTech(url) },
    { fn: () => nucleiQuick(url) }
  ]);

  return {
    endpoints: results[0].data?.endpoints || [],
    technologies: results[1].data?.technologies || [],
    vulnerabilities: results[2].data?.vulnerabilities || []
  };
}
