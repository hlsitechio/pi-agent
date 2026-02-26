FROM node:22-alpine AS builder

WORKDIR /build

# Copy monorepo root for pi CLI build
COPY package.json package-lock.json tsconfig.base.json tsconfig.json ./
COPY packages/ packages/

# Install deps and build pi CLI
RUN npm ci --ignore-scripts 2>/dev/null || npm install
RUN cd packages/coding-agent && npm run build 2>/dev/null || true

# --- Production stage ---
FROM node:22-alpine

# System deps: zstd required by Ollama installer
RUN apk add --no-cache curl bash tini jq python3 zstd && \
    curl -fsSL https://ollama.com/install.sh | sh

# Install tsx for TypeScript extension loading
RUN npm install -g tsx@4.21.0

# Copy built pi CLI from builder
COPY --from=builder /build /app/pi-mono
RUN ln -sf /app/pi-mono/packages/coding-agent/dist/cli.js /usr/local/bin/pi && \
    chmod +x /usr/local/bin/pi

# Create data dirs
RUN mkdir -p /data/output /data/published /data/cowork /data/state /root/.pi/agent /root/.ollama

# Copy ghost writer worker files
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
