# =============================================================================
# Realtime Gateway Service — Multi-stage Dockerfile
# Base: Node 20 Alpine
# Build: NestJS monorepo compiler
# Output: dist/apps/realtime-gateway/main.js
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder
WORKDIR /build

# Copy package files
COPY package*.json ./
RUN npm install --include=dev --legacy-peer-deps --ignore-scripts

# Copy shared configs and source
COPY nest-cli.json ./
COPY tsconfig*.json ./
COPY apps/ ./apps/

# Build specifically for realtime-gateway
RUN npm run build realtime-gateway

# --- Stage 2: Production dependencies ---
FROM node:20-alpine AS deps
WORKDIR /deps
COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps --ignore-scripts

# --- Stage 3: Runtime ---
FROM node:20-alpine
WORKDIR /app

# Install wget for health check
RUN apk add --no-cache wget

# Copy bundle and dependencies
COPY --from=builder /build/dist/ ./dist/
COPY --from=deps /deps/node_modules/ ./node_modules/
COPY package.json ./

# Health check — Custom port 8085
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8085/health || exit 1

EXPOSE 8085

USER node

CMD ["node", "dist/apps/realtime-gateway/main"]
