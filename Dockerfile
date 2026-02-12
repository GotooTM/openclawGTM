FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .

RUN pnpm build

ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# ---- FIX PERMISSION BEFORE USER ----
RUN mkdir -p /tmp/.openclaw && chown -R node:node /tmp/.openclaw
COPY openclaw.json /tmp/.openclaw/openclaw.json
RUN chown node:node /tmp/.openclaw/openclaw.json

ENV OPENCLAW_CONFIG_PATH=/tmp/.openclaw/openclaw.json

# Allow app directory access
RUN chown -R node:node /app

USER node

# ---- Railway Safe Start ----
CMD ["sh", "-lc", "OPENCLAW_HOST=0.0.0.0 node openclaw.mjs gateway --allow-unconfigured --port ${PORT}"]
