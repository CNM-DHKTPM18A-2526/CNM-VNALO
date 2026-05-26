<div align="center">

<img src="frontend/mobile/assets/icons/app_icon.png" alt="VNALO Logo" width="120" />

# VNALO

### Nền Tảng Nhắn Tin Thời Gian Thực — Kiến Trúc Microservices

*Polyglot backend · Flutter mobile · React web · AI trợ lý · WebRTC calls*

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
  <a href="https://nestjs.com/">
    <img src="https://img.shields.io/badge/NestJS-11-E0234E?style=for-the-badge&logo=nestjs&logoColor=white" alt="NestJS">
  </a>
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
  <a href="docs/">📖 Tài liệu</a> •
  <a href="#-bắt-đầu-nhanh">🚀 Bắt đầu nhanh</a> •
  <a href="#️-kiến-trúc-hệ-thống">🏗️ Kiến trúc</a> •
  <a href="#-trạng-thái-hệ-thống">📊 Trạng thái</a> •
  <a href="#-đóng-góp">🤝 Đóng góp</a>
</p>

</div>

---

## 📋 Mục Lục

- [✨ Điểm Nổi Bật](#-điểm-nổi-bật)
- [🛠️ Công Nghệ](#️-công-nghệ)
- [🏗️ Kiến Trúc Hệ Thống](#️-kiến-trúc-hệ-thống)
- [🚀 Bắt Đầu Nhanh](#-bắt-đầu-nhanh)
- [📁 Cấu Trúc Dự Án](#-cấu-trúc-dự-án)
- [🔧 Phát Triển](#-phát-triển)
- [🗄️ Flyway Migrations](#️-flyway-migrations)
- [⚙️ Biến Môi Trường](#️-biến-môi-trường)
- [📖 Tài Liệu](#-tài-liệu)
- [📊 Trạng Thái Hệ Thống](#-trạng-thái-hệ-thống)
- [🤝 Đóng Góp](#-đóng-góp)

---

## ✨ Điểm Nổi Bật

- **Kiến trúc polyglot thực chiến**: Spring Boot (Java 21) cho core/media/ai/moderation/notification + NestJS (TypeScript) cho message/realtime-gateway
- **Dual frontend**: Flutter mobile (iOS/Android) + React 19 web app (Vite + TailwindCSS) — cả hai đầy đủ tính năng
- **WebRTC calls**: Gọi thoại, video 1-1 và nhóm trên cả mobile (flutter_webrtc) lẫn web
- **AI trợ lý tích hợp**: Google Gemini 2.5 Flash (primary) + Ollama fallback, rate limiting, lịch sử persistent (Redis + PostgreSQL)
- **QR Login**: Quét mã QR từ mobile để đăng nhập web — bảng `auth_qr_login_session`
- **Auth đa phương thức**: Đăng nhập bằng số điện thoại **hoặc** email, xác thực OTP qua email
- **Schema có kiểm soát**: Flyway V1→**V26** là nguồn sự thật, `synchronize: false` trong TypeORM
- **Production-hardened**: Nginx TLS, CORS whitelist tường minh, JWT trên mọi endpoint, session audit trail
- **Messaging thực chiến**: Socket.IO + Redis IO adapter cho scale ngang, cursor-based pagination, CQRS inbox
- **Group roles 3 tầng**: `ADMIN` (trưởng nhóm) / `DEPUTY` (phó nhóm) / `MEMBER` (V23 migration)

---

## 🛠️ Công Nghệ

### Backend Services

| Service | Port | Stack | Tình Trạng |
|---------|:----:|-------|-----------|
| `core-service` | 8081 | Spring Boot 3.4.2, Java 21 | ✅ Complete |
| `message-service` | 3000 | NestJS 11, TypeScript | ✅ Complete |
| `realtime-gateway` | 8085 | NestJS, Node.js 20+ | 🔄 Active |
| `media-service` | 8083 | Spring Boot 3.4.2, Java 21 | 🔄 Active |
| `ai-service` | 8094 | Spring Boot 3.4.2, Java 21 | 🔄 Active |
| `notification-service` | 8087 | Spring Boot, Java 21 | 🔄 Active |
| `moderation-service` | 8082 | Spring Boot 3.4.x, Java 21 | 🔄 In Progress |
| `content-service` | 8086 | Spring Boot (scaffold) | 🧪 Scaffolded |
| `analytics-service` | 8084 | Spring Boot (planned) | ⏳ Planned |

### Data Layer

| Component | Công nghệ | Mục đích |
|-----------|-----------|---------|
| Primary DB | PostgreSQL 16 | `vnalo_core`, `vnalo_media`, `vnalo_notification`, `vnalo_analytics` |
| Cache / Sequence | Redis 7 | Session, presence, `serverSeq` INCR, block cache |
| Message Broker | RabbitMQ 4 | Thumbnails async, realtime broadcast |
| Event Streaming | Kafka + Zookeeper | Friendship/block events, notification pipeline |

### Frontend

| Nền tảng | Stack | Tính năng nổi bật |
|---------|-------|-----------------|
| Flutter Mobile | Flutter 3.x · Dart 3.7+ · Provider + Riverpod · Drift (SQLite) | Auth, Chat, WebRTC calls, AI assistant, Contacts, FCM |
| React Web | React 19 · TypeScript · Vite 8 · TailwindCSS 3.4 · Socket.IO | Chat, WebRTC calls, QR login, AI chat, Contacts |

### DevOps

- **Containerization**: Docker + Docker Compose (full-stack và infra-only)
- **Reverse Proxy**: Nginx — TLS termination, path-based routing, WebSocket proxy
- **Domain**: `vnalo.fit` (Let's Encrypt SSL)
- **Media Storage**: AWS S3 (primary) + local `.media-local/` (fallback)

---

## 🏗️ Kiến Trúc Hệ Thống

### Topology tổng quan

```
┌─────────────────────────────────────────────┐
│              CLIENTS                         │
│  Flutter Mobile (iOS/Android)                │
│  React Web (vnalo.fit)                       │
└────────────────┬────────────────────────────┘
                 │ HTTPS / WSS
┌────────────────▼────────────────────────────┐
│   NGINX (TLS · vnalo.fit)                    │
│   Path-based routing · WebSocket upgrade     │
└──┬─────────┬──────────┬──────────┬──────────┘
   │         │          │          │
core:8081  msg:3000  media:8083  rtgw:8085
   │         │          │      (realtime)
   │      ai:8094    notif:8087
   │
   └──────── JWT HS512 (shared secret) ────────┐
                                               │
                                    ┌──────────▼──────────┐
                                    │   PostgreSQL 16      │
                                    │   Redis 7            │
                                    │   RabbitMQ 4         │
                                    │   Kafka/Zookeeper    │
                                    └─────────────────────┘
```

### Bản đồ service đầy đủ

| Service | Port | Stack | Trách nhiệm |
|---------|:----:|-------|------------|
| **core-service** | 8081 | Spring Boot 3.4.2 / Java 21 | Auth (phone+email+OTP+QR), Users, Friends, Blocks, Contacts, FCM, Session Audit, AI Mascot settings |
| **message-service** | 3000 | NestJS 11 / TypeScript | Conversations, Messages, Inbox CQRS, WebSocket gateway (Redis adapter), Reactions, Pins, Join requests |
| **realtime-gateway** | 8085 | NestJS / Node.js 20+ | Presence, typing indicators, heartbeat, RabbitMQ→Socket.IO broadcast, namespace `/realtime` |
| **media-service** | 8083 | Spring Boot 3.4.2 / Java 21 | Upload (S3+local), presigned upload, thumbnails async (RabbitMQ), sticker packs (29 APIs) |
| **ai-service** | 8094 | Spring Boot 3.4.2 / Java 21 | Gemini 2.5 Flash + Ollama fallback, rate limiting (5/min user · 10/min global), persistent history |
| **notification-service** | 8087 | Spring Boot / Java 21 | Kafka consumer → FCM push, device token management |
| **moderation-service** | 8082 | Spring Boot 3.4.x / Java 21 | Reports, cases, appeals, audit log, moderation actions |
| **content-service** | 8086 | Spring Boot (scaffold) | Stories, posts, comments (scaffold) |
| **analytics-service** | 8084 | Spring Boot (planned) | Event ingestion, dashboards |
| **frontend-web** | 80/443 | React 19 + Nginx | Web client served via Docker/Nginx |

### Luồng tin nhắn thực chiến

```
Client A ──POST /api/v1/messages──► message-service (3000)
                                         │ Lưu vào PostgreSQL
                                         │ Publish → RabbitMQ (vnalo.realtime)
                                         ▼
                                   realtime-gateway (8085)
                                         │ Broadcast tới room conversation:{id}
                                         ▼
Client B ◄──── event: message.received ──── Socket.IO namespace /realtime
```

### Quyết định thiết kế quan trọng

| Quyết định | Lý do |
|-----------|-------|
| `serverSeq` per conversation via Redis INCR | Thứ tự tin nhắn monotonic, không bị collision timestamp |
| Cursor-based pagination (`before` + `limit`) | Hiệu quả với conversation lớn |
| CQRS Inbox (`conversation_inbox`) | Đếm unread O(1), inbox load nhanh |
| `clientMessageId` idempotency | Deduplication tại tầng persistence |
| TypeORM `synchronize: false` | Schema chỉ do Flyway (core-service) quản lý |
| Group roles: ADMIN/DEPUTY/MEMBER | 3 tầng rõ ràng thay thế OWNER/ADMIN cũ (V23) |
| QR Login session table | Đăng nhập web bằng mobile approval — stateless, có TTL |

### Nginx routing (vnalo.fit)

| Pattern | Upstream | Ghi chú |
|---------|----------|---------|
| `/socket.io/` | `realtime-gateway:8085` | WebSocket, tắt buffering |
| `/api/v1/media` | `media-service:8083` | File upload/download/sticker |
| `/api/v1/ai/mascot` | `core-service:8081` | AI mascot settings |
| `/api/v1/ai` | `ai-service:8094` | AI chatbot (timeout 120s) |
| `/api/v1/(conversations\|messages\|...)` | `message-service:3000` | Chat REST |
| `/api/v1/notifications` | `notification-service:8087` | FCM push |
| `/api/v1/(posts\|stories\|feeds\|comments)` | `content-service:8086` | Social content |
| `/api/v1/` (catch-all) | `core-service:8081` | Auth, Users, Social |
| `/` | Static files | React web app |

---

## 🚀 Bắt Đầu Nhanh

### Yêu cầu

```bash
# Bắt buộc
Java 21+
Node.js 20+
Docker + Docker Compose
Git

# Tùy chọn — mobile
Flutter 3.x (Dart 3.7+)
Android Studio / Xcode

# Tùy chọn — web development
Trình duyệt + Node.js (đã có ở trên)
```

### Cách 1 — Full stack Docker (khuyến nghị)

```bash
# 1. Clone
git clone https://github.com/CNM-DHKTPM18A-2526/CNM-VNALO.git
cd CNM-VNALO

# 2. Cấu hình secrets
cp docker/.env.example docker/.env
# Chỉnh sửa docker/.env — bắt buộc: JWT_SECRET
# Tùy chọn: AWS keys (media), GEMINI_API_KEY (AI)

# 3. Đặt Firebase credentials (cho core-service FCM)
# Đường dẫn: backend/java-services/services/core-service/src/main/resources/
# Tên file: iuh-cnm-vnalo-firebase-adminsdk-fbsvc-5008b7c5eb.json

# 4. Khởi động hạ tầng + services
cd docker
docker compose up -d postgres redis rabbitmq kafka zookeeper
docker compose up -d core-service message-service realtime-gateway media-service ai-service notification-service

# 5. (Tùy chọn) Web frontend
docker compose up -d frontend-web

# 6. Kiểm tra health
curl http://localhost:8081/api/v1/actuator/health   # core-service
curl http://localhost:3000/api/v1/health             # message-service
curl http://localhost:8083/actuator/health           # media-service
curl http://localhost:8085/health                    # realtime-gateway
curl http://localhost:8094/actuator/health           # ai-service
```

### Cách 2 — Phát triển local (từng service)

```bash
# 1. Khởi động hạ tầng
cd docker
docker compose -f docker-compose.infra.yml up -d
# Hoặc đầy đủ hơn với message broker:
docker compose up -d postgres redis rabbitmq kafka zookeeper

# 2. core-service (Terminal 1)
cd backend/java-services/services/core-service
./mvnw spring-boot:run        # Linux/macOS
.\mvnw.cmd spring-boot:run    # Windows

# 3. message-service (Terminal 2)
cd backend/node-services
npm install && npm run start:dev

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

### Chạy Flutter Mobile

```bash
cd frontend/mobile
flutter pub get

# Android emulator (10.0.2.2 = host machine)
flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=AI_SERVICE_URL=http://10.0.2.2:8094/api/v1

# Thiết bị thật — dùng LAN IP thay vì 10.0.2.2
# Xem hướng dẫn chi tiết: frontend/mobile/README.md
```

### Chạy React Web

```bash
cd frontend/web
cp .env.example .env
npm install
npm run dev    # http://localhost:5173
```

### Health check nhanh

| Service | URL | Kỳ vọng |
|---------|-----|---------|
| core-service | `http://localhost:8081/api/v1/actuator/health` | `{"status":"UP"}` |
| message-service | `http://localhost:3000/api/v1/health` | `{"status":"ok"}` |
| media-service | `http://localhost:8083/actuator/health` | `{"status":"UP"}` |
| realtime-gateway | `http://localhost:8085/health` | `{"status":"ok"}` |
| ai-service | `http://localhost:8094/actuator/health` | `{"status":"UP"}` |
| moderation-service | `http://localhost:8082/api/v1/actuator/health` | `{"status":"UP"}` |

---

## 📁 Cấu Trúc Dự Án

```text
CNM-VNALO/
├── README.md                        # Tài liệu tổng quan (English)
├── README.vi.md                     # Tài liệu tổng quan (Tiếng Việt)
├── CONTRIBUTING.md                  # Hướng dẫn đóng góp
├── nginx.conf                       # Nginx production config (vnalo.fit + SSL)
│
├── backend/
│   ├── java-services/services/
│   │   ├── core-service/            # ✅ Auth, Users, Social, QR, AI Mascot
│   │   │   └── src/main/resources/db/migration/  # V1–V26 Flyway migrations
│   │   ├── media-service/           # 🔄 Upload, S3/local, Sticker (29 APIs)
│   │   ├── ai-service/              # 🔄 Gemini 2.5 Flash + Ollama fallback
│   │   ├── moderation-service/      # 🔄 Reports, Cases, Appeals, Audit
│   │   ├── notification-service/    # 🔄 Kafka → FCM push
│   │   ├── content-service/         # 🧪 Stories, Posts (scaffold)
│   │   └── analytics-service/       # ⏳ Planned
│   │
│   └── node-services/               # NestJS monorepo workspace
│       └── apps/
│           ├── message-service/     # ✅ Chat, WebSocket, CQRS Inbox (port 3000)
│           └── realtime-gateway/    # 🔄 Presence, RabbitMQ→WS bridge (port 8085)
│
├── frontend/
│   ├── mobile/                      # ✅ Flutter (iOS + Android)
│   │   └── lib/features/
│   │       ├── auth/                # Đăng nhập phone+email+OTP
│   │       ├── chat/                # Chat, reactions, pins, stickers, voice msg
│   │       ├── call/                # Voice/Video/Group WebRTC calls
│   │       ├── ai_assistant/        # AI floating bubble, Gemini chat
│   │       ├── contacts/            # Đồng bộ danh bạ, quản lý bạn bè
│   │       ├── notifications/       # FCM handler
│   │       ├── profile/             # Avatar, cài đặt, quyền riêng tư
│   │       ├── timeline/            # Bài đăng, stories (scaffold)
│   │       ├── discover/            # Màn hình khám phá
│   │       └── search/              # Tìm kiếm toàn cục
│   │
│   └── web/                         # ✅ React 19 + Vite + TailwindCSS
│       └── src/features/
│           ├── auth/                # Login, QR login, register, forgot password
│           ├── chat/                # Chat, Socket.IO, WebRTC 1-1 + group
│           ├── contacts/            # Danh sách liên hệ
│           ├── friends/             # Quản lý bạn bè
│           ├── notifications/       # Notification context
│           ├── profile/             # Hồ sơ người dùng
│           └── settings/            # Cài đặt ứng dụng
│
├── docker/
│   ├── docker-compose.yml           # Full stack (tất cả services + infra)
│   ├── docker-compose.infra.yml     # Chỉ infra (PostgreSQL + Redis)
│   └── init-db.sql                  # Khởi tạo database
│
├── docs/
│   ├── system/
│   │   ├── architecture.md          # Target architecture (hardened v2.0)
│   │   ├── database-schema.md       # Schema đầy đủ + Flyway notes
│   │   ├── api-reference.md         # REST + WebSocket contracts
│   │   └── moderation/              # 10 tài liệu moderation portal
│   └── project/
│       ├── status.md                # Trạng thái implementation
│       ├── changelog.md             # Lịch sử thay đổi
│       └── team-assignment.md       # Phân công nhóm
│
├── config/environments/             # Cấu hình môi trường
└── scripts/                         # Script E2E smoke test, tiện ích dev
```

---

## 🔧 Phát Triển

### core-service

```bash
cd backend/java-services/services/core-service

# Build (bỏ qua test)
./mvnw clean install -DskipTests

# Chạy (dev profile — test-mode OTP, JWT mặc định)
./mvnw spring-boot:run

# Chạy test (cần Docker — Testcontainers)
./mvnw test

# Swagger UI
# http://localhost:8081/api/v1/swagger-ui.html
```

### node-services (NestJS monorepo)

```bash
cd backend/node-services

# Cài đặt dependencies
npm install

# Chạy message-service (port 3000) với hot-reload
npm run start:dev

# Chạy realtime-gateway (port 8085)
npm run start:realtime:dev

# Build production
npm run build           # message-service
npm run build:realtime  # realtime-gateway

# Test
npm test                # unit tests
npm run test:e2e        # e2e tests
# Hoặc từ root project:
npm --prefix backend/node-services run test:e2e
```

### Flutter Mobile

```bash
cd frontend/mobile

flutter pub get
flutter analyze    # phải không có lỗi/warning trước khi PR
flutter test       # unit tests

# Build release
flutter build apk --release
flutter build ios --release
```

### React Web

```bash
cd frontend/web

npm install
npm run dev      # dev server :5173
npm run build    # production build
npm run lint     # ESLint
```

---

## 🗄️ Flyway Migrations

Tất cả migrations được quản lý bởi **Flyway** trong `core-service`, áp dụng tự động khi khởi động. **Không** dùng Cassandra — PostgreSQL là database duy nhất trong runtime.

| Migration | Mô tả |
|-----------|-------|
| `V1` | `auth_account`, `user_profile`, `user_setting`, `user_privacy_setting` |
| `V2` | Ràng buộc khóa ngoại |
| `V3` | Cải tiến auth_account |
| `V4` | Refresh token device tracking |
| `V5` | `friend_request`, `friendship`, `block_list`, `contact_sync` |
| `V6` | Cải tiến user_profile |
| `V7` | Indexes và constraints |
| `V8` | `conversation`, `conversation_member`, `message`, `conversation_inbox` |
| `V9` | `message_reaction`, `pinned_message`, `message_receipt` |
| `V10` | Schema hardening — idempotent guards, unique constraints |
| `V11` | `member_limit` mặc định 1000→100 + backfill |
| `V12` | `message.hidden_by_users` — tính năng Xóa Ở Máy Tôi |
| `V13` | `conversation_join_request` + `join_mode` mặc định OPEN |
| `V14` | `auth_account.email` — hỗ trợ đăng nhập bằng email |
| `V15` | `auth_qr_login_session` — bảng QR web login |
| `V17` | `sync_control_policy` |
| `V18` | `auth_session_audit` — audit trail phiên đăng nhập |
| `V19` | Căn chỉnh messaging entities |
| `V20` | Mở rộng chat settings |
| `V21` | Cột group settings |
| `V22` | Căn chỉnh legacy group settings |
| `V23` | Đổi tên role: `OWNER`→`ADMIN`, `ADMIN`→`DEPUTY` (3 tầng) |
| `V24` | Optimistic locking (`version`) trên `conversation_member` |
| `V25` | `user_mascot_settings`, `ai_chat_history` — AI persistent storage |
| `V26` | `ai_chat_history.client_entry_id` — idempotency cho AI history |

> **Tổng cộng: V26 migrations** · `moderation-service` có Flyway riêng (V1–V2, bảng `flyway_schema_history_moderation`)

---

## ⚙️ Biến Môi Trường

<details>
<summary><b>Xem cấu hình đầy đủ — docker/.env</b></summary>

```bash
# ── Database ──────────────────────────────────────────
DB_HOST=localhost
DB_PORT=5432
DB_NAME=vnalo_core
DB_USER=postgres
DB_PASS=postgres

# ── JWT (BẮT BUỘC — dùng chung toàn bộ services) ─────
JWT_SECRET=<base64-encoded-512-bit-key>
# Tạo key: openssl rand -base64 64
JWT_ISSUER=vnalo

# ── Redis ─────────────────────────────────────────────
REDIS_HOST=localhost
REDIS_PORT=6379

# ── RabbitMQ ──────────────────────────────────────────
RABBITMQ_USER=guest
RABBITMQ_PASS=guest
RABBITMQ_PORT=5672
RABBITMQ_MGMT_PORT=15672

# ── Firebase (core-service + notification-service) ────
FIREBASE_CREDENTIALS_PATH=iuh-cnm-vnalo-firebase-adminsdk-fbsvc-5008b7c5eb.json

# ── AWS S3 (media-service) ────────────────────────────
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_BUCKET_NAME=vnalo-media-service
AWS_REGION=ap-southeast-1

# ── AI Service ────────────────────────────────────────
GEMINI_API_KEY=             # https://aistudio.google.com/apikey
GEMINI_MODEL=gemini-2.5-flash
OLLAMA_URL=http://ollama:11434
OLLAMA_MODEL=llama3.1:8b
AI_RATE_LIMIT=5             # req/min/user
AI_RATE_LIMIT_GLOBAL=10     # req/min tổng
AI_INTERNAL_SECRET=         # core-service → ai-service internal

# ── CORS ──────────────────────────────────────────────
APP_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,https://vnalo.fit
```

</details>

---

## 📖 Tài Liệu

| Tài liệu | Nội dung |
|----------|---------|
| [docs/README.md](docs/README.md) | Index toàn bộ tài liệu |
| [docs/system/architecture.md](docs/system/architecture.md) | Kiến trúc mục tiêu (hardened v2.0, 2026-04-29) |
| [docs/system/api-reference.md](docs/system/api-reference.md) | REST + WebSocket API contracts |
| [docs/system/database-schema.md](docs/system/database-schema.md) | Schema đầy đủ + Flyway V1–V26 notes |
| [docs/system/moderation/](docs/system/moderation/) | 10 tài liệu moderation service portal |
| [docs/project/status.md](docs/project/status.md) | Trạng thái implementation hiện tại |
| [docs/project/changelog.md](docs/project/changelog.md) | Lịch sử thay đổi |
| [docs/project/team-assignment.md](docs/project/team-assignment.md) | Phân công nhóm |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Chuẩn code và quy trình đóng góp |
| [frontend/mobile/README.md](frontend/mobile/README.md) | Hướng dẫn setup, chạy, debug Flutter |
| [frontend/web/README.md](frontend/web/README.md) | Hướng dẫn setup và phát triển React web |
| [backend/java-services/services/media-service/Readme.md](backend/java-services/services/media-service/Readme.md) | API media + sticker (29 endpoints) |
| [backend/java-services/services/ai-service/README.md](backend/java-services/services/ai-service/README.md) | Setup và API AI chatbot |
| [backend/node-services/apps/realtime-gateway/Readme.md](backend/node-services/apps/realtime-gateway/Readme.md) | WebSocket events reference |

---

## 📊 Trạng Thái Hệ Thống

| Nhóm | Trạng thái | Ghi chú |
|------|-----------|---------|
| Auth (phone+email+OTP+QR) | ✅ Complete | V14 thêm email, V15 thêm QR session |
| Messaging + WebSocket | ✅ Complete | Socket.IO, Redis adapter, CQRS inbox |
| Realtime Gateway | 🔄 Active | Presence, typing, RabbitMQ bridge |
| Media upload + Sticker | 🔄 Active | S3+local, 29 APIs, RabbitMQ thumbnails |
| AI chatbot (Gemini+Ollama) | 🔄 Active | Rate limiting, persistent history (V25–V26) |
| Push Notifications (FCM) | 🔄 Active | Kafka→FCM pipeline |
| Moderation workflow | 🔄 In Progress | Reports, cases, appeals, audit |
| Flutter mobile | ✅ Active | Drift local DB, WebRTC calls, AI bubble |
| React web | ✅ Active | QR login, WebRTC calls, AI chat |
| Content/Stories service | 🧪 Scaffolded | Scaffold + Nginx route đã có |
| Analytics service | ⏳ Planned | Commented out trong compose |

### Snapshot kiểm tra

| Track | Kết quả |
|-------|---------|
| core-service tests | ✅ Xanh (Testcontainers) |
| node-services tests | ✅ Khả dụng và chạy được |
| flutter test | ✅ Pass |
| flutter analyze | ✅ Không lỗi/warning |
| Docker compose health | ✅ infra + core services healthy |

---

## 🤝 Đóng Góp

- Dùng [Conventional Commits](https://www.conventionalcommits.org/): `feat(scope):`, `fix(scope):`, `docs(scope):`, `test:`, `chore:`
- Tạo branch từ `nguyenvu`, mở Pull Request về `nguyenvu`
- Trước khi merge: pass test + `flutter analyze` + cập nhật docs liên quan
- Không hardcode machine-specific IP vào source code — dùng `--dart-define` hoặc env var

Chi tiết đầy đủ: [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 Giấy Phép

Dự án sử dụng [MIT License](LICENSE).

---

<div align="center">

**Domain**: [vnalo.fit](https://vnalo.fit) · **Repo**: [CNM-DHKTPM18A-2526/CNM-VNALO](https://github.com/CNM-DHKTPM18A-2526/CNM-VNALO) · **Khóa học**: CNM - DHKTPM18A

<sub>Made with ❤️ by CNM-DHKTPM18A-2526 Team · 2026</sub>

**[⬆ Về đầu trang](#-vnalo)**

</div>
