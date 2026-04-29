# SYSTEM ARCHITECTURE — TARGET STATE

> **Authority:** This document defines the **Target Architecture** for VNALO. Security hardening directives use MUST, SHALL, and REQUIRED per RFC 2119. All production deployments MUST comply. Code that deviates from this specification MUST be treated as a security defect.

> **Version:** 2.0-HARDENED
> **Effective:** 2026-04-29
> **Supersedes:** Previous unhardened architecture.md

---

## 1. SERVICE TOPOLOGY

### 1.1 Service Registry

| Service | Port | Stack | Responsibility | Auth Boundary |
|---|---|---|---|---|
| **core-service** | 8081 | Spring Boot 3.4, Java 21 | Identity, Auth, Social Graph | JWT (HS512) |
| **message-service** | 3000 | NestJS 11, TypeScript | Conversations, Messages, Chat WS | JWT (HS512) |
| **realtime-gateway** | 8085 | NestJS, Node.js 20+ | Presence federation, Kafka→Socket bridge | JWT (HS512) |
| **media-service** | 8083 | Spring Boot 3.4, Java 21 | Media upload, stickers, S3/local | JWT (HS512) |
| **moderation-service** | 8082 | Spring Boot 3.4, Java 21 | Reports, cases, appeals | JWT (HS512) |
| **content-service** | 8086 | Spring Boot (scaffold) | Stories, posts, comments | **JWT REQUIRED — permitAll PROHIBITED** |
| **notification-service** | 8087 | Spring Boot (scaffold) | FCM push, device tokens | **JWT REQUIRED — X-User-Id header PROHIBITED** |
| **ai-service** | 8094 | Spring Boot 3.4, Java 21 | Gemini + Ollama assistant | JWT (HS512) |
| **analytics-service** | 8084 | Spring Boot (planned) | Event ingestion, trend dashboards | JWT (HS512) |

---

## 2. TRUST BOUNDARY MODEL

### 2.1 Hardened Security Perimeter

```
┌─────────────────────────────────────────────────────────────────────┐
│                           CLIENTS                                      │
│            (Flutter Mobile, React Web, API Consumers)                │
│                         JWT Bearer Token                               │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────────┐
│                         NGINX GATEWAY                                 │
│   • TLS termination                                                    │
│   • Path-based routing                                               │
│   • Request size limits (client_max_body_size 100M)                 │
│   • WebSocket upgrade handling                                        │
│   • No application-layer trust — all auth handled by backends       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        ▼                        ▼                        ▼
   Java Services             Node Services           External
   (JWT filter)            (JWT strategy)         Services
   core-service             message-service          Gemini API
   media-service           realtime-gateway          Ollama
   moderation-service                               S3
   content-service         **JWT REQUIRED**         PostgreSQL
   notification-service    **No X-User-Id header** Redis
   ai-service             **No permitAll**         Kafka
   analytics-service
```

### 2.2 Security Boundaries (HARDENED)

```
REQUIRED: Every mutating endpoint across ALL services MUST validate JWT.

PROHIBITED patterns (immediate remediation required):
  ✗ content-service: permitAll on mutating endpoints
  ✗ notification-service: X-User-Id header trust
  ✗ Any service: permitAll with controller-level auth
```

---

## 3. REQUEST ROUTING

### 3.1 Nginx Routing Rules

| Route | Upstream | Context | Notes |
|---|---|---|---|
| `/api/v1/media` | `media-service:8083` | Java `/api/v1/media` | Media list, stickers |
| `/api/v1/upload` | `media-service:8083/api/v1/media/upload` | Alias | Upload endpoint |
| `/api/v1/files` | `media-service:8083/api/v1/media/public` | Alias | Public file access |
| `/api/v1/ai` | `ai-service:8094` | — | AI assistant |
| `/socket.io/` | `realtime-gateway:8085` | WS namespace | WebSocket |
| `/api/v1/(conversations|messages|...)` | `message-service:3000` | — | Chat REST |
| `/api/v1/notifications` | `notification-service:8087` | — | Push notifications |
| `/api/v1/(posts|stories|feeds|comments)` | `content-service:8086` | — | Social content |
| `/api/v1/analytics` | `analytics-service:8084` | — | Analytics |
| `/api/v1/` (catch-all) | `core-service:8081` | — | Auth, Users, Social |
| `/health` | Nginx internal | — | Health check |

**Routing Requirements:**

