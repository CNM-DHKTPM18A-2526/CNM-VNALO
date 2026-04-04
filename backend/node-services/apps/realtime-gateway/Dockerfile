# =============================================================================
# Realtime Gateway Service — Multi-stage Dockerfile
# Base: Node 20 Alpine
# Build: NestJS monorepo compiler
# Port: 8085
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder
WORKDIR /build

# Copy package files first (cache dependencies layer)
COPY package*.json ./
RUN npm install --legacy-peer-deps --ignore-scripts

# Copy shared configs and source
COPY nest-cli.json ./
COPY tsconfig*.json ./
# Phải copy toàn bộ codebase hoặc ít nhất apps để build đúng tsconfig path
COPY apps ./apps

RUN npm run build:realtime

# --- Stage 2: Production dependencies ---
FROM node:20-alpine AS deps
WORKDIR /deps
COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps --ignore-scripts

# --- Stage 3: Runtime ---
FROM node:20-alpine
WORKDIR /app

# Security: use built-in node user (non-root)
RUN apk add --no-cache wget

# Copy bundle from builder
COPY --from=builder /build/dist/ ./dist/

# Copy production node_modules
COPY --from=deps /deps/node_modules/ ./node_modules/
COPY package.json ./

EXPOSE 8085
USER node

CMD ["node", "dist/apps/realtime-gateway/main"]
