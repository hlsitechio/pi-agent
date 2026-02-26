#!/bin/bash
set -e

echo "[*] Starting Ghost Writer Worker..."

# Start Ollama in background (cloud proxy — no GPU, just routing to ollama.com)
echo "[*] Starting Ollama cloud proxy..."
ollama serve &

# Wait for Ollama
for i in $(seq 1 30); do
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "[+] Ollama ready"
    break
  fi
  sleep 1
done

# Pull cloud model configs (tiny routing configs, not actual weights)
echo "[*] Pulling cloud model configs..."
ollama pull glm-4.7:cloud 2>/dev/null || true
ollama pull glm-5:cloud 2>/dev/null || true
ollama pull gpt-oss:120b-cloud 2>/dev/null || true
ollama pull gpt-oss:20b-cloud 2>/dev/null || true
ollama pull deepseek-v3.2:cloud 2>/dev/null || true

# Ensure data directories exist on persistent volume
mkdir -p /data/output /data/published /data/cowork /data/state

# Symlink data dirs into agent paths for compatibility
ln -sf /data/output /app/pi-agents/content/article-writer/output 2>/dev/null || true
ln -sf /data/published /app/pi-agents/content/published 2>/dev/null || true
ln -sf /data/cowork /app/pi-agents/content/cowork 2>/dev/null || true

# Start the HTTP API server (n8n triggers agents via this)
echo "[+] Starting API server on :${PORT:-3000}..."
exec node /app/server.js