- **`proxy_pass` directives** MUST use direct hostnames (e.g., `http://media-service:8083`) without Nginx variables for all services where startup-order is guaranteed.
- **`resolver 127.0.0.11`** MUST be configured for Docker internal DNS resolution.
- **Upstream variable usage** (`set $upstream; proxy_pass $upstream`) MAY be used only when graceful startup without upstream resolution is required, with documented trade-off of DNS-per-request overhead.

### 3.2 Media Upload Flow

```
Client                          Nginx                    media-service:8083
  │                                │                             │
  │  POST /api/v1/upload          │                             │
  │  Content-Type: multipart/form │                            │
  │  Authorization: Bearer <JWT>   │                             │
  │──────────────────────────────►│                             │
  │                                │  POST /api/v1/media/upload  │
  │                                │────────────────────────────►│
  │                                │                             │
  │                                │  { url, mimeType, size, thumbnailUrl }
  │                                │◄────────────────────────────│
  │                                │                             │
  │  HTTP 200 { data: { url } }  │                             │
  │◄───────────────────────────────│
```

---

## 4. AUTHENTICATION & AUTHORIZATION

### 4.1 Token Architecture

| Property | Value | Rationale |
|---|---|---|
| Algorithm | HS512 | Shared secret across all services |
| Issuer | `core-service` | Single source of truth |
| Access Token TTL | 15 minutes | Short-lived |
| Refresh Token TTL | 30 days | Long-lived, revocable |
| Required Claims | `sub` (userId), `iat`, `exp` | Identity + timing |
| Optional Claims | `clientPlatform`, `deviceId` | Multi-device support |

**Secret Rotation:** All services MUST share the same JWT secret. Rotation MUST be coordinated atomically across all services via environment variable update and rolling restart.

### 4.2 Authorization Perimeter

```
Every service boundary:
  1. Decode JWT on request receipt
  2. Verify signature (HS512 shared secret)
  3. Verify expiry (exp claim)
  4. Extract userId (sub claim)
  5. Enforce service-level RBAC

Cross-service communication:
  - message-service → media-service: API call with forwarded JWT
  - message-service → core-service: API call with forwarded JWT OR shared secret
  - core-service → message-service: API call with shared secret
```

---

## 5. DATA OWNERSHIP & PERSISTENCE

### 5.1 Service-Owned Domains

| Owner | Database | Schema |
|---|---|---|
| core-service | `vnalo_core` (PostgreSQL) | users, auth, social graph, blocks |
| message-service | `vnalo_core` (PostgreSQL) | conversations, messages, inbox, pins |
| media-service | `vnalo_media` (PostgreSQL) | media metadata, sticker catalogs |
| moderation-service | `vnalo_core` (PostgreSQL) | reports, cases, appeals |
| notification-service | `vnalo_core` (PostgreSQL) | device tokens, notification feed |
| analytics-service | `vnalo_analytics` (PostgreSQL) | event log, aggregates |

### 5.2 Cache Topology

| Cache | Technology | Purpose |
|---|---|---|
| Sequence Generator | Redis INCR | Monotonic serverSeq per conversation |
| Session Store | Redis | WebSocket presence, userSockets map |
| Block List | Redis | Per-user block set (TTL 1h, invalidated on change) |
| Contact Graph | Redis | Mutual contacts for presence scoping |
| API Response | Redis | Short-lived cache for analytics queries |

---

## 6. COMMUNICATION PATTERNS

### 6.1 Synchronous REST

All client-to-service communication uses REST over HTTPS through Nginx.

### 6.2 Real-Time WebSocket

```
Namespace: /chat
Transport: websocket (primary), polling (fallback)
Auth: JWT in Socket.IO handshake auth.token
Port: message-service :3000 → proxied via Nginx /socket.io/
```

**Gateway Responsibilities:**
- Maintain `userSockets: Map<userId, Set<socketId>>` for multi-device delivery
- Maintain `conversation:{id}` Socket.IO rooms for broadcast
- Enforce SG-1 membership check on every event (see MODULE_SPEC_CHAT)
- Emit errors with structured `code` field (see MODULE_SPEC_CHAT)

### 6.3 Event-Driven (Kafka)

```
Topic: vnalo.realtime.events
  → Published by: core-service (friendship, block events)
  → Consumed by: realtime-gateway → Socket.IO emission

Topic: vnalo.media.events
  → Published by: message-service (GROUP_DISBANDED_MEDIA_CLEANUP)
  → Consumed by: media-service (S3 cleanup)

Topic: vnalo.moderation.events
  → Published by: message-service (REPORT_CREATED)
  → Consumed by: moderation-service (case creation)
```

