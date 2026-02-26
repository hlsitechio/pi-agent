const http = require('http');
const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const AGENTS_DIR = '/app/pi-agents/content';
const DATA_DIR = process.env.DATA_DIR || '/data';
const API_KEY = process.env.WORKER_API_KEY || '';

// Agent configs
const AGENTS = {
  'trend-scanner':    { model: 'glm-4.7:cloud', timeout: 180 },
  'article-writer':   { model: 'glm-4.7:cloud', timeout: 180 },
  'article-editor':   { model: 'glm-4.7:cloud', timeout: 180 },
  'article-reviewer': { model: 'gpt-oss:120b-cloud', timeout: 300 },
  'seo-optimizer':    { model: 'glm-4.7:cloud', timeout: 120 },
  'content-publisher':{ model: 'glm-4.7:cloud', timeout: 120 },
};

// Running agents tracker
const running = {};

function authenticate(req) {
  if (!API_KEY) return true;
  const auth = req.headers['authorization'] || '';
  return auth === `Bearer ${API_KEY}`;
}

function parseBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try { resolve(JSON.parse(body)); }
      catch { resolve({}); }
    });
  });
}

async function runAgent(agentName) {
  const config = AGENTS[agentName];
  if (!config) throw new Error(`Unknown agent: ${agentName}`);
  if (running[agentName]) throw new Error(`Agent ${agentName} already running`);

  const agentDir = path.join(AGENTS_DIR, agentName);
  const extension = path.join(agentDir, 'extension.ts');
  const runScript = path.join(agentDir, 'run.sh');

  if (!fs.existsSync(runScript)) throw new Error(`No run.sh for ${agentName}`);

  running[agentName] = true;
  const startTime = Date.now();

  return new Promise((resolve, reject) => {
    const proc = spawn('bash', [runScript], {
      cwd: agentDir,
      env: {
        ...process.env,
        AGENT_HOME: agentDir,
        HOME: '/root',
        PATH: `/usr/local/bin:/usr/bin:/bin:/root/bin:${process.env.PATH}`,
      },
      timeout: (config.timeout + 30) * 1000,
    });

    let stdout = '';
    let stderr = '';
    proc.stdout.on('data', d => stdout += d);
    proc.stderr.on('data', d => stderr += d);

    proc.on('close', (code) => {
      delete running[agentName];
      const duration = ((Date.now() - startTime) / 1000).toFixed(1);
      resolve({
        agent: agentName,
        exitCode: code,
        duration: `${duration}s`,
        stdout: stdout.slice(-2000),
        stderr: stderr.slice(-1000),
      });
    });

    proc.on('error', (err) => {
      delete running[agentName];
      reject(err);
    });
  });
}

function getStatus() {
  const topicsQueue = path.join(AGENTS_DIR, 'topics-queue.json');
  const publishedTracker = path.join(AGENTS_DIR, 'published-tracker.json');
  const outputDir = path.join(DATA_DIR, 'output');

  let topics = { topics: [] };
  let tracker = {};
  let articles = [];

  try { topics = JSON.parse(fs.readFileSync(topicsQueue, 'utf8')); } catch {}
  try { tracker = JSON.parse(fs.readFileSync(publishedTracker, 'utf8')); } catch {}
  try { articles = fs.readdirSync(outputDir).filter(f => f.endsWith('.md')); } catch {}

  return {
    running: Object.keys(running),
    topics: {
      total: topics.topics?.length || 0,
      pending: topics.topics?.filter(t => t.status === 'pending').length || 0,
      drafted: topics.topics?.filter(t => t.status === 'drafted').length || 0,
    },
    articles: {
      inProgress: articles.length,
      files: articles,
    },
    published: {
      total: tracker.total_published || 0,
      lastRun: tracker.last_publish_run || null,
    },
    availableAgents: Object.keys(AGENTS),
    timestamp: new Date().toISOString(),
  };
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');

  if (!authenticate(req)) {
    res.writeHead(401);
    return res.end(JSON.stringify({ error: 'Unauthorized' }));
  }

  // GET /health
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200);
    return res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
  }

  // GET /status
  if (req.method === 'GET' && req.url === '/status') {
    res.writeHead(200);
    return res.end(JSON.stringify(getStatus()));
  }

  // POST /run/:agent
  const runMatch = req.url.match(/^\/run\/([a-z-]+)$/);
  if (req.method === 'POST' && runMatch) {
    const agentName = runMatch[1];
    try {
      // Return immediately with 202, run agent in background
      res.writeHead(202);
      res.end(JSON.stringify({ status: 'started', agent: agentName }));

      const result = await runAgent(agentName);
      // Store result for polling
      const resultFile = path.join(DATA_DIR, 'state', `${agentName}-last-run.json`);
      fs.mkdirSync(path.dirname(resultFile), { recursive: true });
      fs.writeFileSync(resultFile, JSON.stringify(result, null, 2));
    } catch (err) {
      if (!res.headersSent) {
        res.writeHead(409);
        res.end(JSON.stringify({ error: err.message }));
      }
    }
    return;
  }

  // GET /result/:agent
  const resultMatch = req.url.match(/^\/result\/([a-z-]+)$/);
  if (req.method === 'GET' && resultMatch) {
    const agentName = resultMatch[1];
    const resultFile = path.join(DATA_DIR, 'state', `${agentName}-last-run.json`);
    try {
      const result = JSON.parse(fs.readFileSync(resultFile, 'utf8'));
      res.writeHead(200);
      return res.end(JSON.stringify(result));
    } catch {
      res.writeHead(404);
      return res.end(JSON.stringify({ error: 'No results yet' }));
    }
  }

  // POST /pipeline — run full pipeline sequentially
  if (req.method === 'POST' && req.url === '/pipeline') {
    res.writeHead(202);
    res.end(JSON.stringify({ status: 'pipeline-started' }));

    const pipeline = [
      'trend-scanner',
      'article-writer',
      'article-editor',
      'article-reviewer',
      'seo-optimizer',
      'content-publisher',
    ];

    const results = [];
    for (const agent of pipeline) {
      try {
        const result = await runAgent(agent);
        results.push(result);
        // If agent failed, stop pipeline
        if (result.exitCode !== 0) {
          console.error(`[!] Pipeline stopped: ${agent} failed (exit ${result.exitCode})`);
          break;
        }
      } catch (err) {
        results.push({ agent, error: err.message });
        break;
      }
    }

    const resultFile = path.join(DATA_DIR, 'state', 'pipeline-last-run.json');
    fs.writeFileSync(resultFile, JSON.stringify({ results, completedAt: new Date().toISOString() }, null, 2));
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[+] Ghost Writer Worker API listening on :${PORT}`);
  console.log(`[i] Agents: ${Object.keys(AGENTS).join(', ')}`);
  console.log(`[i] Data dir: ${DATA_DIR}`);
});
