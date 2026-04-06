# System Architecture

> VNALO — Microservices Messaging Platform

---

## Overview

VNALO is a real-time messaging platform built with a polyglot microservices architecture:

- **core-service** (Java/Spring Boot) — Auth, Users, Social features
- **message-service** (Node.js/NestJS) — Messaging, Conversations, Real-time chat

Both services share a single **PostgreSQL** database and communicate via shared JWT secrets.

---

## Service Map

| Service | Port | Technology | Responsibility |
|---------|------|------------|---------------|
| **core-service** | 8081 | Spring Boot 3.4, Java 21 | Auth, User profiles, Friends, Blocks, QR, Contact Sync |
| **message-service** | 3000 (default) | NestJS 11, TypeScript | Conversations, Messages, Inbox, WebSocket gateway |

### Extended Services (Current Repository Scope)

| Service | Port | Technology | Responsibility |
|---------|------|------------|---------------|
| media-service | 8083 | Spring Boot 3.4, Java 21 | Media upload APIs, sticker APIs, S3/local storage mode |
| realtime-gateway | 8085 | NestJS, Node.js 20+ | WebSocket scaling skeleton, Redis adapter, room broadcast |
| moderation-service | 8082 | Spring Boot 3.4, Java 21 | Report intake, moderation workflows, appeal lifecycle |
| content-service | 8086 | Spring Boot (scaffold) | Story, Timeline modules (scaffold) |
| notification-service | 8087 | Spring Boot (scaffold) | FCM push orchestration (scaffold) |
| ai-service | 8094 | Spring Boot 3.4, Java 21 | Gemini + Ollama fallback assistant APIs |
| analytics-service | 8084 *(compose profile)* | Spring Boot *(planned)* | Planned metrics/event analytics service |

---

## High-Level Architecture

```
┌──────────────────┐
│  Flutter Mobile   │
│  (iOS + Android)  │
└────────┬─────────┘
         │
    ┌────┴────────────────────────┐
    │         REST / WebSocket     │
    │                              │
┌───┴──────────┐  ┌───────────────┴──┐
│ core-service │  │ message-service  │
│ (Spring Boot)│  │ (NestJS)         │
│ Port 8081    │  │ Port 3000        │
│              │  │                  │
│ • Auth/JWT   │  │ • Conversations  │
│ • Users      │  │ • Messages       │
│ • Friends    │  │ • WebSocket GW   │
│ • Blocks     │  │ • Inbox (CQRS)   │
│ • QR Code    │  │ • Search         │
│ • Contacts   │  │ • Reactions      │
│ • FCM Push   │  │ • Pins           │
└──────┬───────┘  └───────┬──────────┘
       │                  │
       └────────┬─────────┘
                │
       ┌────────┴────────┐
       │   PostgreSQL     │
       │   (vnalo_core)   │
       │                  │
       │   + Redis        │
       │   (sessions)     │
       └─────────────────┘
```

---

## Communication Patterns

### REST (Synchronous)
- Client → core-service: Auth, profile CRUD, friend requests
- Client → message-service: Conversation CRUD, message history, search

### WebSocket (Real-time)
- Client ↔ message-service: `conversation.join`, `message.send`, `message.typing`, `message.read`, `presence.changed`
- Socket.IO namespace `/chat` with JWT authentication via handshake

### Shared State
- **JWT Secret**: Same `HS512` key across both services — tokens issued by core-service are validated by message-service
- **Database**: Single PostgreSQL instance, Flyway migrations owned by core-service

---

## Database Strategy

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Primary | PostgreSQL 16 | All persistent data (users, messages, conversations) |
| Cache | Redis 7 | Sequence generator (`INCR`), pub/sub support, cache |

Migrations: Flyway (V1–V13), managed in `core-service/src/main/resources/db/migration/`

---

## Infrastructure

### Development
- Docker Compose: PostgreSQL + Redis
- core-service: `mvn spring-boot:run` (port 8081)
- message-service: `npm run start:dev` (default port 3000)

### Container Runtime Profiles
- `docker/docker-compose.infra.yml`: Infrastructure only (PostgreSQL + Redis)
- `docker/docker-compose.yml`: Full development stack (core/message/media/realtime/moderation/content/notification/ai + optional infra profiles)

### Production Direction (Target)
- Container orchestration platform (target architecture)
- Managed PostgreSQL + managed Redis
- Horizontal scaling for message-service/realtime-gateway paths
