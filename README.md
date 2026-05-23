<div align="center">

<img src="frontend/mobile/assets/icons/app_icon.png" alt="VNALO Logo" width="120" />

# VNALO

### Enterprise-Grade Real-Time Messaging Platform

*Polyglot microservices · Flutter mobile · React web · AI assistant · WebRTC calls*

<p align="center">
  <a href="https://github.com/CNM-DHKTPM18A-2526/CNM-VNALO">
    <img src="https://img.shields.io/badge/version-1.0.0--SNAPSHOT-blue.svg?style=for-the-badge" alt="Version">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge" alt="License">
  </a>
  <a href="https://openjdk.org/">
    <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java">
  </a>
  <a href="https://spring.io/projects/spring-boot">
    <img src="https://img.shields.io/badge/Spring_Boot-3.4.2-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white" alt="Spring Boot">
  </a>
</p>

<p align="center">
  <a href="https://nodejs.org/">
    <img src="https://img.shields.io/badge/Node.js-20+-339933?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js">
  </a>
  <a href="https://nestjs.com/">
    <img src="https://img.shields.io/badge/NestJS-11-E0234E?style=for-the-badge&logo=nestjs&logoColor=white" alt="NestJS">
  </a>
  <a href="https://www.postgresql.org/">
    <img src="https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  </a>
  <a href="https://redis.io/">
    <img src="https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis">
  </a>
</p>

<p align="center">
  <a href="https://flutter.dev/">
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  </a>
  <a href="https://react.dev/">
    <img src="https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React">
  </a>
  <a href="https://www.docker.com/">
    <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  </a>
</p>

<p align="center">
  <strong><a href="README.md">English</a></strong> •
  <strong><a href="README.vi.md">Tiếng Việt</a></strong>
</p>

<p align="center">
  <a href="docs/">📖 Documentation</a> •
  <a href="#-quick-start">🚀 Quick Start</a> •
  <a href="#️-architecture">🏗️ Architecture</a> •
  <a href="#-team">👥 Team</a> •
  <a href="#-contributing">🤝 Contributing</a>
</p>

---

### 🎯 Core Features

<table>
<tr>
<td align="center">🔐<br/><strong>Auth & Security</strong><br/>Phone + Email · JWT HS512 · OTP · QR Login</td>
<td align="center">💬<br/><strong>Real-time Chat</strong><br/>Socket.IO · Inbox CQRS · Reactions · Pins</td>
<td align="center">📞<br/><strong>WebRTC Calls</strong><br/>Voice · Video · Group Calls</td>
</tr>
<tr>
<td align="center">📱<br/><strong>Flutter Mobile</strong><br/>iOS · Android · Dark/Light Theme</td>
<td align="center">🌐<br/><strong>React Web</strong><br/>Vite · TailwindCSS · QR Login · AI Chat</td>
<td align="center">🤖<br/><strong>AI Assistant</strong><br/>Gemini 2.5 Flash + Ollama Fallback</td>
</tr>
<tr>
<td align="center">🎥<br/><strong>Media Service</strong><br/>S3 · Local Fallback · Sticker Packs · Thumbnails</td>
<td align="center">🔔<br/><strong>Push Notifications</strong><br/>FCM · Background Messages</td>
<td align="center">⚡<br/><strong>Realtime Gateway</strong><br/>Redis Adapter · Presence · RabbitMQ Bridge</td>
</tr>
</table>

</div>

---

## 📋 Table of Contents

