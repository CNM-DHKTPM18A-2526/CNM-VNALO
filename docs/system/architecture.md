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
| **message-service** | 8082 | NestJS 11, TypeScript | Conversations, Messages, Inbox, WebSocket gateway |

### Future Services (Planned)

| Service | Port | Technology | Responsibility |
|---------|------|------------|---------------|
| media-service | 8083 | Spring Boot | File upload, Cloudinary, thumbnails |
| realtime-gateway | 8085 | Node.js | WebSocket scaling, presence |
| content-service | 8092 | Spring Boot | Stories, Timeline |
| notification-service | 8087 | Spring Boot | FCM push notifications |

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
│ Port 8081    │  │ Port 8082        │
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
- Client ↔ message-service: `send_message`, `typing_start/stop`, `presence`
- Socket.IO with JWT authentication via handshake

### Shared State
- **JWT Secret**: Same `HS512` key across both services — tokens issued by core-service are validated by message-service
- **Database**: Single PostgreSQL instance, Flyway migrations owned by core-service

---

## Database Strategy

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Primary | PostgreSQL 16 | All persistent data (users, messages, conversations) |
| Cache | Redis 7 | Session store, presence, rate limiting |

Migrations: Flyway (V1–V11), managed in `core-service/src/main/resources/db/migration/`

---

## Infrastructure

### Development
- Docker Compose: PostgreSQL + Redis
- core-service: `mvn spring-boot:run` (port 8081)
- message-service: `npm run start:dev` (port 8082)

### Production (Planned)
- AWS EKS (Kubernetes)
- ALB for REST, NLB for WebSocket
- RDS for PostgreSQL
- ElastiCache for Redis
