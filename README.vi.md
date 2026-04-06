<div align="center">

<img src="frontend/mobile/assets/icons/app_icon.png" alt="VNALO Logo" width="120" />

# VNALO

### Nền Tảng Nhắn Tin Thời Gian Thực Theo Kiến Trúc Microservices

*Bản tiếng Việt đã được audit/reconcile toàn diện theo runtime hiện tại (04/2026)*

<p align="center">
  <a href="https://github.com/CNM-DHKTPM18A-2526/CNM-ZALO">
    <img src="https://img.shields.io/badge/version-1.0.0--SNAPSHOT-blue.svg?style=for-the-badge" alt="Version">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge" alt="License">
  </a>
  <a href="https://openjdk.org/">
    <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java">
  </a>
  <a href="https://spring.io/projects/spring-boot">
    <img src="https://img.shields.io/badge/Spring_Boot-3.4-6DB33F?style=for-the-badge&logo=spring-boot&logoColor=white" alt="Spring Boot">
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
  <a href="#-kiến-trúc">🏗️ Kiến trúc</a> •
  <a href="#-trạng-thái-hệ-thống">📊 Trạng thái</a> •
  <a href="#-đóng-góp">🤝 Đóng góp</a>
</p>

</div>

---

## 📋 Mục Lục

