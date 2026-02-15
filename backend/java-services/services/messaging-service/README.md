# 💬 Messaging Service

Messaging microservice cho **VNALO** — quản lý conversations, messages (Cassandra), calls (WebRTC signaling), notifications (FCM push), và message metadata (reactions, pins, polls).

---

## 📦 Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| Java | 21 | Runtime |
| Spring Boot | 3.4.2 | Framework |
| PostgreSQL | 16+ | Relational data (conversations, calls, notifications, metadata) |
| Apache Cassandra | 4+ | High-volume message storage |
| Redis | 7+ | Cache / Sessions |
| Kafka | 3+ | Event streaming (production) |
| Firebase Admin SDK | 9.4.3 | Push notifications (FCM) |
| WebSocket (STOMP) | — | Real-time messaging + WebRTC signaling |
| Flyway | — | DB migrations (production) |
| SpringDoc OpenAPI | 2.8.4 | Swagger UI |
| Lombok | — | Boilerplate reduction |

---

## ✅ Prerequisites

- **Java 21** (JDK)
- **Docker** (recommended for infrastructure services)
- **Maven** (or use included `mvnw` wrapper)

### Infrastructure Services

| Service | Default | Required |
|---|---|---|
| PostgreSQL | `localhost:5432` / `vnalo_core` | ✅ Bắt buộc |
| Cassandra | `localhost:9042` / `vnalo_messaging` | ✅ Bắt buộc |
| Redis | `localhost:6379` | ⚠️ Cần cho cache |
| Kafka | `localhost:9092` | ❌ Không cần ở dev |
| Firebase | Service account JSON | ❌ Optional (cho push notification) |

---

## 🚀 Quick Start

### 1. Khởi động infrastructure bằng Docker

```bash
# PostgreSQL
docker run -d --name postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=sapassword -e POSTGRES_DB=vnalo_messaging -p 5432:5432 postgres:16


# Cassandra
docker run -d --name cassandra -p 9042:9042 cassandra:4.1

# Chờ Cassandra khởi động (~30-60 giây), sau đó tạo keyspace
docker exec -it cassandra cqlsh -e "CREATE KEYSPACE IF NOT EXISTS vnalo_messaging WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"

#sau đó chạy 
docker exec -it cassandra cqlsh -e "DESCRIBE KEYSPACES;"
# để kiểm tra keyspace vnalo_messaging đã tồn tại hay chưa, nếu chưa thì chạy lại lệnh 
docker exec -it cassandra cqlsh -e "CREATE KEYSPACE IF NOT EXISTS vnalo_messaging WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};"
# và kiểm tra lại

# Redis
docker run -d --name redis -p 6379:6379 redis:7-alpine

# Kafka & Zookeeper (Optional - Chỉ cần khi chạy PROD hoặc test load)
# 1. Chạy Zookeeper
docker run -d --name zookeeper -p 2181:2181 -e ALLOW_ANONYMOUS_LOGIN=yes bitnami/zookeeper:latest

# 2. Chạy Kafka Broker (link với Zookeeper)
docker run -d --name kafka -p 9092:9092 -e KAFKA_BROKER_ID=1 -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092 -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 -e KAFKA_CFG_ZOOKEEPER_CONNECT=zookeeper:2181 -e ALLOW_PLAINTEXT_LISTENER=yes --link zookeeper bitnami/kafka:latest

```

### 2. Build & Run

```bash
cd backend/java-services/services/messaging-service

# Build
./mvnw clean compile

# Run (dev profile — tự tạo tables, không cần Kafka/Flyway)
./mvnw spring-boot:run

# Hoặc chạy với custom config
DB_HOST=localhost DB_PASS=mypassword ./mvnw spring-boot:run
```

### 3. Kiểm tra

- **Health check:** http://localhost:8082/api/v1/actuator/health
- **Swagger UI:** http://localhost:8082/api/v1/swagger-ui.html
- **API Docs:** http://localhost:8082/api/v1/v3/api-docs

