# =============================================================================
# Message Service — Multi-stage Dockerfile
# Base: Node 20 Alpine
# Build: NestJS monorepo with webpack compiler
# Output: dist/apps/message-service/main.js (single webpack bundle)
# Default port: 3000 (override via PORT env var)
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder
WORKDIR /build

# Copy package files first (cache dependencies layer)
COPY package*.json ./
RUN npm ci --ignore-scripts

# Copy source and build
COPY . .
RUN npm run build

# --- Stage 2: Production dependencies ---
FROM node:20-alpine AS deps
WORKDIR /deps
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

# --- Stage 3: Runtime ---
FROM node:20-alpine
WORKDIR /app

# Security: use built-in node user (non-root)
RUN apk add --no-cache wget

# Copy webpack bundle (single file) from builder
COPY --from=builder /build/dist/ ./dist/

# Copy production node_modules (for native modules if any)
COPY --from=deps /deps/node_modules/ ./node_modules/

# Copy package.json (for metadata)
COPY package.json ./

# Health check — NestJS global prefix applies: /api/v1/health
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/api/v1/health || exit 1

EXPOSE 3000

USER node

CMD ["node", "dist/apps/message-service/main"]
