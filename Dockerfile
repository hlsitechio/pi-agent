# v3 — Debian slim for Ollama glibc compatibility
FROM node:22-slim

# System deps: Ollama needs glibc (Alpine's musl breaks it)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash tini jq python3 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://ollama.com/install.sh | sh

# Install pi CLI from npm + tsx for TypeScript extensions
RUN npm install -g @mariozechner/pi-coding-agent@0.55.1 tsx@4.21.0

# Create app structure
RUN mkdir -p /app/pi-agents /data/output /data/published /data/cowork /data/state /root/.pi/agent /root/.ollama

# Copy agent code + configs
COPY ghost-writer/pi-agents/ /app/pi-agents/
COPY ghost-writer/config/models.json /root/.pi/agent/models.json
COPY ghost-writer/config/ollama-config.json /root/.ollama/config.json
COPY ghost-writer/server.js /app/server.js
COPY ghost-writer/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    find /app/pi-agents -name "run.sh" -exec chmod +x {} \;

ENV OLLAMA_HOST=127.0.0.1
ENV NODE_ENV=production
ENV DATA_DIR=/data

EXPOSE 3000

ENTRYPOINT ["tini", "--"]
CMD ["/entrypoint.sh"]