---

## 7. INFRASTRUCTURE

### 7.1 Development

```
docker/docker-compose.yml (full stack)
docker/docker-compose.infra.yml (PostgreSQL + Redis only)
```

### 7.2 Production Target

```
• Container orchestration (ECS/EKS target)
• Managed PostgreSQL (AWS RDS or Cloud SQL)
• Managed Redis (AWS ElastiCache)
• S3-compatible object storage for media
• Nginx in Docker with health checks
• Horizontal scaling for message-service and realtime-gateway
• Kafka (MSK or self-hosted)
```

---

## 8. MEDIA CATEGORY SYSTEM

### 8.1 Java Enum (Authoritative Source)

```java
public enum MediaCategory {
    AVATAR,          // User profile pictures
    COVER,           // Group cover images
    CHAT_IMAGE,      // Images sent in chat
    CHAT_VIDEO,      // Videos sent in chat
    CHAT_FILE,       // Documents and other files
    CHAT_VOICE,      // Voice messages
    STORY,           // Story/timeline uploads
    TIMELINE,        // Timeline post media
    STICKER,         // Chat stickers
    EMOJI,           // Animated emoji/GIF
    GIF              // Standalone GIF files
}
```

### 8.2 Frontend Mapping

| MIME Type | Category Sent | Notes |
|---|---|---|
| `image/*` | `CHAT_IMAGE` | — |
| `video/*` | `CHAT_VIDEO` | — |
| Default | `CHAT_FILE` | Documents, archives |
| Avatar upload | `AVATAR` | Profile picture |
| Group avatar | `COVER` | Group cover |
| Sticker upload | `STICKER` | — |

---

## 9. ERROR RESILIENCE

### 9.1 Circuit Breaker

All inter-service HTTP calls MUST implement circuit breaker pattern:

```
Open: After 5 consecutive failures (5xx or timeout)
  → Return cached response or graceful degradation
  → Log alert
Half-open: After 30s
  → Allow one probe request
Closed: On probe success
  → Resume normal operation
```

### 9.2 Retry Policy

```
Non-idempotent: NO automatic retry
Idempotent (GET, DELETE): Retry up to 3 times with exponential backoff (1s, 2s, 4s)
Upload media: Chunked upload with resume capability (target)
```

### 9.3 Dead Letter Queue

```
Kafka consumer errors → DLQ topic (vnalo.dlq.{topic})
DLQ consumer → alerting → manual review
Maximum retention in DLQ: 7 days
```

---

## 10. OBSERVABILITY

### 10.1 Logging Standards

```
Every request: traceId, userId, service, endpoint, duration, statusCode
Every WebSocket event: traceId, socketId, eventName, userId, conversationId
Every DB transaction: traceId, operation, duration, rowCount
Every Kafka publish: traceId, topic, eventType
```

### 10.2 SLI Targets

| Metric | Target | Alert Threshold |
|---|---|---|
| API P99 latency (auth) | < 200ms | > 500ms |
| API P99 latency (message send) | < 300ms | > 800ms |
| WebSocket message delivery | < 100ms (local) | > 500ms |
| Media upload (image) | < 3s | > 10s |
| Service availability | 99.9% | < 99.5% |

---

## 11. COMPLIANCE CHECKLIST

```
SECURITY
  [ ] All services validate JWT on every request
  [ ] No permitAll on mutating endpoints
  [ ] No X-User-Id header trust for identity
  [ ] JWT secret rotation mechanism in place
  [ ] Input validation on all user-controlled fields
  [ ] Rate limiting on auth endpoints (OTP, login)

INTEGRITY
  [ ] All group mutations wrapped in DB transactions
  [ ] serverSeq monotonicity via Redis INCR
  [ ] Block filtering on all message queries
  [ ] Exactly-one-ADMIN invariant enforced

PERFORMANCE
  [ ] Room-based WS emission (no per-user loops)
  [ ] Presence scoped to mutual contacts
  [ ] Circuit breakers on all inter-service calls
  [ ] No N+1 queries in hot paths

RELIABILITY
  [ ] DLQ for Kafka consumers
  [ ] Circuit breakers on external API calls
  [ ] Health check endpoints on all services
  [ ] Graceful shutdown with connection draining
```