- [✨ Highlights](#-highlights)
- [🛠️ Tech Stack](#️-tech-stack)
- [🏗️ Architecture](#️-architecture)
- [🚀 Quick Start](#-quick-start)
- [📁 Project Structure](#-project-structure)
- [🔧 Development](#-development)
- [🗄️ Database Migrations](#️-database-migrations)
- [📖 Documentation](#-documentation)
- [✅ Current Status](#-current-status)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## ✨ Highlights

<div align="center">

| 🎨 Modern UI/UX | ⚡ High Performance | 🔒 Secure | 📈 Scalable |
|:---:|:---:|:---:|:---:|
| Flutter + React dual frontend | Socket.IO WebSocket | Firebase + JWT HS512 | Polyglot Microservices |
| Material Design + Dark Mode | Cursor-based Pagination | OTP via Email | Docker Compose ready |
| WebRTC Voice & Video | Redis INCR serverSeq | QR Login Sessions | Kafka + RabbitMQ |
| AI Floating Bubble | Sub-second Delivery | Session Audit Trail | Nginx TLS reverse proxy |

</div>

### 🌟 What Makes VNALO Different

- **🤖 Integrated AI Assistant** — Gemini 2.5 Flash with Ollama fallback, rate limiting, persistent history (Redis + PostgreSQL)
- **📞 WebRTC Calls** — Voice, video, and group calls on both mobile (flutter_webrtc) and web (WebRTC API)
- **🖥️ Dual Frontend** — Flutter mobile app (iOS/Android) + React 19 web app (Vite + TailwindCSS), both fully functional
- **🔐 QR Login** — Scan QR code from mobile to authenticate on web (`auth_qr_login_session` table)
- **🔧 Polyglot Backend** — Spring Boot (Java 21) for core/media/ai + NestJS (TypeScript) for messaging/realtime
- **🏗️ Schema-controlled** — Flyway V1→V26 as single source of truth, TypeORM `synchronize: false`
- **🛡️ Production-hardened** — Nginx TLS, CORS explicit allow-lists, JWT on every endpoint, session audit

---

## 🛠️ Tech Stack

<div align="center">

### Backend

<p>
<img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white">
<img src="https://img.shields.io/badge/Spring_Boot-3.4.2-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white">
<img src="https://img.shields.io/badge/Node.js-20+-339933?style=for-the-badge&logo=node.js&logoColor=white">
<img src="https://img.shields.io/badge/NestJS-11-E0234E?style=for-the-badge&logo=nestjs&logoColor=white">
</p>

### Data Layer

<p>
<img src="https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white">
<img src="https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white">
<img src="https://img.shields.io/badge/RabbitMQ-4-FF6600?style=for-the-badge&logo=rabbitmq&logoColor=white">
<img src="https://img.shields.io/badge/Kafka-7.5-231F20?style=for-the-badge&logo=apache-kafka&logoColor=white">
</p>

### Frontend

<p>
<img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white">
<img src="https://img.shields.io/badge/Dart-3.7+-0175C2?style=for-the-badge&logo=dart&logoColor=white">
<img src="https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black">
<img src="https://img.shields.io/badge/TypeScript-5.9-3178C6?style=for-the-badge&logo=typescript&logoColor=white">
<img src="https://img.shields.io/badge/Vite-8-646CFF?style=for-the-badge&logo=vite&logoColor=white">
<img src="https://img.shields.io/badge/TailwindCSS-3.4-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white">
</p>

### Infrastructure & DevOps

<p>
<img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white">
<img src="https://img.shields.io/badge/Nginx-TLS-009639?style=for-the-badge&logo=nginx&logoColor=white">
<img src="https://img.shields.io/badge/Firebase-FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black">
<img src="https://img.shields.io/badge/AWS_S3-Media-FF9900?style=for-the-badge&logo=amazon-s3&logoColor=white">
</p>

</div>

<details>
<summary><b>📦 Complete Technology Stack</b></summary>

#### Backend — core-service (Java/Spring Boot)
- **Framework**: Spring Boot 3.4.2 (Java 21) with Virtual Threads support
- **Security**: Spring Security 6 + Firebase Admin SDK 9.7.0 + jjwt 0.12.6 (HS512)
- **Database**: Spring Data JPA + Flyway (V1–V26, owner of all schema migrations)
- **Auth**: Phone + Email login, JWT access (15min) + refresh tokens (30 days), OTP via email, QR Login sessions
- **APIs**: Auth, Users, Friends, Blocks, Contacts (phone book sync), QR, FCM push, Session Audit, AI Mascot settings
- **Extras**: Kafka producer (friendship/block events), Redis cache, Springdoc OpenAPI/Swagger

#### Backend — message-service (TypeScript/NestJS)
- **Framework**: NestJS 11 (Node.js 20+)
- **ORM**: TypeORM — `synchronize: false`, schema managed by Flyway in core-service
- **WebSocket**: Socket.IO via `@nestjs/platform-socket.io` with **Redis IO adapter** for horizontal scaling
- **Auth**: Passport JWT strategy (shared HS512 secret with core-service)
- **Modules**: Conversation, Message, Inbox (CQRS), Gateway (Socket.IO), Kafka producer (notification events)
- **Entities**: `conversation`, `conversation_member`, `conversation_direct_map`, `conversation_inbox`, `conversation_join_request`, `message`, `message_reaction`, `message_receipt`, `pinned_message` (9 TypeORM entities)

#### Backend — realtime-gateway (TypeScript/NestJS)
- **Framework**: NestJS (Node.js 20+), port 8085
- **Transport**: Socket.IO, namespace `/realtime`, WebSocket-only (no polling)
- **Scaling**: Redis IO adapter — supports N parallel gateway instances
- **Features**: Presence tracking, typing indicators, heartbeat, RabbitMQ consumer for message broadcast
- **Integration**: Receives events from message-service via RabbitMQ `vnalo.realtime` exchange

#### Backend — media-service (Java/Spring Boot)
- **Framework**: Spring Boot 3.4.2 (Java 21), port 8083
- **Storage**: AWS S3 (primary) + local fallback (`.media-local/`)
- **Features**: Upload, presigned upload (large files), thumbnails (async via RabbitMQ), access control
- **Stickers**: Full sticker pack CRUD — 29 APIs (15 media + 14 sticker)
- **Categories**: AVATAR, COVER, CHAT_IMAGE, CHAT_VIDEO, CHAT_FILE, CHAT_VOICE, STORY, TIMELINE, STICKER, EMOJI, GIF
- **Database**: Separate `vnalo_media` PostgreSQL database

#### Backend — ai-service (Java/Spring Boot)
- **Framework**: Spring Boot 3.4.2 (Java 21), port 8094
- **AI Engine**: Google Gemini 2.5 Flash (primary) → Ollama llama3.1:8b (fallback)
- **Storage**: Redis (session cache + rate limiting) + PostgreSQL (persistent history via V25–V26 migrations)
- **Rate Limiting**: 5 req/min per user, 10 req/min global
- **Features**: Chat ask/history/delete, AI mascot settings (CRUD), internal API for core-service integration
- **Knowledge Scope**: VNALO platform-specific; rejects off-topic queries

#### Backend — moderation-service (Java/Spring Boot)
- **Framework**: Spring Boot 3.4.x (Java 21), port 8082
- **Features**: Report intake, case assignment/resolution, moderation actions, appeal lifecycle, audit log
- **Roles**: MODERATOR, ADMIN (runtime guard via `moderation_admin_user` table)
- **Migrations**: V1 (init schema), V2 (appeal table) — separate Flyway history table

#### Backend — notification-service (Java/Spring Boot)
- **Framework**: Spring Boot (Java 21), port 8087
- **Transport**: Kafka consumer (topic from message-service) + FCM push via Firebase Admin SDK
- **Database**: Separate `vnalo_notification` PostgreSQL database

#### Frontend — Flutter Mobile
- **SDK**: Flutter 3.x / Dart 3.7+ (`sdk: ^3.7.2`)
- **State**: Provider + flutter_riverpod 3.3.1
- **Local DB**: Drift (SQLite) for offline-first storage
- **Features**: Auth (phone+email+OTP), Chat (reactions, pins, recall, voice messages, stickers), WebRTC calls (voice/video/group), AI assistant (floating bubble), Contacts, Notifications (FCM), Timeline, Discover, Profile
- **Config**: `--dart-define` for all service URLs (CORE, MESSAGE, MEDIA, SOCKET, AI)

#### Frontend — React Web
- **Stack**: React 19 + TypeScript 5.9 + Vite 8 + TailwindCSS 3.4
- **State**: React Context + custom hooks
- **WebSocket**: socket.io-client 4.8.x
- **Features**: Auth (phone/email login, QR login, forgot password), Chat (real-time, file sharing, stickers), WebRTC calls (1-1 + group), Contacts, Profile, AI Chat page
- **Deployment**: Docker + Nginx (served at port 80/443)

#### Infrastructure
- **Databases**: PostgreSQL 16 (vnalo_core, vnalo_media, vnalo_notification, vnalo_analytics)
- **Cache/Queue**: Redis 7 (sessions, presence, serverSeq INCR, block cache)
- **Messaging**: RabbitMQ 4 (media thumbnails, realtime broadcast), Kafka/Zookeeper (event streaming)
- **Gateway**: Nginx (TLS termination, path-based routing, WebSocket proxy), domain: `vnalo.fit`
- **AI**: Ollama (optional, profile `ai-local`) for local LLM fallback

</details>

---

## 🏗️ Architecture

<div align="center">

### High-Level System Design

```
┌─────────────────────────────────────────┐
│            CLIENT LAYER                  │
│  Flutter Mobile (iOS/Android)            │
│  React Web (vnalo.fit)                   │
└────────────────┬────────────────────────┘
                 │ HTTPS / WSS
┌────────────────▼────────────────────────┐
│         NGINX (TLS termination)          │
│  vnalo.fit  ·  Path-based routing        │
│  /api/v1/*  ·  /socket.io/              │
└──┬───────┬────────┬────────┬────────────┘
   │       │        │        │
┌──▼──┐ ┌──▼──┐ ┌──▼──┐ ┌──▼────────┐
│core │ │ msg │ │media│ │realtime   │
│8081 │ │3000 │ │8083 │ │gateway    │
│Java │ │Nest │ │Java │ │8085 Nest  │
└──┬──┘ └──┬──┘ └──┬──┘ └──┬────────┘
   │       │        │        │
   └───────┴────────┴───────┘
           │ Shared JWT Secret (HS512)
   ┌───────▼────────────────┐
   │    PostgreSQL 16        │
   │    vnalo_core (main)    │
   │    vnalo_media          │
   │    vnalo_notification   │
   ├────────────────────────┤
   │    Redis 7              │
   │  sessions·presence·seq │
   ├────────────────────────┤
   │  RabbitMQ 4             │
   │  media·realtime events │
   ├────────────────────────┤
   │  Kafka + Zookeeper      │
   │  friendship·moderation │
   └────────────────────────┘
```

</div>

### 🎯 Service Registry

| Service | Port | Technology | Responsibility | Status |
|---------|:----:|-----------|----------------|--------|
| 🔐 **core-service** | 8081 | Spring Boot 3.4.2 (Java 21) | Auth (phone+email+OTP+QR), Users, Friends, Blocks, Contacts, FCM, AI Mascot | ✅ Complete |
| 💬 **message-service** | 3000 | NestJS 11 (TypeScript) | Conversations, Messages, WebSocket gateway, Inbox CQRS, Reactions, Pins | ✅ Complete |
| 🖼️ **media-service** | 8083 | Spring Boot 3.4.2 (Java 21) | File upload (S3+local), Thumbnails, Sticker packs (29 APIs) | 🔄 In Progress |
| ⚡ **realtime-gateway** | 8085 | NestJS (Node.js 20+) | Presence federation, Typing indicators, RabbitMQ→Socket.IO bridge | 🔄 In Progress |
| 🤖 **ai-service** | 8094 | Spring Boot 3.4.2 (Java 21) | Gemini 2.5 Flash chatbot + Ollama fallback, rate limiting, persistent history | 🔄 Active |
| 🔔 **notification-service** | 8087 | Spring Boot (Java 21) | Kafka consumer → FCM push notifications | 🔄 Active |
| 🛡️ **moderation-service** | 8082 | Spring Boot 3.4.x (Java 21) | Reports, Cases, Appeals, Audit log | 🔄 In Progress |
| 📝 **content-service** | 8086 | Spring Boot (scaffold) | Stories, Posts, Comments, Timeline | 🧪 Scaffolded |
| 📊 **analytics-service** | 8084 | Spring Boot (planned) | Event ingestion, dashboards | ⏳ Planned |
| 🌐 **frontend-web** | 80/443 | React 19 + Nginx | Web client (served by Docker/Nginx) | ✅ Active |

### 🔄 Message Flow

```
Client A ──POST /api/v1/messages──► message-service (3000)
                                         │ save to PostgreSQL
                                         │ publish → RabbitMQ (vnalo.realtime)
                                         ▼
                                   realtime-gateway (8085)
                                         │ broadcast to room conversation:{id}
                                         ▼
Client B ◄──── event: message.received ──── Socket.IO /realtime namespace
```

**Key Design Decisions:**
- 📊 **`serverSeq` per conversation** — Redis `INCR` for monotonic message ordering, no timestamp collisions
- 🔄 **Cursor-based pagination** — efficient history with `before` + `limit`
- 👥 **CQRS Inbox** — denormalized `conversation_inbox` table for O(1) unread counts
- 🔐 **Idempotency** — `clientMessageId` for deduplication at persistence layer
- 🏷️ **Group roles** — 3-tier: `ADMIN` (leader) / `DEPUTY` (sub-leader) / `MEMBER` (V23 migration)
- 🔑 **QR Login** — stateless QR token with `auth_qr_login_session` table, mobile approves web login

### 🌐 Nginx Routing (vnalo.fit)

| Route Pattern | Upstream | Notes |
|---|---|---|
| `/socket.io/` | `realtime-gateway:8085` | WebSocket, buffering disabled |
| `/api/v1/media` | `media-service:8083` | File upload/download |
| `/api/v1/upload` | `media-service:8083/api/v1/media/upload` | Alias |
| `/api/v1/ai/mascot` | `core-service:8081` | AI mascot settings |
| `/api/v1/ai` | `ai-service:8094` | AI chatbot (120s timeout) |
| `/api/v1/(conversations\|messages\|...)` | `message-service:3000` | Chat REST |
| `/api/v1/notifications` | `notification-service:8087` | Push notifications |
| `/api/v1/(posts\|stories\|feeds\|comments)` | `content-service:8086` | Social content |
| `/api/v1/` (catch-all) | `core-service:8081` | Auth, Users, Social |
| `/` | Static files | React web app |

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required
☑️  Java 21+ (JDK)
☑️  Node.js 20+
☑️  Docker & Docker Compose
☑️  Git

# Optional — mobile development
📱  Flutter SDK 3.x (Dart 3.7+)
📱  Android Studio (Android)
🍎  Xcode (iOS — macOS only)

# Optional — web development
🌐  Node.js 20+ (already required above)
```

### ⚡ Option 1 — Full Stack with Docker

```bash
# 1. Clone
git clone https://github.com/CNM-DHKTPM18A-2526/CNM-VNALO.git
cd CNM-VNALO

# 2. Configure secrets
cp docker/.env.example docker/.env
# Edit docker/.env — set JWT_SECRET (required), optionally AWS keys & GEMINI_API_KEY

# 3. Add Firebase credentials (for core-service FCM)
# Place: backend/java-services/services/core-service/src/main/resources/
# File:  iuh-cnm-vnalo-firebase-adminsdk-fbsvc-5008b7c5eb.json

# 4. Start infrastructure + core services
cd docker
docker compose up -d postgres redis rabbitmq kafka zookeeper
docker compose up -d core-service message-service media-service realtime-gateway ai-service

# 5. (Optional) Start web frontend
docker compose up -d frontend-web

# 6. Health checks
curl http://localhost:8081/api/v1/actuator/health  # core-service
curl http://localhost:3000/api/v1/health            # message-service
curl http://localhost:8083/actuator/health          # media-service
curl http://localhost:8085/health                   # realtime-gateway
curl http://localhost:8094/actuator/health          # ai-service
```

### ⚡ Option 2 — Local Development (Manual)

```bash
# 1. Start infrastructure only
cd docker
docker compose -f docker-compose.infra.yml up -d
# OR with message brokers:
docker compose up -d postgres redis rabbitmq kafka zookeeper

# 2. core-service (Terminal 1)
cd backend/java-services/services/core-service
# Windows:
.\mvnw.cmd spring-boot:run
# Linux/macOS:
./mvnw spring-boot:run

# 3. message-service (Terminal 2)
cd backend/node-services
npm install
npm run start:dev

# 4. realtime-gateway (Terminal 3)
cd backend/node-services
npm run start:realtime:dev

# 5. media-service (Terminal 4)
cd backend/java-services/services/media-service
./mvnw spring-boot:run

# 6. ai-service (Terminal 5)
cd backend/java-services/services/ai-service
./mvnw spring-boot:run
```

### 🌐 Web Frontend (Development)

```bash
cd frontend/web
cp .env.example .env   # configure VITE_CORE_URL etc.
npm install
npm run dev            # http://localhost:5173
```

### 📱 Flutter Mobile

```bash
cd frontend/mobile
flutter pub get

# Android emulator (10.0.2.2 → host machine)
flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=AI_SERVICE_URL=http://10.0.2.2:8094/api/v1

# Physical device — use LAN IP instead of 10.0.2.2
# See frontend/mobile/README.md for full network mapping guide
```

> **Note:** Dev profile has JWT default value and OTP test-mode enabled. Flyway runs automatically on core-service startup and is the single source of truth for schema. TypeORM `synchronize` is **disabled** in message-service.

---

## 📁 Project Structure

```
CNM-VNALO/
├── 📄 README.md                       # Project overview (English)
├── 📄 README.vi.md                    # Project overview (Vietnamese)
├── 📄 CONTRIBUTING.md                 # Contribution guidelines
├── 📄 nginx.conf                      # Nginx production config (vnalo.fit)
│
├── 📂 backend/
│   ├── java-services/
│   │   └── services/
│   │       ├── core-service/          # ✅ Auth, Users, Social, QR, AI Mascot
│   │       │   └── src/main/resources/db/migration/   # V1–V26 Flyway
│   │       ├── media-service/         # 🔄 Upload, S3/local, Stickers (29 APIs)
│   │       ├── ai-service/            # 🔄 Gemini + Ollama chatbot
│   │       ├── moderation-service/    # 🔄 Reports, Cases, Appeals
│   │       ├── notification-service/  # 🔄 FCM push via Kafka
│   │       ├── content-service/       # 🧪 Stories, Posts (scaffold)
│   │       └── analytics-service/     # ⏳ Planned
│   │
│   └── node-services/                 # NestJS monorepo workspace
│       └── apps/
│           ├── message-service/       # ✅ Chat, WebSocket, Inbox CQRS (port 3000)
│           └── realtime-gateway/      # 🔄 Presence, RabbitMQ bridge (port 8085)
│
├── 📂 frontend/
│   ├── mobile/                        # ✅ Flutter (iOS + Android)
│   │   ├── lib/
│   │   │   ├── features/
│   │   │   │   ├── auth/              # Phone+email login, OTP, splash
│   │   │   │   ├── chat/              # Messaging, reactions, pins, stickers
│   │   │   │   ├── call/              # Voice, video, group WebRTC calls
│   │   │   │   ├── ai_assistant/      # AI floating bubble, Gemini chat
│   │   │   │   ├── contacts/          # Phone book sync, friend management
│   │   │   │   ├── notifications/     # FCM, push notification handler
│   │   │   │   ├── profile/           # Avatar, settings, privacy
│   │   │   │   ├── timeline/          # Posts, stories (scaffold)
│   │   │   │   ├── discover/          # Explore screen
│   │   │   │   └── search/            # Global search
│   │   │   ├── services/              # ApiService, ChatService, SocketService…
│   │   │   └── core/                  # Theme, localization, local DB (Drift)
│   │   └── pubspec.yaml
│   │
│   └── web/                           # ✅ React 19 + Vite + TailwindCSS
│       ├── src/
│       │   ├── features/
│       │   │   ├── auth/              # Login, QR login, register, forgot password
│       │   │   ├── chat/              # Chat, Socket.IO, WebRTC (1-1 + group)
│       │   │   ├── contacts/          # Contacts page
│       │   │   ├── friends/           # Friend management
│       │   │   ├── notifications/     # Notification context
│       │   │   ├── profile/           # Profile management
│       │   │   └── settings/          # App settings
│       │   └── pages/                 # ChatPage, CallPage, AiChatPage…
│       └── package.json
│
├── 📂 docker/
│   ├── docker-compose.yml             # Full stack (all services + infra)
│   ├── docker-compose.infra.yml       # Infra only (PostgreSQL + Redis)
│   └── init-db.sql                    # Database initialization
│
├── 📂 docs/
│   ├── system/
│   │   ├── architecture.md            # Target architecture (hardened spec)
│   │   ├── database-schema.md         # Complete PostgreSQL schema
│   │   ├── api-reference.md           # REST + WebSocket API contracts
│   │   └── moderation/                # 10-doc moderation portal
│   └── project/
│       ├── status.md                  # Implementation status
│       ├── changelog.md               # Version history
│       └── team-assignment.md         # Team task distribution
│
├── 📂 config/
│   └── environments/                  # Environment config files
│
└── 📂 scripts/                        # E2E smoke scripts, dev utilities
```

---

## 🔧 Development

### core-service (Java/Spring Boot)

```bash
cd backend/java-services/services/core-service

# Build (skip tests)
./mvnw clean install -DskipTests

# Run (dev profile — default, OTP test-mode, JWT default secret)
./mvnw spring-boot:run

# Run tests (uses Testcontainers — Docker required)
./mvnw test

# Swagger UI
open http://localhost:8081/api/v1/swagger-ui.html
```

### message-service + realtime-gateway (NestJS monorepo)

```bash
cd backend/node-services

# Install
npm install

# Run message-service only (port 3000) with hot-reload
npm run start:dev

# Run realtime-gateway only (port 8085)
npm run start:realtime:dev

# Run both simultaneously (two terminals)
npm run start:dev &
npm run start:realtime:dev

# Build for production
npm run build                    # message-service
npm run build:realtime           # realtime-gateway

# Tests
npm test                         # unit tests
npm run test:e2e                 # e2e (from repo root: npm --prefix backend/node-services run test:e2e)
```

### Flutter Mobile

```bash
cd frontend/mobile

flutter pub get
flutter analyze      # must be error-free before PR
flutter test         # unit tests
flutter run ...      # see Quick Start section for --dart-define flags

# Release build
flutter build apk --release
flutter build ios --release
```

### React Web

```bash
cd frontend/web

npm install
npm run dev          # development server on :5173
npm run build        # production build
npm run lint         # ESLint check
```

---

## 🗄️ Database Migrations

Managed by **Flyway** in `core-service`, applied automatically on startup. TypeORM `synchronize: false` in all Node services.

| Migration | Description |
|-----------|-------------|
| `V1` | `auth_account`, `user_profile`, `user_setting`, `user_privacy_setting` |
| `V2` | Foreign key constraints |
| `V3` | Auth account enhancements |
| `V4` | Refresh token device tracking |
| `V5` | `friend_request`, `friendship`, `block_list`, `contact_sync` |
| `V6` | User profile enhancements |
| `V7` | Indexes and constraints |
| `V8` | `conversation`, `conversation_member`, `message`, `conversation_inbox` |
| `V9` | `message_reaction`, `pinned_message`, `message_receipt` |
| `V10` | Schema hardening — idempotent guards, uniqueness constraints |
| `V11` | Group `member_limit` default 1000→100 + backfill |
| `V12` | `message.hidden_by_users` for Delete-For-Me feature |
| `V13` | `conversation_join_request` + `join_mode` OPEN default |
| `V14` | `auth_account.email` column + case-insensitive unique index |
| `V15` | `auth_qr_login_session` table for QR web login flow |
| `V17` | `sync_control_policy` table |
| `V18` | `auth_session_audit` table — session transition audit trail |
| `V19` | Messaging entities alignment |
| `V20` | Chat settings expansion |
| `V21` | Group settings columns |
| `V22` | Legacy group settings alignment |
| `V23` | Member role rename: `OWNER`→`ADMIN`, `ADMIN`→`DEPUTY` (3-tier model) |
| `V24` | Optimistic locking (`version` column) on `conversation_member` |
| `V25` | `user_mascot_settings`, `ai_chat_history` tables for AI persistence |
| `V26` | `ai_chat_history.client_entry_id` for idempotency |

> **Current migration count: V26** · `moderation-service` has its own separate Flyway history (`V1–V2`, table `flyway_schema_history_moderation`)

---

## ⚙️ Environment Variables

<details>
<summary><b>Core variables — docker/.env</b></summary>

```bash
# ── Database ──────────────────────────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=vnalo_core
DB_USER=postgres
DB_PASS=postgres

# ── JWT (REQUIRED — shared across ALL services) ───
JWT_SECRET=<base64-encoded-512-bit-key>
# Generate: openssl rand -base64 64
JWT_ISSUER=vnalo

# ── Redis ─────────────────────────────────────────
REDIS_HOST=localhost
REDIS_PORT=6379

# ── RabbitMQ ──────────────────────────────────────
RABBITMQ_USER=guest
RABBITMQ_PASS=guest
RABBITMQ_PORT=5672
RABBITMQ_MGMT_PORT=15672

# ── Firebase (core-service + notification-service) ─
FIREBASE_CREDENTIALS_PATH=iuh-cnm-vnalo-firebase-adminsdk-fbsvc-5008b7c5eb.json

# ── AWS S3 (media-service) ────────────────────────
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_BUCKET_NAME=vnalo-media-service
AWS_REGION=ap-southeast-1

# ── AI Service ────────────────────────────────────
GEMINI_API_KEY=             # https://aistudio.google.com/apikey
GEMINI_MODEL=gemini-2.5-flash
OLLAMA_URL=http://ollama:11434
OLLAMA_MODEL=llama3.1:8b
AI_RATE_LIMIT=5             # req/min per user
AI_RATE_LIMIT_GLOBAL=10     # req/min global
AI_INTERNAL_SECRET=         # for core-service → ai-service internal calls

# ── CORS ──────────────────────────────────────────
APP_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,https://vnalo.fit
```

</details>

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [📂 Documentation Index](docs/README.md) | All docs with descriptions |
| [🏗️ Architecture](docs/system/architecture.md) | Target architecture spec (hardened, v2.0) |
| [🗄️ Database Schema](docs/system/database-schema.md) | Complete PostgreSQL schema (Flyway V1–V26) |
| [📡 API Reference](docs/system/api-reference.md) | REST endpoints + WebSocket events |
| [🛡️ Moderation Portal](docs/system/moderation/) | 10-document moderation service spec |
| [📊 Status](docs/project/status.md) | Implementation status per service |
| [📝 Changelog](docs/project/changelog.md) | Version history |
| [👥 Team Assignment](docs/project/team-assignment.md) | Task distribution |
| [🤝 Contributing](CONTRIBUTING.md) | Code standards and workflow |
| [📱 Mobile Setup Guide](frontend/mobile/README.md) | Flutter setup, run, troubleshoot |
| [🌐 Web Setup Guide](frontend/web/README.md) | React web setup and development |
| [🖼️ Media Service Guide](backend/java-services/services/media-service/Readme.md) | Media + Sticker API (29 endpoints) |
| [🤖 AI Service Guide](backend/java-services/services/ai-service/README.md) | AI chatbot setup and API |
| [🛡️ Moderation Service Guide](backend/java-services/services/moderation-service/README.md) | Moderation quick start |
| [⚡ Realtime Gateway Guide](backend/node-services/apps/realtime-gateway/Readme.md) | WebSocket events reference |

---

## ✅ Current Status

| Service | Status | Features | Notes |
|---------|--------|----------|-------|
| **core-service** | ✅ Complete | Auth (phone+email+OTP+QR), Users, Friends, Blocks, Contacts, FCM, Session Audit, AI Mascot | Flyway V1–V26, Swagger |
| **message-service** | ✅ Complete | Conversations, Messages, Reactions, Pins, Inbox, WebSocket (Redis adapter), Kafka producer | 9 TypeORM entities |
| **realtime-gateway** | 🔄 Active | Presence, typing, heartbeat, RabbitMQ→Socket.IO broadcast | Port 8085, `/realtime` namespace |
| **media-service** | 🔄 Active | 29 APIs: upload/presigned/thumbnail/access + sticker packs, S3+local fallback | RabbitMQ async thumbnails |
| **ai-service** | 🔄 Active | Gemini 2.5 Flash + Ollama fallback, rate limiting, persistent history | V25–V26 migrations |
| **notification-service** | 🔄 Active | Kafka consumer → FCM push, device token management | Active in docker-compose |
| **moderation-service** | 🔄 In Progress | Reports, cases, appeals, audit log, moderation actions | Separate Flyway history |
| **content-service** | 🧪 Scaffolded | Stories, posts, comments (scaffold) | Commented out in compose |
| **analytics-service** | ⏳ Planned | Event ingestion, dashboards | Commented out in compose |
| **Flutter mobile** | ✅ Active | Full auth, chat, WebRTC calls, AI assistant, contacts, notifications | Drift local DB, Provider+Riverpod |
| **React web** | ✅ Active | Auth (QR login), chat, WebRTC calls, AI chat, contacts, profile | React 19 + Vite 8 |

---

## 🤝 Contributing

### 📝 Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     ✨ New feature
fix:      🐛 Bug fix
docs:     📝 Documentation
style:    💎 Code style (formatting)
refactor: ♻️  Code refactoring
test:     ✅ Tests
chore:    🔧 Maintenance
```

Scope examples: `feat(auth):`, `fix(message-service):`, `docs(mobile):`

### 🔀 Workflow

```bash
# 1. Create feature branch from nguyenvu
git checkout nguyenvu
git pull origin nguyenvu
git checkout -b feature/your-feature

# 2. Develop, commit using conventional commits
git commit -m 'feat(scope): add amazing feature'

# 3. Before PR: pass tests + update docs
flutter analyze && flutter test        # mobile
npm test                               # node-services
./mvnw test                            # java services

# 4. Open Pull Request → nguyenvu
git push origin feature/your-feature
```

### 👥 Team

<div align="center">

#### CNM-DHKTPM18A-2526 Development Team

<table>
<tr>
<td align="center">
<a href="https://github.com/iamnguyenvu">
<img src="https://github.com/iamnguyenvu.png" width="100px;" alt="Nguyễn Hoàng Nguyên Vũ"/>
<br /><sub><b>Nguyễn Hoàng Nguyên Vũ</b></sub>
</a>
<br /><sub>👑 Team Leader</sub>
<br /><sub>📋 22003185</sub>
<br />
<a href="https://github.com/iamnguyenvu">
<img src="https://img.shields.io/badge/GitHub-iamnguyenvu-181717?style=flat-square&logo=github">
</a>
<br />
<a href="mailto:iamnguyenvu.gm@gmail.com">
<img src="https://img.shields.io/badge/Email-Contact-EA4335?style=flat-square&logo=gmail&logoColor=white">
</a>
</td>
<td align="center">
<a href="https://github.com/datle0910">
<img src="https://github.com/datle0910.png" width="100px;" alt="Lê Văn Đạt"/>
<br /><sub><b>Lê Văn Đạt</b></sub>
</a>
<br /><sub>💻 Developer</sub>
<br /><sub>📋 22001605</sub>
<br />
<a href="https://github.com/datle0910">
<img src="https://img.shields.io/badge/GitHub-datle0910-181717?style=flat-square&logo=github">
</a>
</td>
<td align="center">
<a href="https://github.com/pnwang1704">
<img src="https://github.com/pnwang1704.png" width="100px;" alt="Phan Nhật Quang"/>
<br /><sub><b>Phan Nhật Quang</b></sub>
</a>
<br /><sub>💻 Developer</sub>
<br /><sub>📋 22684961</sub>
<br />
<a href="https://github.com/pnwang1704">
<img src="https://img.shields.io/badge/GitHub-pnwang1704-181717?style=flat-square&logo=github">
</a>
</td>
<td align="center">
<a href="https://github.com/thaibaotb">
<img src="https://github.com/thaibaotb.png" width="100px;" alt="Đặng Thái Bảo"/>
<br /><sub><b>Đặng Thái Bảo</b></sub>
</a>
<br /><sub>💻 Developer</sub>
<br /><sub>📋 22686331</sub>
<br />
<a href="https://github.com/thaibaotb">
<img src="https://img.shields.io/badge/GitHub-thaibaotb-181717?style=flat-square&logo=github">
</a>
</td>
</tr>
</table>

**Organization**: [CNM-DHKTPM18A-2526](https://github.com/CNM-DHKTPM18A-2526) | **Course**: Công Nghệ Mới - DHKTPM18A

</div>

**Project Responsibilities:**
- **Nguyễn Hoàng Nguyên Vũ** (Team Leader): Architecture, core-service, message-service, realtime-gateway, web frontend, AI service integration
- **Lê Văn Đạt**: realtime-gateway, media-service
- **Phan Nhật Quang**: content-service, notification-service
- **Đặng Thái Bảo**: moderation-service, analytics-service

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Inspired by** [Zalo](https://zalo.me) · [WhatsApp](https://whatsapp.com) · [Telegram](https://telegram.org)

**Production domain**: [vnalo.fit](https://vnalo.fit) · **Repo**: [CNM-DHKTPM18A-2526/CNM-VNALO](https://github.com/CNM-DHKTPM18A-2526/CNM-VNALO)

<sub>Made with ❤️ by the CNM-DHKTPM18A-2526 Team · 2026</sub>

**[⬆ Back to Top](#-vnalo)**

</div>