---

## ⚙️ Configuration

File config: `src/main/resources/application.yml`

### Environment Variables

| Variable | Default | Mô tả |
|---|---|---|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `messaging` | PostgreSQL database |
| `DB_USER` | `postgres` | PostgreSQL username |
| `DB_PASS` | `sapassword` | PostgreSQL password |
| `CASSANDRA_HOST` | `localhost` | Cassandra contact points |
| `CASSANDRA_PORT` | `9042` | Cassandra port |
| `CASSANDRA_KEYSPACE` | `vnalo_messaging` | Cassandra keyspace |
| `CASSANDRA_DC` | `datacenter1` | Cassandra datacenter |
| `REDIS_HOST` | `localhost` | Redis host |
| `REDIS_PORT` | `6379` | Redis port |
| `KAFKA_SERVERS` | `localhost:9092` | Kafka bootstrap servers |
| `JWT_SECRET` | (dev key) | JWT signing key (Base64, min 512-bit) |
| `JWT_ISSUER` | `vnalo` | JWT issuer |
| `FIREBASE_CONFIG_PATH` | (none) | Path to Firebase service account JSON |
| `LOG_LEVEL` | `INFO` | Logging level |

### Profiles

| Profile | ddl-auto | Flyway | Kafka | Swagger | SQL Logging |
|---|---|---|---|---|---|
| **`dev`** (mặc định) | `update` | ❌ | ❌ | ✅ | ✅ |
| **`prod`** | `validate` | ✅ | ✅ | ❌ | ❌ |

---

## 🔥 Firebase (FCM Push Notification)

Firebase dùng để gửi push notification tới điện thoại/trình duyệt ngay cả khi app không mở.

### Setup