- [✨ Điểm Nổi Bật](#-điểm-nổi-bật)
- [🛠️ Công Nghệ](#️-công-nghệ)
- [🏗️ Kiến Trúc](#️-kiến-trúc)
- [🚀 Bắt Đầu Nhanh](#-bắt-đầu-nhanh)
- [📁 Cấu Trúc Dự Án](#-cấu-trúc-dự-án)
- [🔧 Phát Triển](#-phát-triển)
- [📖 Tài Liệu](#-tài-liệu)
- [📊 Trạng Thái Hệ Thống](#-trạng-thái-hệ-thống)
- [🤝 Đóng Góp](#-đóng-góp)

---

## ✨ Điểm Nổi Bật

- **Kiến trúc polyglot**: Spring Boot (core/media/moderation/ai) + NestJS (message/realtime).
- **Realtime thực chiến**: Socket.IO + JWT handshake + inbox CQRS cho luồng chat.
- **Mobile Flutter**: auth flow đầy đủ, avatar upload có retry/fallback cho thiết bị thật.
- **Schema có kiểm soát**: Flyway là nguồn sự thật, hiện tại đến **V13**.
- **Môi trường chạy rõ ràng**: có cả full-stack compose và infra-only compose.

---

## 🛠️ Công Nghệ

### Backend
- `core-service`: Spring Boot 3.4.2, Java 21, Spring Security, Flyway.
- `message-service`: NestJS 11, TypeORM, Socket.IO.
- `media-service`, `moderation-service`, `realtime-gateway`: đang phát triển tích cực, đã có runtime trong compose.
- `content-service`, `notification-service`: scaffold đã có trong repo.
- `ai-service`: experimental (Gemini + Ollama fallback).

### Data Layer
- PostgreSQL 16: lưu trữ chính.
- Redis 7: cache/presence/sequence.
- RabbitMQ, Kafka, Ollama: mở rộng theo profile/môi trường.

### Mobile
- Flutter 3.x, Dart 3.x.
- Cấu hình endpoint bằng `--dart-define`.

---

## 🏗️ Kiến Trúc

### Runtime chính hiện tại

```text
Flutter Mobile
  -> core-service (8081): Auth/User/Friend/Contact/QR
  -> message-service (3000): Conversation/Message/Inbox/WebSocket
  -> media-service (8083): Upload media + sticker APIs

Shared infrastructure: PostgreSQL 16 + Redis 7
JWT HS512 được chia sẻ giữa các service chính
```

### Bản đồ service

| Service | Port | Công nghệ | Trạng thái |
|---|---:|---|---|
| core-service | 8081 | Spring Boot 3.4 (Java 21) | ✅ Complete |
| message-service | 3000 | NestJS 11 (Node.js 20+) | ✅ Complete |
| media-service | 8083 | Spring Boot 3.4 (Java 21) | 🔄 In Progress |
| realtime-gateway | 8085 | NestJS (Node.js 20+) | 🔄 In Progress |
| moderation-service | 8082 | Spring Boot 3.4 (Java 21) | 🔄 In Progress |
| content-service | 8086 | Spring Boot (scaffold) | 🧪 Scaffolded |
| notification-service | 8087 | Spring Boot (scaffold) | 🧪 Scaffolded |
| ai-service | 8094 | Spring Boot 3.4 (Java 21) | 🧪 Experimental |
| analytics-service | 8084 (compose profile) | Spring Boot (planned) | ⏳ Planned |

---

## 🚀 Bắt Đầu Nhanh

### Yêu cầu

```bash
Java 21+
Node.js 20+
Docker + Docker Compose
Git
# Tùy chọn cho mobile:
Flutter 3.x
```

### Chạy local nhanh

```bash
# 1) Clone
git clone https://github.com/CNM-DHKTPM18A-2526/CNM-ZALO.git
cd CNM-ZALO

# 2) Khởi động hạ tầng (infra-only)
docker compose -f docker/docker-compose.infra.yml up -d

# 3) Chạy core-service (Terminal 1)
cd backend/java-services/services/core-service
./mvnw spring-boot:run

# 4) Chạy message-service (Terminal 2)
cd ../../../../backend/node-services
npm install
npm run start:dev

# 5) (Tùy chọn) Chạy mobile
cd ../../frontend/mobile
flutter pub get
flutter run --dart-define=ENV=dev --dart-define=CORE_SERVICE_URL=http://<LAN_IP>:8081/api/v1
```

### Health checks

- core-service: http://localhost:8081/api/v1/actuator/health
- message-service: http://localhost:3000/api/v1/health
- media-service: http://localhost:8083/actuator/health
- moderation-service: http://localhost:8082/api/v1/actuator/health

---

## 📁 Cấu Trúc Dự Án

```text
CNM-ZALO/
├── README.md
├── README.vi.md
├── docs/
│   ├── README.md
│   ├── system/
│   └── project/
├── backend/
│   ├── java-services/services/
│   │   ├── core-service
│   │   ├── media-service
│   │   ├── moderation-service
│   │   ├── content-service
│   │   ├── notification-service
│   │   └── ai-service
│   └── node-services/apps/
│       ├── message-service
│       └── realtime-gateway
├── frontend/mobile/
└── docker/
    ├── docker-compose.yml
    ├── docker-compose.infra.yml
    └── init-db.sql
```

---

## 🔧 Phát Triển

### core-service

```bash
cd backend/java-services/services/core-service
./mvnw clean install -DskipTests
./mvnw test
```

### node-services

```bash
cd backend/node-services
npm install
npm run start:dev
npm run test
npm run test:e2e
```

### mobile

```bash
cd frontend/mobile
flutter test
flutter run -d <device_id> --dart-define=ENV=dev --dart-define=CORE_SERVICE_URL=http://<LAN_IP>:8081/api/v1
```

### Flyway migration

- V1 -> V13 (quản lý bởi `core-service`).
- `message-service` đang dùng PostgreSQL + schema Flyway; **không dùng Cassandra trong runtime hiện tại**.

---

## 📖 Tài Liệu

| Tài liệu | Nội dung |
|---|---|
| [docs/README.md](docs/README.md) | Index toàn bộ tài liệu |
| [docs/system/architecture.md](docs/system/architecture.md) | Kiến trúc và service map |
| [docs/system/api-reference.md](docs/system/api-reference.md) | REST + WebSocket contracts |
| [docs/system/database-schema.md](docs/system/database-schema.md) | Schema tổng hợp + note reconcile |
| [docs/project/status.md](docs/project/status.md) | Trạng thái implementation hiện tại |
| [docs/project/changelog.md](docs/project/changelog.md) | Lịch sử thay đổi |
| [docs/project/team-assignment.md](docs/project/team-assignment.md) | Team ownership |

---

## 📊 Trạng Thái Hệ Thống

| Nhóm | Trạng thái |
|---|---|
| Core auth/user/social | ✅ Complete |
| Messaging + WebSocket | ✅ Complete |
| Media upload/sticker | 🔄 In Progress |
| Moderation workflow | 🔄 In Progress |
| Realtime scaling gateway | 🔄 In Progress |
| Content/Notification services | 🧪 Scaffolded |
| AI assistant service | 🧪 Experimental |
| Analytics service | ⏳ Planned |

---

## 🤝 Đóng Góp

- Dùng Conventional Commits (`feat`, `fix`, `docs`, `test`, `chore`).
- Tạo branch riêng, mở Pull Request về `main`.
- Trước khi merge: pass test + cập nhật tài liệu liên quan.

Tham khảo: [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 Giấy Phép

Dự án sử dụng [MIT License](LICENSE).
