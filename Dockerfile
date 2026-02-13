FROM node:22-bookworm

# ----------------------------
# Tooling: Bun + Corepack (pnpm)
# ----------------------------
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# ----------------------------
# Optional APT packages
# ----------------------------
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# ----------------------------
# Install dependencies (cached layer)
# ----------------------------
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# ----------------------------
# Build
# ----------------------------
COPY . .

RUN pnpm build

ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# ----------------------------
# Runtime config + permissions (do BEFORE switching user)
# ----------------------------
RUN mkdir -p /tmp/.openclaw && chown -R node:node /tmp/.openclaw

COPY openclaw.json /tmp/.openclaw/openclaw.json
RUN chown node:node /tmp/.openclaw/openclaw.json

ENV OPENCLAW_CONFIG_PATH=/tmp/.openclaw/openclaw.json

RUN chown -R node:node /app

# ----------------------------
# Security hardening
# ----------------------------
USER node

# ----------------------------
# Railway start (use Railway-provided PORT)
# ----------------------------
CMD ["sh", "-lc", "node openclaw.mjs gateway --allow-unconfigured --host 0.0.0.0 --port ${PORT:-18789} 2>&1 | tee /tmp/openclaw.log; sleep 30"]