1. Vào [Firebase Console](https://console.firebase.google.com/) → Tạo project
2. **Project Settings** → **Service Accounts** → Chọn **Java** (Admin SDK configuration snippet)
3. Click **Generate New Private Key** → Tải file JSON về.
4. Đổi tên file thành `firebase-service-account.json`.
5. Đặt vào 1 trong 2 nơi:

```bash
# Cách 1: Đặt trong resources (dev)
cp firebase-service-account.json src/main/resources/

# Cách 2: Đặt bất kỳ đâu và set env (production)
export FIREBASE_CONFIG_PATH=/etc/vnalo/firebase-service-account.json
```

> **Lưu ý:** Nếu chưa config Firebase, app vẫn chạy bình thường — chỉ skip push notification.

### Tính năng FCM

| Method | Mô tả |
|---|---|
| `sendPushToUser(userId, ...)` | Push tới tất cả device tokens active của user |
| `sendToToken(fcmToken, ...)` | Push tới 1 FCM token cụ thể |
| `sendToMultipleTokens(tokens, ...)` | Batch push nhiều tokens |

Platform-specific: Android (high priority, sound), iOS (sound, badge), Web (icon).

---

## 🗄 Database Architecture

### Dual-Database Design

```
┌─────────────────┐     ┌──────────────────┐
│   PostgreSQL     │     │    Cassandra      │
│                  │     │                   │
│ • Conversations  │     │ • Messages        │
│ • Members        │     │   (high-volume)   │
│ • Inbox          │     │                   │
│ • Reactions      │     │ Partition key:    │
│ • Pins           │     │   conversation_id │
│ • Polls          │     │ Clustering:       │
│ • Calls          │     │   created_at DESC │
│ • Notifications  │     │   message_id DESC │
│ • Device Tokens  │     │                   │
└─────────────────┘     └──────────────────┘
```

### Conversation Domain (6 tables — PostgreSQL)

| Table | Primary Key | Mô tả |
|---|---|---|
| `conversation` | `conversation_id` (UUID) | Cuộc trò chuyện (DIRECT/GROUP) |
| `conversation_member` | (`conversation_id`, `user_id`) | Thành viên + role + settings |
| `conversation_inbox` | (`user_id`, `conversation_id`) | Hộp thư đến + unread count |
| `conversation_direct_map` | (`user_id_1`, `user_id_2`) | Mapping chat 1-1 (tránh duplicate) |
| `group_join_request` | `request_id` (UUID) | Yêu cầu tham gia nhóm |
| `group_banned_member` | (`conversation_id`, `user_id`) | Thành viên bị cấm |

### Message Domain (Cassandra + PostgreSQL)

| Table | Database | Primary Key | Mô tả |
|---|---|---|---|
| `message` | **Cassandra** | Partition: `conversation_id`, Cluster: `created_at` DESC, `message_id` DESC | Tin nhắn |
| `message_reaction` | PostgreSQL | `reaction_id` (UUID) | Reaction emoji |
| `pinned_message` | PostgreSQL | `pin_id` (UUID) | Tin nhắn ghim |
| `poll` | PostgreSQL | `poll_id` (UUID) | Bình chọn |
| `poll_option` | PostgreSQL | `option_id` (UUID) | Lựa chọn poll |
| `poll_vote` | PostgreSQL | `vote_id` (UUID) | Phiếu bầu |

### Call Domain (2 tables — PostgreSQL)

| Table | Primary Key | Mô tả |
|---|---|---|
| `call_session` | `call_id` (UUID) | Phiên gọi (VOICE/VIDEO) |
| `call_participant` | `participant_id` (UUID) | Người tham gia cuộc gọi |

### Notification Domain (2 tables — PostgreSQL)

| Table | Primary Key | Mô tả |
|---|---|---|
| `notification` | `notification_id` (UUID) | Thông báo hệ thống |
| `device_token` | `device_id` (String) | FCM device token |

---

## 🌐 API Endpoints

**Base URL:** `http://localhost:8082/api/v1`

### 📋 Conversations — `/conversations`

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `POST` | `/` | Tạo conversation (DIRECT/GROUP) | ✅ |
| `GET` | `/` | Lấy inbox của user | ✅ |
| `GET` | `/{id}` | Chi tiết conversation | ✅ |
| `PATCH` | `/{id}` | Cập nhật thông tin | ✅ Admin |
| `POST` | `/{id}/leave` | Rời conversation | ✅ |
| `GET` | `/{id}/members` | Danh sách thành viên | ✅ |
| `POST` | `/{id}/members` | Thêm thành viên | ✅ |
| `DELETE` | `/{id}/members/{userId}` | Xóa thành viên | ✅ Admin |
| `PUT` | `/{id}/members/{userId}/role` | Đổi role thành viên | ✅ Admin |
| `POST` | `/{id}/banned-members/{userId}` | Ban thành viên | ✅ Admin |
| `DELETE` | `/{id}/banned-members/{userId}` | Unban thành viên | ✅ Admin |
| `GET` | `/{id}/banned-members` | Danh sách bị ban | ✅ Admin |
| `POST` | `/{id}/join-requests` | Yêu cầu tham gia nhóm | ✅ |
| `POST` | `/{id}/join-requests/{reqId}/approve` | Duyệt yêu cầu | ✅ Admin |
| `POST` | `/{id}/join-requests/{reqId}/reject` | Từ chối yêu cầu | ✅ Admin |
| `GET` | `/{id}/join-requests` | Danh sách yêu cầu chờ | ✅ Admin |

### 💬 Messages — `/messages`

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `POST` | `/` | Gửi tin nhắn (→ Cassandra + WebSocket) | ✅ |
| `GET` | `/conversations/{id}` | Lịch sử tin nhắn (phân trang Slice) | ✅ |
| `DELETE` | `/{messageId}` | Thu hồi tin nhắn (soft delete) | ✅ Sender |

### ⭐ Message Metadata — `/conversations/{id}/messages`

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `POST` | `/reactions` | Thêm reaction | ✅ |
| `DELETE` | `/{msgId}/reactions` | Xóa reaction | ✅ |
| `GET` | `/{msgId}/reactions` | Danh sách reactions | ✅ |
| `POST` | `/{msgId}/pin` | Ghim tin nhắn | ✅ |
| `DELETE` | `/{msgId}/pin` | Bỏ ghim | ✅ |
| `GET` | `/pinned` | Danh sách tin ghim | ✅ |
| `POST` | `/polls` | Tạo bình chọn | ✅ |
| `POST` | `/polls/{pollId}/vote` | Bỏ phiếu | ✅ |
| `GET` | `/polls/{pollId}` | Kết quả bình chọn | ✅ |

### 📞 Calls — `/calls`

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `POST` | `/` | Bắt đầu cuộc gọi | ✅ |
| `POST` | `/{callId}/answer` | Nhận cuộc gọi | ✅ |
| `POST` | `/{callId}/end` | Kết thúc cuộc gọi | ✅ |
| `POST` | `/{callId}/decline` | Từ chối cuộc gọi | ✅ |
| `GET` | `/{callId}` | Chi tiết cuộc gọi | ✅ |
| `GET` | `/conversations/{id}/history` | Lịch sử cuộc gọi | ✅ |

### 🔔 Notifications — `/notifications`

| Method | Endpoint | Mô tả | Auth |
|---|---|---|---|
| `GET` | `/` | Tất cả thông báo | ✅ |
| `GET` | `/unread` | Thông báo chưa đọc | ✅ |
| `GET` | `/unread/count` | Đếm chưa đọc | ✅ |
| `PATCH` | `/{id}/read` | Đánh dấu đã đọc | ✅ |
| `PATCH` | `/read-all` | Đánh dấu tất cả đã đọc | ✅ |
| `POST` | `/device-token` | Đăng ký FCM token | ✅ |
| `DELETE` | `/device-token/{deviceId}` | Xóa device token | ✅ |

---

## 🔌 WebSocket

**Endpoint:** `ws://localhost:8082/api/v1/ws`

Hỗ trợ cả **SockJS** và **raw WebSocket**.

### Authentication

Gửi JWT token trong STOMP CONNECT headers:
```
Authorization: Bearer <token>
```
hoặc:
```
token: <token>
```

### Subscribe Topics

| Topic | Events | Mô tả |
|---|---|---|
| `/topic/conversation/{id}` | `NEW_MESSAGE` | Tin nhắn mới trong conversation |
| `/topic/user/{userId}` | `WEBRTC_SIGNAL`, notifications | Sự kiện cá nhân (call signaling, thông báo) |

### WebRTC Call Signaling

Signaling cho cuộc gọi WebRTC qua STOMP WebSocket:

```
Send:      /app/call.signal
Receive:   /topic/user/{targetUserId}
```

**Flow:**
```
1. Caller gửi OFFER     → Server relay → /topic/user/{callee}
2. Callee gửi ANSWER    → Server relay → /topic/user/{caller}
3. Cả 2 trao đổi ICE_CANDIDATE → Server relay → peer
4. Bất kỳ ai gửi HANGUP → Server relay → peer
```

**Signal payload:**
```json
{
  "callId": "uuid",
  "targetUserId": "uuid",
  "type": "OFFER | ANSWER | ICE_CANDIDATE | HANGUP",
  "payload": "SDP string hoặc ICE candidate JSON"
}
```

### Frontend Example (SockJS + STOMP)

```javascript
const socket = new SockJS('http://localhost:8082/api/v1/ws');
const client = Stomp.over(socket);

client.connect({ 'Authorization': 'Bearer ' + jwt }, () => {
    // Subscribe tin nhắn mới
    client.subscribe('/topic/conversation/' + conversationId, (msg) => {
        const event = JSON.parse(msg.body);
        console.log(event.type, event.data);
    });

    // Subscribe WebRTC signaling
    client.subscribe('/topic/user/' + myUserId, (msg) => {
        const event = JSON.parse(msg.body);
        if (event.type === 'WEBRTC_SIGNAL') {
            handleWebRTCSignal(event.data);
        }
    });

    // Gửi WebRTC offer
    client.send('/app/call.signal', {}, JSON.stringify({
        callId: callId,
        targetUserId: targetUserId,
        type: 'OFFER',
        payload: sdpOffer
    }));
});
```

---

## 📂 Project Structure

```
src/main/java/iuh/cnm/vnalo/messagingservice/
├── config/              # WebSocket, Security, CORS, Firebase, OpenAPI
├── security/            # JWT filter & token provider
├── exceptions/          # ErrorCode (33 codes), ApiException, GlobalHandler
├── model/
│   ├── entity/          # JPA entities (15) + Cassandra entity (1)
│   │   ├── conversation/    # Conversation, Member, Inbox, DirectMap, BannedMember, JoinRequest
│   │   ├── message/         # Message (Cassandra)
│   │   ├── call/            # CallSession, CallParticipant
│   │   └── notification/    # Notification, DeviceToken
│   ├── enums/           # 18 enums across 4 domains
│   └── dto/             # Request & Response DTOs
├── repository/          # Spring Data JPA (15) + Cassandra (1)
├── service/             # Business logic (7 services)
│   ├── ConversationService      # CRUD, members, ban, join requests
│   ├── MessageService           # Send/get/delete (Cassandra)
│   ├── MessageMetadataService   # Reactions, pins, polls
│   ├── CallService              # Call lifecycle management
│   ├── NotificationService      # Notifications + device tokens
│   ├── FirebasePushService      # FCM push notifications
│   └── WebSocketEventService    # Real-time event broadcasting
└── controller/          # REST + WebSocket controllers
    ├── ConversationController   # 16 endpoints
    ├── MessageController        # 3 endpoints
    ├── MessageMetadataController # 9 endpoints
    ├── CallController           # 6 endpoints
    ├── NotificationController   # 7 endpoints
    └── CallSignalingController  # WebRTC STOMP signaling
```

---

## 🔐 Authentication

Tất cả endpoints yêu cầu JWT token trong header:
```
Authorization: Bearer <token>
```

Token được **validate only** — do `core-service` cấp phát. Messaging service chỉ verify.

---

## 🏗 Build & Deploy

```bash
# Compile
./mvnw clean compile

# Package (skip tests)
./mvnw clean package -DskipTests

# Run với dev profile (mặc định)
./mvnw spring-boot:run

# Run với prod profile
SPRING_PROFILES_ACTIVE=prod \
  DB_HOST=db.production.com \
  DB_PASS=secret \
  JWT_SECRET=<base64-key> \
  CASSANDRA_HOST=cassandra.production.com \
  FIREBASE_CONFIG_PATH=/etc/vnalo/firebase.json \
  java -jar target/messaging-service-0.0.1-SNAPSHOT.jar
```

### Docker (Production)

```bash
# Build image
docker build -t vnalo/messaging-service .

# Run
docker run -d \
  -p 8082:8082 \
  -e DB_HOST=postgres \
  -e DB_PASS=secret \
  -e JWT_SECRET=<key> \
  -e CASSANDRA_HOST=cassandra \
  -e REDIS_HOST=redis \
  -e KAFKA_SERVERS=kafka:9092 \
  -e FIREBASE_CONFIG_PATH=/config/firebase.json \
  -v /path/to/firebase.json:/config/firebase.json \
  vnalo/messaging-service
```

---

## 📊 Monitoring

| Endpoint | Mô tả |
|---|---|
| `/actuator/health` | Health check |
| `/actuator/info` | App info |
| `/actuator/metrics` | Metrics |
| `/actuator/prometheus` | Prometheus metrics |

---

## 🔢 Error Codes

| Code | Mô tả |
|---|---|
| `CONV_001` — `CONV_013` | Conversation errors (not found, permission, banned, join request) |
| `MSG_001` — `MSG_005` | Message errors (not found, not sender, deleted, pinned) |
| `REACT_001` — `REACT_002` | Reaction errors |
| `POLL_001` — `POLL_004` | Poll errors |
| `CALL_001` — `CALL_005` | Call errors (not found, ongoing, busy) |
| `NOTIF_001` — `NOTIF_002` | Notification errors |

Tất cả error responses trả về format:
```json
{
  "success": false,
  "error": {
    "code": "CONV_003",
    "message": "You are not a member of this conversation"
  }
}
```

---

## 🐘 Cassandra Cheatsheet

**Q: Có cần cài Cassandra trên máy không?**
**A: KHÔNG.** Bạn chỉ cần chạy qua Docker là đủ. App sẽ kết nối tới container Docker.

### 1. Truy cập CQLSH (Cassandra Shell)

Để gõ lệnh database, chạy lệnh sau trong terminal:

```bash
docker exec -it cassandra cqlsh
```

### 2. Các lệnh cơ bản

```sql
-- Xem tất cả keyspaces
DESCRIBE KEYSPACES;

-- Sử dụng keyspace của app
USE vnalo_messaging;

-- Xem các bảng
DESCRIBE TABLES;

-- Xem cấu trúc bảng message
DESCRIBE TABLE message;
```

### 3. CRUD & Filtering Data

**Lưu ý quan trọng:** Cassandra không phải là SQL. Bạn chỉ có thể filter (WHERE) theo các cột trong **Primary Key** hoặc cột có **Index**.
Primary Key của bảng `message`: `((conversation_id), created_at, message_id)`
- Partition Key: `conversation_id` (Bắt buộc phải có trong WHERE)
- Clustering Keys: `created_at`, `message_id` (Dùng để sort hoặc filter range)

#### ✅ SELECT (Đúng cách)

```sql
-- 1. Lấy tất cả tin nhắn của 1 cuộc trò chuyện (BẮT BUỘC có conversation_id)
SELECT * FROM message WHERE conversation_id = 550e8400-e29b-41d4-a716-446655440000;

-- 2. Lấy tin nhắn mới nhất (Cassandra đã sắp xếp sẵn DESC theo created_at)
SELECT * FROM message WHERE conversation_id = ... LIMIT 10;

-- 3. Lọc theo thời gian (cần allow filtering nếu không đầy đủ key, nhưng tốt nhất là theo cluster key)
SELECT * FROM message 
WHERE conversation_id = ... 
AND created_at > '2024-01-01 00:00:00';
```

#### ❌ SELECT (Sai cách - Sẽ báo lỗi)

```sql
-- KHÔNG THỂ query mà không có conversation_id
SELECT * FROM message WHERE sender_id = ...; -- LỖI: Cần allow filtering (chậm)

-- KHÔNG THỂ sort ngược chiều định nghĩa (trừ khi query rất cụ thể)
SELECT * FROM message WHERE conversation_id = ... ORDER BY created_at ASC; -- LỖI (mặc định là DESC)
```

#### INSERT (Thêm dữ liệu)

```sql
INSERT INTO message (conversation_id, created_at, message_id, sender_id, content, type, status)
VALUES (
  550e8400-e29b-41d4-a716-446655440000, 
  toTimestamp(now()), 
  uuid(), 
  550e8400-e29b-41d4-a716-446655440001, 
  'Xin chào Cassandra!', 
  'TEXT', 
  'SENT'
);
```

#### UPDATE (Sửa dữ liệu)

Trong Cassandra, INSERT trùng Primary Key = UPDATE.

```sql
-- Đổi trạng thái tin nhắn thành READ
UPDATE message SET status = 'READ' 
WHERE conversation_id = ... 
AND created_at = ... 
AND message_id = ...;
```

#### DELETE (Xóa dữ liệu)

```sql
-- Xóa 1 tin nhắn cụ thể (Soft delete thường được dùng hơn trong app thực tế)
DELETE FROM message 
WHERE conversation_id = ... 
AND created_at = ... 
AND message_id = ...;
```

#### TRUNCATE (Xóa sạch dữ liệu bảng)

```sql
TRUNCATE message;
```
