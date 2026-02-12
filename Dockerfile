FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Enable Corepack (pnpm)
RUN corepack enable

WORKDIR /app

# Optional apt packages
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Copy manifests first for better layer caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# Install deps
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Build
RUN pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Prepare OpenClaw config dir + permissions (must be BEFORE USER node)
RUN mkdir -p /tmp/.openclaw && \
    chown -R node:node /tmp/.openclaw

# If you want baked-in config file in image:
COPY openclaw.json /tmp/.openclaw/openclaw.json
RUN chown node:node /tmp/.openclaw/openclaw.json

ENV OPENCLAW_CONFIG_PATH=/tmp/.openclaw/openclaw.json

# App directory permission for non-root runtime
RUN chown -R node:node /app

# Security hardening: Run as non-root user
USER node

# Start gateway server (Railway provides $PORT)
CMD ["sh", "-lc", "node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT}"]
