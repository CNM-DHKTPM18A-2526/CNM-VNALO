# =============================================================================
# Message Service — Multi-stage Dockerfile
# Base: Node 20 Alpine
# Build: NestJS monorepo with webpack compiler
# Output: dist/apps/message-service/main.js
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder
WORKDIR /build

# Copy package files first
COPY package*.json ./
RUN npm install --legacy-peer-deps --ignore-scripts

# Copy source and build
COPY . .
RUN npm run build

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

# Health check — NestJS health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/api/v1/health || exit 1

EXPOSE 3000

USER node

CMD ["node", "dist/apps/message-service/main"]
