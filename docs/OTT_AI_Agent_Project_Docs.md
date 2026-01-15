# OTT Zalo-like System — AI Agent Project Documentation (Detailed)

> **Purpose**: This document is a **single source of truth** for an AI coding agent (and humans) to understand, implement, and operate a Zalo-like OTT system with **microservices + realtime gateway**, **Firebase Phone Auth (SMS OTP)**, **hybrid AI Assistant (Gemini API + Ollama fallback)**, and **analytics**.
>
> **Scope**: This doc covers **backend microservices boundaries**, data stores, event topics, APIs, contracts, local dev setup, and operational runbooks.
>
> **Related Documents**:
> - [Database Design By Service](./OTT_Zalo_Database_Design_By_Service.md) — Chi tiết schema theo từng service
> - [Feedback v4](./Feedback_v4_ServerSeq_ZaloLike_Microservices.md) — Latest decisions (serverSeq, multi-device)

---

## 0) Architecture & Key Decisions

> **System Architecture: Microservices**
> 
> Hệ thống được thiết kế theo hướng **giống Zalo nhất** với kiến trúc **microservices**.

### Key Architectural Decisions (MUST READ)

| Decision | Choice | Rationale |
|----------|--------|----------|
| **D8: Message Ordering** | `serverSeq` per conversation | Tránh trùng timestamp, ordering ổn định |
| **D9: Receipt Semantics** | User-level (any-device) | Giống Zalo: delivered/seen khi bất kỳ device nào nhận/đọc |
| **D10: Cursor Format** | Per use case: message history `{convId,lastSeq}`, conversation list `{lastMessageSeq,lastConversationId}` | Tránh nhầm lẫn giữa các loại pagination |
| **D11: Metadata Ownership** | Message Service owns unread/lastMessage | Single source of truth |
| **D12: Idempotency Key** | `clientMessageId` (persistent store + Redis) | Reliable hơn TTL-based dedupe |

### Production Mode (Default — Zalo-like)

| Component | Choice | Rationale |
|-----------|--------|----------|
| **Architecture** | Microservices | Independent scaling, clear boundaries |
| **Database** | PostgreSQL + Cassandra | Polyglot persistence |
| **Message Storage** | Cassandra/ScyllaDB | High write throughput |
| **Event Bus** | Apache Kafka | Reliable async processing |
| **Media Storage** | S3 + CloudFront | Global CDN |
| **Realtime** | Netty Gateway | 100K+ connections |
| **Ordering** | `serverSeq` per conversation | Monotonic, no timestamp collision |

### MVP Mode (Optional reference — Team 4 người, 8 tuần)

| Component | MVP Choice | Rationale |
|-----------|------------|-----------|
| **Architecture** | Modular Monolith | Đơn giản, dễ debug, deploy nhanh |
| **Database** | PostgreSQL only | Đủ cho < 100K users, dễ maintain |
| **Message Storage** | PostgreSQL với index tốt | Không cần Cassandra cho MVP |
| **Event Bus** | Kafka (optional) hoặc direct call | Có thể bỏ Kafka nếu cần đơn giản |
| **Media Storage** | MinIO local / Firebase Storage | Không cần S3 + CloudFront |
| **Realtime** | Spring WebSocket hoặc Netty | Spring WebSocket dễ hơn |
| **AI Service** | Bỏ hoàn toàn | Không phải core feature |

### Production Mode (Scale — 1M+ DAU)

| Component | Production Choice | Rationale |
|-----------|-------------------|-----------|
| **Architecture** | Microservices | Independent scaling |
| **Database** | PostgreSQL + Cassandra | Polyglot persistence |
| **Message Storage** | Cassandra/ScyllaDB | High write throughput |
| **Event Bus** | Apache Kafka (MSK) | Reliable async processing |
| **Media Storage** | S3 + CloudFront | Global CDN |
| **Realtime** | Netty Gateway | 100K+ connections |
| **AI Service** | Gemini + Ollama fallback | Full feature |

---

## 0.1) Quick Start (What to read first)

1. **Architecture & Key Decisions** → Section 0
2. **Architecture overview** → Section 1
3. **Microservices list & responsibilities** → Section 2
4. **Realtime Gateway behavior (ACK/Presence/Sync)** → Section 3
5. **Data model & storage strategy** → Section 4
6. **Kafka topics & events** → Section 5
7. **API surface (REST + Realtime events)** → Section 6
8. **Auth flow (Firebase → internal JWT)** → Section 7
9. **AI Assistant hybrid routing & fallback** → Section 8
10. **Deployment on AWS (EKS + ALB/NLB + S3/CloudFront)** → Section 9
11. **Local development & troubleshooting** → Section 10

---

## 1) System Overview

### 1.1 Goals

- Deliver a **Zalo-like OTT** experience: account + friends/groups + 1–1 & group chat + media + notifications.
- Provide a **Realtime messaging** path with low latency.
- Use an **event-driven pipeline** for heavy/async tasks: persistence, thumbnails, push, analytics.
- Provide **AI Assistant** in a controlled scope, with privacy and availability guarantees.

### 1.2 Key Functional Modules (16 Microservices)

**Core Services:**
- Account/Auth (Phone OTP), Profile, Device sessions
- Social Graph (friend requests, friendship, block, contact sync)
- Messaging core (conversations, participants, messages, receipts, reactions)
- Realtime Gateway (WebSocket, routing, ACK/retry, presence, call signaling)

**Communication Services:**
- Message Service (text, image, video, file, voice, sticker, poll)
- Call Service (voice/video 1:1 and group calls via WebRTC)
- Notification Service (push to offline devices via FCM/APNs)

**Content Services:**
- Media Service (upload via presigned URL, thumbnails, processing)
- Sticker Service (sticker packs, AI-generated stickers)
- Story Service (24h stories, views, reactions, highlights)
- Timeline Service (newsfeed posts, likes, comments, shares)

**Utility Services:**
- QR & Link Service (personal QR, group invites, short links)
- Analytics Service (DAU/WAU/MAU, usage metrics)
- AI Service (Gemini + Ollama hybrid, smart reply, translation)
- Backup Service (local backup, export/import chat history, restore)
- Moderation Service (reports, admin actions, user warnings)

> **⚠️ Excluded Features (Out of Scope):**
> - ZaloPay / E-wallet / Payments
> - Mini Apps / Third-party apps
> - Official Account / Business accounts

### 1.3 Non-Functional Requirements (NFR)

- **Low-latency** realtime messaging.
- **Scalability**: independent scaling for gateway and microservices.
- **Reliability**: ACK/retry, reconnect, DLQ for async pipelines.
- **Security**: HTTPS/WSS, internal JWT, rate limiting.
- **Privacy**: AI features are opt-in for chat context; minimal logging.

---

## 2) Backend Microservices (Boundaries & Responsibilities)

> The backend uses **Spring Boot microservices** for business logic and a **Netty Realtime Gateway** for long-lived WebSocket connections.

### 2.1 Microservices List (recommended boundaries)

1. **Auth Service**
   - Verify **Firebase ID token** (phone OTP)
   - Issue **internal JWT + refresh token**
   - Maintain token lifecycle, revocation lists (optional)

2. **User/Profile Service**
   - User profile CRUD: name, avatar, DOB, gender, privacy settings
   - User presence preferences (hide last seen, etc.)

3. **Device/Session (Merged into Auth Service)**
   - Track devices per account, remote logout
   - Store push tokens (FCM/APNs) per device
   - Detect "new device" (fingerprint / user-agent heuristic)

4. **Social Graph Service**
   - Friend requests
   - Friendship state
   - Block/unblock relations

5. **Conversation/Group Service**
   - Create conversations (1–1, group)
   - Manage participants
   - Group roles: Owner/Admin/Member
   - Conversation settings: mute/pin/hide (owned by Conversation Service)

6. **Message Service** (D11: Owns conversation metadata)
   - Consume message events from Kafka
   - Persist message history (Cassandra for production, PostgreSQL for MVP)
   - **Owns conversation metadata**: `last_message`, `last_message_seq`, `unread_count` per user
   - Receipt handling: Delivered/Seen at **user-level** (D9)
   - Idempotency: Dedupe by `clientMessageId` (D12)
   - Validates/uses `serverSeq` ordering (D8) — generated by Gateway for fast ACK

7. **Media Service**
   - Presigned URL issuance for uploads
   - Store metadata: objectKey, mimeType, size, checksum
   - Emit media processing jobs (thumbnail/compress)

8. **Notification Service**
   - Consume notification events
   - Send push to offline devices via FCM/APNs
   - Respect per-conversation mute settings

9. **Analytics Service**
   - Consume analytics events
   - Aggregate daily/weekly/monthly metrics
   - Serve admin dashboard APIs

10. **AI Service**
    - AI assistant chat endpoint
    - Provider routing: **Gemini first** (quality) → **Ollama fallback** (availability)
    - Rate limit and policy filters
    - Opt-in features: Quick Reply, Summary, zSticker AI

11. **Call Service** ⭐ NEW
    - Voice call (1:1 và group)
    - Video call (1:1 và group)
    - WebRTC signaling server
    - Call history tracking
    - Missed call notifications
    - Screen sharing support

12. **Story Service** ⭐ NEW (Zalo Nhật ký)
    - Story CRUD (ảnh, video, text với background)
    - 24-hour expiration
    - View tracking
    - Story reactions & replies
    - Close friends visibility
    - Story highlights

13. **Timeline Service** ⭐ NEW (Zalo Newsfeed)
    - Timeline posts (text, images, videos)
    - Like/React với 6 emoji types
    - Comments & replies
    - Tag friends
    - Share posts
    - Privacy settings per post

14. **Sticker Service** ⭐ NEW
    - Sticker pack management
    - User sticker downloads
    - Sticker usage tracking
    - zSticker AI generation
    - Animated stickers (Lottie)

15. **QR & Link Service** ⭐ NEW
    - Personal QR code generation
    - Group invite QR codes
    - Short links for sharing
    - QR scan tracking

16. **Backup Service** ⭐ NEW
    - Export chat history to local file (JSON/encrypted)
    - Import/restore from backup file
    - Selective backup (per conversation)
    - Backup scheduling (manual trigger)
    - Media backup (optional - large files)

17. **Moderation Service** ⭐ NEW
    - User reports (spam, harassment, inappropriate content)
    - Admin review workflow
    - User warnings & actions (lock, ban)
    - Admin action audit logs
    - Content moderation policies

> **Note**: Device/Session được merge vào Auth Service (item 3), nên tổng thực tế là **16 independent services**.

### 2.2 Cross-cutting Components

- **Realtime Gateway (Netty)**: connection management, routing, ACK, presence, call signaling
- **Kafka**: event streaming backbone
- **Redis**: presence/session mapping, rate limiting, caching
- **WebRTC TURN/STUN Server**: media relay for calls

---

## 3) Realtime Gateway (Netty + WebSocket + JSON)

> **Decision**: Sử dụng **JSON over WebSocket** (Production default). Protobuf là optional upgrade cho bandwidth/CPU optimization.

### 3.1 Responsibilities

- Maintain long-lived **WSS** connections
- Authenticate and bind `userId/deviceId` ↔ `connectionId`
- Route messages to:
  - all online devices of the recipient
  - all participants in a group
- Handle ACK states:
  - `Sent`: server ack to sender after validation & enqueue
  - `Delivered`: recipient device ack after receiving (được quy đổi thành **user-level** - D9)
  - `Seen`: recipient device ack after reading (được quy đổi thành **user-level** - D9)
- Presence tracking: online/offline/lastSeen in Redis
- Reconnect and sync:
  - client provides `lastSyncCursor`
  - server resends missed events/messages

> **Note (D9)**: Delivered/Seen ACK có thể được gửi từ 1 thiết bị, nhưng hệ thống ghi nhận theo **user-level** (bất kỳ device nào của user nhận/đọc).

### 3.2 Key Architectural Decisions

#### **Decision 1: Message ID & Ordering Generation**
> **Gateway generates `messageId`** (UUID), `serverSeq` (per-conversation sequence), và `serverTs` cho mỗi message được accept.

```
Client                    Gateway                    Kafka                    Message Service
   │                         │                         │                            │
   │── message_send ────────▶│                         │                            │
   │   (clientMessageId,     │                         │                            │
   │    content)             │                         │                            │
   │                         │── generate messageId ──▶│                            │
   │                         │── generate serverSeq ──▶│  (atomic per conversation) │
   │                         │── generate serverTs ───▶│                            │
   │                         │                         │                            │
   │                         │── publish event ───────▶│                            │
   │                         │   (messageId, serverSeq)│                            │
   │                         │                         │                            │
   │◀── message_sent_ack ────│                         │                            │
   │   (clientMessageId,     │                         │                            │
   │    messageId, serverSeq)│                         │                            │
   │                         │                         │── consume ───────────────▶│
   │                         │                         │                            │── persist to store
   │                         │                         │                            │   (consumer idempotent
   │                         │                         │                            │    by eventId/messageId;
   │                         │                         │                            │    business dedupe by
   │                         │                         │                            │    senderId+clientMessageId)
```

**Key Points:**
- **`serverSeq`**: Monotonic sequence number per conversation, atomic increment (Redis INCR hoặc DB sequence)
- **Ordering**: `ORDER BY serverSeq ASC` (UI display) hoặc `serverSeq DESC` (pagination)
- **Rationale**: Gateway có thể respond nhanh, không cần đợi Message Service
- **Idempotency**: Message Service dedupe bằng `clientMessageId` (Cassandra lookup table `message_idempotency_by_sender`)

**Gateway Idempotency Resolution:**
> **Critical**: Xử lý retry sau Redis cache expiration để tránh cấp serverSeq mới cho message duplicate

1. **Redis hit**: Trả về stored `(messageId, serverSeq)` từ cache
2. **Redis miss**: Query Message Service (hoặc idempotency store) bằng `(senderId, clientMessageId)`:
   - Nếu tìm thấy → trả về existing `(messageId, serverSeq)`
   - Nếu không tìm thấy → allocate new `serverSeq` và publish
3. **Cache mapping**: Lưu `dedup:msg:{senderId}:{clientMessageId} → {messageId, serverSeq}` với TTL >= 24h (hoặc 7d khớp lookup TTL)

> **Why**: Client retry sau cache expiration (muộn hơn) không được nhận ACK mới với serverSeq khác → tránh state mismatch

#### **Decision 2: Conversation Settings Ownership**
> **Conversation Service owns conversation settings** (mute/pin/hide).

- Notification Service **reads** settings từ cache/event, không tự query DB
- Settings được cache trong Redis với TTL 5 phút

#### **Decision 3: Cursor Format (Per Use Case)**

> **D10 Update**: Tách cursor format theo use case để tránh nhầm lẫn

**1) Message History Cursor** (load messages trong 1 conversation):
```json
{
  "cursor": "base64({\"convId\":\"uuid\",\"lastSeq\":12345})"
}
```
- **Pagination (load more)**: `serverSeq < lastSeq` với `ORDER BY serverSeq DESC LIMIT N`
- **Sync (missed messages)**: `serverSeq > lastSeq` với `ORDER BY serverSeq ASC`
- **Không cần tie-breaker**: `serverSeq` là unique per conversation

**2) Conversation List Cursor** (load danh sách conversations):
```json
{
  "cursor": "base64({\"lastMessageSeq\":12345,\"lastConversationId\":\"uuid\"})"
}
```
- **Sort**: Conversations sort theo `last_message_seq DESC, conversation_id DESC`
- **Pagination**: `WHERE (last_message_seq < ? OR (last_message_seq = ? AND conversation_id < ?))`
- **Alternative**: Có thể dùng `lastUpdatedAt` thay `lastMessageSeq` nếu store `updated_at`

**3) Multi-conversation Sync**:
- Client gửi array of `{convId, lastSeq}` pairs cho từng conversation

### 3.3 WebSocket Message Envelope (JSON)

**Client → Gateway: `message_send`**
```json
{
  "type": "message_send",
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "ts": 1704067200000,
  "payload": {
    "conversationId": "uuid",
    "clientMessageId": "client-generated-uuid",
    "messageType": "text",
    "content": "Hello!"
  }
}
```

**Gateway → Client: `message_sent_ack`**
```json
{
  "type": "message_sent_ack",
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "ts": 1704067200001,
  "payload": {
    "clientMessageId": "client-generated-uuid",
    "messageId": "server-generated-uuid",
    "serverSeq": 12345,
    "serverTs": 1704067200001
  }
}
```

**Gateway → Client: `message_receive`**
```json
{
  "type": "message_receive",
  "ts": 1704067200001,
  "payload": {
    "messageId": "uuid",
    "conversationId": "uuid",
    "senderId": "uuid",
    "serverSeq": 12345,
    "serverTs": 1704067200001,
    "messageType": "text",
    "content": "Hello!"
  }
}
```

#### Allowed `type` values:

**Client → Gateway:**
| Type | Description |
|------|-------------|
| `message_send` | Gửi tin nhắn mới (với `clientMessageId`) |
| `message_delivered` | ACK đã nhận tin nhắn |
| `message_seen` | ACK đã đọc tin nhắn |
| `typing_start` | Bắt đầu typing |
| `typing_stop` | Dừng typing |
| `presence_subscribe` | Subscribe presence của users |
| `sync_request` | Request sync messages từ cursor (`{convId, lastSeq}`) |

**Gateway → Client:**
| Type | Description |
|------|-------------|
| `message_receive` | Tin nhắn mới từ người khác (có `serverSeq`) |
| `message_sent_ack` | ACK tin nhắn đã được server nhận (có `serverSeq`) |
| `message_delivered_ack` | ACK tin nhắn đã delivered |
| `message_seen_ack` | ACK tin nhắn đã được đọc |
| `user_typing` | User đang typing |
| `presence_update` | User online/offline |
| `sync_response` | Response cho sync request |
| `error` | Error response |

### 3.4 ACK & Retry Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MESSAGE ACK FLOW (serverSeq)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Sender          Gateway              Kafka        Recipient(s)     │
│    │                │                   │              │             │
│    │─ message_send ▶│                   │              │             │
│    │ (clientMsgId)  │─ validate ───────▶│              │             │
│    │                │─ gen msgId ───────▶│              │             │
│    │                │─ gen serverSeq ───▶│ (atomic)    │             │
│    │                │─ publish ─────────▶│              │             │
│    │◀─ SENT ACK ────│                   │              │             │
│    │  (clientMsgId, │                   │              │             │
│    │   msgId, seq)  │                   │              │             │
│    │                │◀──────────────────│─ broadcast ─▶│             │
│    │                │                   │              │─ receive    │
│    │                │◀──────────────────│──────────────│─ DELIVERED  │
│    │◀─ DELIVERED ───│                   │              │ (user-level)│
│    │                │                   │              │             │
│    │                │◀──────────────────│──────────────│─ SEEN       │
│    │◀─ SEEN ────────│                   │              │ (user-level)│
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Key Flow Points:**
- Gateway responds với `message_sent_ack` **ngay sau khi publish Kafka thành công**
- ACK bao gồm: `clientMessageId` (matching), `messageId` (server), `serverSeq` (ordering)
- Client retry nếu không nhận ACK trong 5 giây (với cùng `clientMessageId`)
- Gateway dedupe bằng `clientMessageId` (Redis >=24h + persistent store = Cassandra lookup)
- **Delivered/Seen là user-level** (D9): chỉ cần 1 device nhận/đọc → mark cho user

---

## 4) Data Layer Strategy (Polyglot Persistence)

> **Xem chi tiết schema**: [OTT_Zalo_Database_Design_By_Service.md](./OTT_Zalo_Database_Design_By_Service.md)

### 4.0 Database Strategy by Project Mode

| Mode | Primary DB | Message Storage | Rationale |
|------|------------|-----------------|-----------|
| **MVP** | PostgreSQL | PostgreSQL | Single DB, dễ maintain, đủ cho < 100K users |
| **Production** | PostgreSQL | Cassandra/ScyllaDB | Polyglot persistence cho scale |

### 4.1 RDBMS (PostgreSQL) — Recommended

> **Decision**: Dùng **PostgreSQL** thay vì MySQL vì JSONB support tốt hơn.

Use for **strong consistency** and relational queries:

**Auth Service Database:**
- `auth_account` — Tài khoản đăng nhập
- `auth_refresh_token` — Refresh tokens
- `auth_otp` — OTP verification (optional)

**User Profile Service Database:**
- `user_profile` — Thông tin profile
- `user_privacy_setting` — Cài đặt riêng tư

**Social Graph Service Database:**
- `friend_request` — Lời mời kết bạn
- `friendship` — Quan hệ bạn bè
- `block_list` — Danh sách chặn

**Conversation Service Database:**
- `conversation` — Thông tin hội thoại
- `conversation_member` — Thành viên + settings (mute/pin/lastRead)
- `conversation_direct_map` — Tối ưu lookup 1:1 chat

**Message Service Database:**
- `message_reaction` — Reactions (PostgreSQL for relational queries)

**Media Service Database:**
- `media_object` — Metadata file upload

**Notification Service Database:**
- `device_token` — Push tokens
- `notification` — Lịch sử thông báo

### 4.2 NoSQL (Cassandra/ScyllaDB)

Use for **append-only high write throughput** message history.

```cql
-- Primary query pattern: Load messages by conversation (serverSeq ordering)
CREATE TABLE messages_by_conversation (
    conversation_id UUID,
    server_seq BIGINT,          -- Monotonic sequence per conversation (D8)
    message_id UUID,
    sender_id UUID,
    client_message_id UUID,     -- For reference (idempotency check in separate table)
    message_type TEXT,
    content TEXT,
    media_id UUID,
    reply_to_id UUID,
    status TEXT,                -- SENT, DELETED, REVOKED
    server_ts TIMESTAMP,
    PRIMARY KEY ((conversation_id), server_seq)
) WITH CLUSTERING ORDER BY (server_seq DESC);

-- Idempotency lookup table (D12) — thay vì secondary index
-- Partition by sender để query nhanh khi dedupe
CREATE TABLE message_idempotency_by_sender (
    sender_id UUID,
    client_message_id UUID,
    conversation_id UUID,
    server_seq BIGINT,
    message_id UUID,
    created_at TIMESTAMP,
    PRIMARY KEY ((sender_id), client_message_id)
) WITH default_time_to_live = 604800;  -- TTL 7 days; after expiration, rely on application-level idempotency (client retry window) + Redis cache

-- Query: SELECT * FROM message_idempotency_by_sender 
--        WHERE sender_id = ? AND client_message_id = ?
```

> **Why lookup table instead of secondary index?**
> - Secondary index trong Cassandra cho non-partition-key queries không scale tốt
> - Lookup table với partition = `sender_id` cho O(1) idempotency check

**Ordering Rules:**
- **UI Display**: `ORDER BY server_seq ASC` (oldest first)
- **Pagination (load more)**: `ORDER BY server_seq DESC` + `WHERE server_seq < ?`
- **Sync (missed)**: `ORDER BY server_seq ASC` + `WHERE server_seq > ?`

### 4.3 Redis

**Presence & Session:**
```
presence:user:{userId} → {"online": true, "lastSeen": 1704067200000, "deviceId": "..."}
socket:conn:{connectionId} → {"userId": "...", "deviceId": "..."}
socket:user:{userId} → SET of connectionIds
```

**Rate Limiting:**
```
rl:msg:{userId} → counter với TTL 60s
rl:ai:{userId} → counter với TTL 60s
```

**Caching:**
```
cache:conv:list:{userId} → JSON array of conversation summaries (TTL 5m)
cache:conv:settings:{conversationId}:{userId} → JSON settings (TTL 5m)
```

**Sequence Generation (D8):**
```
seq:conv:{conversationId} → BIGINT (atomic INCR for serverSeq)
```

> **Production Notes**:
> - **Primary**: Redis INCR (atomic, nhanh, O(1))
> - **Persistence**: Redis cần enable AOF/RDB và replication đúng cách
> - **Failover risk**: Redis cluster failover có thể gây sequence gap/rollback nếu không config đúng
> - **Alternative**: DB sequence per conversation (PostgreSQL SEQUENCE) nếu không muốn phụ thuộc Redis
> - **Khuyến nghị**: Redis Cluster với `min-replicas-to-write 1` + `min-replicas-max-lag 10`
> - **Gap tolerance**: Sequence gaps chấp nhận được (ordering vẫn đúng), nhưng **không được rollback** (seq giảm)
> - **No-rollback option**: Cân nhắc Redis Raft / sequence service nếu cần đảm bảo mạnh hơn

**Idempotency (D12 - cache):**
```
dedup:msg:{senderId}:{clientMessageId} → {messageId, serverSeq}
TTL: >= 24h (or align with Cassandra lookup TTL)
```

> **Note**: Persistent store là Cassandra lookup table `message_idempotency_by_sender` (with 7-day TTL). Redis cache là fast-path optimization, scoped by sender để tránh collision.

### 4.4 Không dùng Cross-Service Foreign Keys

> **Nguyên tắc Microservices**: Mỗi service sở hữu database riêng, không FK xuyên service.

```
✅ ĐÚNG: Message Service lưu senderId (UUID), không FK đến users table
❌ SAI:  Message Service có FK REFERENCES users(id)
```

Khi cần data từ service khác:
1. **Cache locally** (Redis/in-memory)
2. **Sync via events** (Kafka)
3. **API call** (nếu cần real-time)

---

## 5) Kafka Topics & Event Contracts

### 5.1 Topics

| Topic | Events | Producer | Consumer |
|-------|--------|----------|----------|
| `topic.message-events` | `message_sent`, `message_delivered`, `message_seen`, `message_recalled` | Gateway | Message Service, Notification Service |
| `topic.notification-events` | `notify_push`, `notify_in_app` | Message Service | Notification Service |
| `topic.media-jobs` | `media_uploaded`, `thumbnail_request` | Media Service | Media Worker |
| `topic.social-events` | `friend_request_sent`, `friend_accepted`, `user_blocked` | Social Service | Notification Service |
| `topic.analytics-events` | `login_success`, `message_sent`, `media_uploaded` | Various | Analytics Service |
| `topic.dlq.*` | Dead-letter events | Kafka | Manual processing |

### 5.2 Canonical Event Envelope

```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "message_sent",
  "occurredAt": "2026-01-12T10:00:00Z",
  "producer": "realtime-gateway",
  "version": 1,
  "correlationId": "request-trace-id",
  "payload": {
    "messageId": "uuid",
    "conversationId": "uuid",
    "senderId": "uuid",
    "messageType": "text",
    "content": "Hello!",
    "serverSeq": 12345,
    "serverTs": 1704067200000
  }
}
```

### 5.3 Key Event Payloads

#### `message_sent`

> **Allowed `messageType`**: `text` | `image` | `video` | `file` | `voice` | `sticker` | `system`

```json
{
  "messageId": "uuid",
  "conversationId": "uuid", 
  "senderId": "uuid",
  "messageType": "text",
  "content": "Hello!",
  "mediaId": null,
  "replyToId": null,
  "mentions": ["userId1", "userId2"],
  "clientMessageId": "client-generated-uuid",
  "serverSeq": 12345,
  "serverTs": 1704067200000
}
```

#### `message_delivered` / `message_seen` (User-level Semantics)

> **D9: Zalo-like Receipt**: Delivered/Seen là **user-level**, không phải device-level.
> - **Delivered**: Bất kỳ device nào của recipient nhận được → delivered for user
> - **Seen**: Bất kỳ device nào của recipient đọc → seen for user

> **Allowed `receiptType`**: `delivered` | `seen`

```json
{
  "conversationId": "uuid",
  "messageId": "uuid",
  "serverSeq": 12345,
  "userId": "uuid",
  "receiptType": "delivered",
  "timestamp": 1704067200000
}
```

**Receipt Storage (Message Service):**
```sql
-- Chỉ cần lưu user-level, không cần per-device
CREATE TABLE message_receipt (
    conversation_id UUID,
    message_id UUID,
    user_id UUID,
    delivered_at TIMESTAMP,
    seen_at TIMESTAMP,
    PRIMARY KEY (conversation_id, message_id, user_id)
);
```

### 5.4 Idempotency (D12)

> **Strategy**: `clientMessageId` với persistent storage (Cassandra lookup hoặc PostgreSQL UNIQUE)

**Message Dedupe Flow:**
1. Client gửi `message_send` với `clientMessageId` (UUID, client-generated)
2. Gateway check Redis `dedup:msg:{senderId}:{clientMessageId}` (fast-path, TTL >= 24h)
   - **Hit**: Trả về stored `{messageId, serverSeq}` (skip steps 3-4)
   - **Miss**: Tiếp tục step 3
3. Gateway query idempotency store (mode-specific):

**Idempotency Resolution (Cassandra):**
- Query `message_idempotency_by_sender` WHERE `sender_id = ? AND client_message_id = ?`
- **Found**: Trả về existing `{messageId, serverSeq, conversationId}`
- **Not found**: 
  - Allocate new `serverSeq` (Redis INCR)
  - Publish Kafka event
  - INSERT vào `message_idempotency_by_sender` (TTL 7 days)
  - Cache vào Redis (TTL 24h-7d)

**Event Consumer Idempotency:**
- Consumers **MUST** be idempotent using `eventId` hoặc `messageId`
- Dedupe strategy:
  - Cassandra lookup table (source of truth) + Redis fast-path
  - Kafka offset: Commit offset sau khi process thành công

**Why persistent storage (not TTL-only)?**
- Redis restart/eviction → mất dedupe state
- Cassandra TTL 7d hoặc PostgreSQL UNIQUE là reliable across restarts
- Redis chỉ là fast-path optimization

### 5.5 Outbox Pattern (Production - Optional)

> **Use case**: Đảm bảo atomicity giữa DB write và Kafka publish

```
┌────────────────────────────────────────────────────────────────┐
│                      OUTBOX PATTERN                            │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Service                    DB                     Kafka       │
│    │                        │                        │         │
│    │── BEGIN TX ──────────▶│                        │         │
│    │── INSERT message ────▶│                        │         │
│    │── INSERT outbox ─────▶│                        │         │
│    │── COMMIT TX ─────────▶│                        │         │
│    │                        │                        │         │
│    │        ┌───────────────┼────────────────────────┤         │
│    │        │ Outbox Poller │                        │         │
│    │        │ (CDC/polling) │                        │         │
│    │        └───────┬───────┘                        │         │
│    │                │── SELECT unpublished ────────▶│         │
│    │                │── publish event ─────────────▶│         │
│    │                │── UPDATE published_at ───────▶│         │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Outbox Table:**
```sql
CREATE TABLE outbox_event (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(50),     -- 'message', 'conversation'
    aggregate_id UUID,
    event_type VARCHAR(50),
    payload JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    published_at TIMESTAMP NULL     -- NULL = chưa publish
);

CREATE INDEX idx_outbox_unpublished ON outbox_event (created_at) 
    WHERE published_at IS NULL;
```

**When to use:**
- Message Service cần atomic write + event
- Notification Service cần reliable event emission
- Consider for critical workflows requiring exactly-once delivery

---

## 6) API Surface

> **Ownership**: Mỗi API endpoint thuộc về một service cụ thể.

### 6.1 REST APIs (by Service)

#### Auth Service (`/api/v1/auth`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/firebase/verify` | Verify Firebase token | `{firebaseIdToken}` | `{jwt, refreshToken, user}` |
| POST | `/refresh` | Refresh JWT | `{refreshToken}` | `{jwt}` |
| POST | `/logout` | Logout (revoke refresh token) | `{refreshToken}` | `{success}` |
| POST | `/logout-all` | Logout all devices | - | `{success}` |

#### User Service (`/api/v1/users`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/me` | Get current user profile | - | `{user}` |
| PUT | `/me` | Update profile | `{displayName, avatar, bio, ...}` | `{user}` |
| GET | `/{userId}` | Get user by ID | - | `{user}` |
| GET | `/search?phone=...` | Search by phone | - | `{users[]}` |
| PUT | `/me/privacy` | Update privacy settings | `{settings}` | `{settings}` |

#### Social Service (`/api/v1/social`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/friends/requests` | Send friend request | `{toUserId, message?}` | `{request}` |
| GET | `/friends/requests/incoming` | List incoming requests | - | `{requests[]}` |
| GET | `/friends/requests/outgoing` | List outgoing requests | - | `{requests[]}` |
| POST | `/friends/requests/{id}/accept` | Accept request | - | `{friendship}` |
| POST | `/friends/requests/{id}/reject` | Reject request | - | `{success}` |
| DELETE | `/friends/requests/{id}` | Cancel request | - | `{success}` |
| GET | `/friends` | List friends | - | `{friends[]}` |
| DELETE | `/friends/{userId}` | Unfriend | - | `{success}` |
| POST | `/blocks` | Block user | `{userId}` | `{block}` |
| DELETE | `/blocks/{userId}` | Unblock user | - | `{success}` |
| GET | `/blocks` | List blocked users | - | `{blocks[]}` |

#### Conversation Service (`/api/v1/conversations`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/` | List conversations | `?cursor=...&limit=20` | `{conversations[], pagination}` |
| POST | `/` | Create direct conversation | `{userId}` | `{conversation}` |
| GET | `/{id}` | Get conversation detail | - | `{conversation}` |
| PUT | `/{id}/settings` | Update settings (mute/pin) | `{isMuted, isPinned}` | `{settings}` |
| POST | `/{id}/read` | Mark as read | `{lastReadSeq}` | `{success}` |

#### Group Service (`/api/v1/groups`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/` | Create group | `{name, memberIds[], avatar?}` | `{group}` |
| GET | `/{id}` | Get group detail | - | `{group}` |
| PUT | `/{id}` | Update group info | `{name?, avatar?}` | `{group}` |
| DELETE | `/{id}` | Delete group (owner only) | - | `{success}` |
| POST | `/{id}/members` | Add members | `{userIds[]}` | `{members[]}` |
| DELETE | `/{id}/members/{userId}` | Remove member | - | `{success}` |
| POST | `/{id}/leave` | Leave group | - | `{success}` |
| PUT | `/{id}/members/{userId}/role` | Change role | `{role}` | `{member}` |

#### Message Service (`/api/v1/messages`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/conversations/{id}/messages` | Get message history | `?cursor=...&limit=50` | `{messages[], pagination}` |
| GET | `/{messageId}` | Get single message | - | `{message}` |
| DELETE | `/{messageId}` | Delete message | - | `{success}` |
| POST | `/{messageId}/recall` | Recall message | - | `{success}` |
| POST | `/{messageId}/reactions` | Add reaction | `{emoji}` | `{reaction}` |
| DELETE | `/{messageId}/reactions` | Remove reaction | - | `{success}` |

#### Media Service (`/api/v1/media`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/presign` | Get presigned upload URL | `{fileName, mimeType, size}` | `{uploadUrl, mediaId}` |
| POST | `/{mediaId}/confirm` | Confirm upload complete | - | `{media}` |
| GET | `/{mediaId}` | Get media metadata | - | `{media}` |

#### Notification Service (`/api/v1/notifications`)

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/` | List notifications | `?cursor=...` | `{notifications[]}` |
| PUT | `/{id}/read` | Mark as read | - | `{success}` |
| PUT | `/read-all` | Mark all as read | - | `{success}` |
| POST | `/devices` | Register device token | `{token, platform}` | `{device}` |
| DELETE | `/devices/{deviceId}` | Unregister device | - | `{success}` |

#### Call Service (`/api/v1/calls`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/initiate` | Initiate call | `{conversationId, callType}` | `{callId, iceServers}` |
| POST | `/{callId}/answer` | Answer call | `{sdpAnswer}` | `{success}` |
| POST | `/{callId}/reject` | Reject call | `{reason?}` | `{success}` |
| POST | `/{callId}/end` | End call | - | `{success}` |
| GET | `/history` | Get call history | `?cursor=...&limit=20` | `{calls[], pagination}` |
| GET | `/{callId}` | Get call details | - | `{call}` |

#### Story Service (`/api/v1/stories`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/` | Create story | `{mediaId?, text?, background?, visibility}` | `{story}` |
| GET | `/feed` | Get stories feed | - | `{stories[]}` (grouped by user) |
| GET | `/me` | Get my stories | - | `{stories[]}` |
| GET | `/{storyId}` | Get story detail | - | `{story}` |
| DELETE | `/{storyId}` | Delete story | - | `{success}` |
| GET | `/{storyId}/views` | Get story viewers | - | `{viewers[]}` |
| POST | `/{storyId}/view` | Mark story viewed | - | `{success}` |
| POST | `/{storyId}/reactions` | React to story | `{emoji}` | `{reaction}` |
| POST | `/{storyId}/replies` | Reply to story | `{content}` | `{reply}` |
| POST | `/highlights` | Create highlight | `{title, storyIds[]}` | `{highlight}` |
| GET | `/highlights/{userId}` | Get user highlights | - | `{highlights[]}` |

#### Timeline Service (`/api/v1/timeline`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/feed` | Get timeline feed | `?cursor=...` | `{posts[], pagination}` |
| POST | `/posts` | Create post | `{content, mediaIds[]?, visibility}` | `{post}` |
| GET | `/posts/{postId}` | Get post detail | - | `{post}` |
| PUT | `/posts/{postId}` | Update post | `{content?, visibility?}` | `{post}` |
| DELETE | `/posts/{postId}` | Delete post | - | `{success}` |
| POST | `/posts/{postId}/like` | Like/React post | `{reactionType}` | `{reaction}` |
| DELETE | `/posts/{postId}/like` | Unlike post | - | `{success}` |
| GET | `/posts/{postId}/comments` | Get comments | `?cursor=...` | `{comments[]}` |
| POST | `/posts/{postId}/comments` | Add comment | `{content, parentId?}` | `{comment}` |
| DELETE | `/comments/{commentId}` | Delete comment | - | `{success}` |
| POST | `/posts/{postId}/share` | Share post | `{content?}` | `{post}` |

#### Sticker Service (`/api/v1/stickers`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/packs` | List sticker packs | `?category=...` | `{packs[]}` |
| GET | `/packs/trending` | Get trending packs | - | `{packs[]}` |
| GET | `/packs/{packId}` | Get pack with stickers | - | `{pack, stickers[]}` |
| POST | `/packs/{packId}/download` | Download pack | - | `{success}` |
| DELETE | `/packs/{packId}/download` | Remove pack | - | `{success}` |
| GET | `/me/packs` | Get my downloaded packs | - | `{packs[]}` |
| GET | `/me/recent` | Get recently used stickers | - | `{stickers[]}` |
| POST | `/ai/generate` | Generate AI sticker | `{prompt}` | `{sticker}` |
| GET | `/search` | Search stickers | `?q=...` | `{stickers[]}` |

#### QR & Link Service (`/api/v1/qr`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| GET | `/me` | Get my QR code | - | `{qrCode, shortCode}` |
| POST | `/group/{conversationId}` | Generate group invite QR | `{expiresAt?}` | `{qrCode, inviteLink}` |
| GET | `/scan/{shortCode}` | Resolve QR/short link | - | `{type, targetId}` |
| POST | `/short-link` | Create short link | `{url, type}` | `{shortLink}` |

#### Backup Service (`/api/v1/backup`) ⭐ NEW

| Method | Endpoint | Description | Request | Response |
|--------|----------|-------------|---------|----------|
| POST | `/export` | Export all chats to file | `{includeMedia?, format}` | `{downloadUrl, expiresAt}` |
| POST | `/export/{conversationId}` | Export single conversation | `{includeMedia?}` | `{downloadUrl}` |
| POST | `/import` | Import backup file | `multipart/form-data` | `{status, conversations[]}` |
| GET | `/history` | Get backup history | - | `{backups[]}` |
| DELETE | `/{backupId}` | Delete backup file | - | `{success}` |

### 6.2 Realtime (WebSocket) Events

> **Endpoint**: `wss://api.example.com/ws?token={jwt}`

**Connection Flow:**
```
1. Client connects với JWT trong query param hoặc header
2. Server validates JWT, extracts userId/deviceId
3. Server binds connection: connectionId ↔ userId/deviceId
4. Server sends: {"type": "connected", "payload": {"connectionId": "..."}}
5. Client có thể bắt đầu send/receive messages
```

**Client → Gateway:**

| Type | Payload | Description |
|------|---------|-------------|
| `message_send` | `{conversationId, clientMessageId, messageType, content, mediaId?, replyToId?, mentions?}` | Gửi tin nhắn |
| `message_delivered` | `{conversationId, messageId, serverSeq}` | ACK đã nhận |
| `message_seen` | `{conversationId, messageId, serverSeq}` | ACK đã đọc |
| `typing_start` | `{conversationId}` | Bắt đầu typing |
| `typing_stop` | `{conversationId}` | Dừng typing |
| `presence_subscribe` | `{userIds[]}` | Subscribe presence |
| `sync_request` | `{cursor, limit?}` | Request sync (cursor = base64({convId, lastSeq})) |
| `call_initiate` | `{conversationId, callType, sdpOffer}` | Bắt đầu cuộc gọi (voice/video) |
| `call_answer` | `{callId, sdpAnswer}` | Trả lời cuộc gọi |
| `call_reject` | `{callId, reason?}` | Từ chối cuộc gọi |
| `call_end` | `{callId}` | Kết thúc cuộc gọi |
| `call_ice_candidate` | `{callId, candidate}` | Gửi ICE candidate |
| `call_toggle_audio` | `{callId, enabled}` | Bật/tắt mic |
| `call_toggle_video` | `{callId, enabled}` | Bật/tắt camera |

**Gateway → Client:**

| Type | Payload | Description |
|------|---------|-------------|
| `connected` | `{connectionId}` | Connection established |
| `message_receive` | `{message}` (includes `serverSeq`) | Tin nhắn mới |
| `message_sent_ack` | `{clientMessageId, messageId, serverSeq, serverTs}` | ACK đã gửi |
| `message_delivered_ack` | `{messageId, userId, timestamp}` | ACK delivered (user-level) |
| `message_seen_ack` | `{messageId, userId, timestamp}` | ACK seen (user-level) |
| `message_recalled` | `{messageId, conversationId}` | Tin nhắn bị thu hồi |
| `user_typing` | `{conversationId, userId}` | User đang typing |
| `presence_update` | `{userId, online, lastSeen}` | Presence change |
| `sync_response` | `{messages[], cursor}` | Sync data (messages ordered by serverSeq) |
| `call_incoming` | `{callId, conversationId, callerId, callType, sdpOffer}` | Có cuộc gọi đến |
| `call_answered` | `{callId, sdpAnswer}` | Cuộc gọi được trả lời |
| `call_rejected` | `{callId, userId, reason}` | Cuộc gọi bị từ chối |
| `call_ended` | `{callId, duration, reason}` | Cuộc gọi kết thúc |
| `call_ice_candidate` | `{callId, candidate}` | ICE candidate từ peer |
| `call_participant_joined` | `{callId, userId}` | Người tham gia vào group call |
| `call_participant_left` | `{callId, userId}` | Người rời khỏi group call |
| `call_media_state` | `{callId, userId, audioEnabled, videoEnabled}` | Trạng thái media của participant |
| `error` | `{code, message}` | Error |

---

## 7) Authentication & Authorization

### 7.1 Firebase Phone Auth → Internal JWT

1. Client uses Firebase SDK to verify phone OTP.
2. Firebase returns `Firebase ID token`.
3. Client sends token to **Auth Service**.
4. Auth Service verifies token and issues **internal JWT + refresh token**.
5. All microservices trust internal JWT (Spring Security).

### 7.2 Roles

- `USER`: default
- `ADMIN`: dashboard & moderation

### 7.3 Rate Limiting

- Message send: per-user RPM limit in Redis.
- AI: separate per-user budget, plus provider circuit breaker.

---

## 8) AI Assistant (Hybrid Gemini + Ollama)

### 8.1 Modes

- **Basic AI Assistant** (default): FAQ/help scope.
- **Quick Reply** (opt-in): only user-selected single message is used.
- **Summary** (opt-in): only user-selected range is used.

### 8.2 Provider Routing

```
┌─────────────────────────────────────────────────────────┐
│                 AI PROVIDER ROUTING                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   Request ──▶ Rate Limit Check ──▶ Policy Filter        │
│                     │                    │               │
│                     ▼                    ▼               │
│              ┌─────────────┐      ┌───────────┐         │
│              │   Gemini    │      │  Reject   │         │
│              │   (Primary) │      │           │         │
│              └──────┬──────┘      └───────────┘         │
│                     │                                    │
│              Success? ──Yes──▶ Return Response          │
│                     │                                    │
│                     No (429/timeout/error)              │
│                     │                                    │
│                     ▼                                    │
│              ┌─────────────┐                            │
│              │   Ollama    │                            │
│              │ (Fallback)  │                            │
│              └──────┬──────┘                            │
│                     │                                    │
│              Success? ──Yes──▶ Return Response          │
│                     │                                    │
│                     No                                   │
│                     │                                    │
│                     ▼                                    │
│              ┌─────────────┐                            │
│              │  Template/  │                            │
│              │    FAQ      │                            │
│              └─────────────┘                            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

- **Circuit Breaker**: Sau 5 failures liên tiếp, bypass Gemini trong 5 phút
- **Timeout**: Gemini 10s, Ollama 30s

### 8.3 Safety & Privacy Guardrails

- Do not automatically ingest chat history.
- Log only metadata (latency, provider, error code), not message content.
- Require explicit opt-in confirmation for Quick Reply / Summary.

### 8.4 AI Data Governance

```yaml
DATA_RETENTION:
  ai_request_logs: 30 days    # Chỉ metadata, không content
  ai_response_cache: 0        # Không cache responses

PII_REDACTION:
  before_sending_to_provider:
    - phone_numbers: replace với [PHONE]
    - email_addresses: replace với [EMAIL]
    - urls: keep (có thể cần cho context)
  
FORBIDDEN_OPERATIONS:
  - Auto-summarize conversations without explicit consent
  - Store user messages for training
  - Share data between users
```

### 8.5 AI Service API

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/ai/chat` | General AI chat |
| POST | `/api/v1/ai/quick-reply` | Generate quick replies (opt-in) |
| POST | `/api/v1/ai/summary` | Summarize messages (opt-in) |

```json
// POST /api/v1/ai/chat
{
  "prompt": "How do I create a group?",
  "context": "app_help"  // Scope: app_help, general
}

// Response
{
  "response": "To create a group, tap the + button...",
  "provider": "gemini",
  "latencyMs": 450
}
```

---

## 9) Deployment (AWS)

### 9.1 High-Level

- **Web**: S3 + CloudFront
- **REST**: ALB → EKS ingress → microservices
- **Realtime**: NLB → Netty Realtime Gateway
- **Data**:
  - RDS (PostgreSQL/MySQL)
  - Cassandra/Scylla on EC2
  - ElastiCache Redis
  - MSK Kafka
- **Observability**: CloudWatch + Prometheus + Grafana
- **Security**: IAM, VPC, WAF, TLS

### 9.2 Why this deployment architecture

- Separate ALB (REST) and NLB (WebSocket) to optimize latency and connection stability.
- Polyglot persistence matches OTT data patterns.
- Kafka isolates hot path from heavy processing.
- S3+CloudFront reduces backend bandwidth and improves media delivery.

---

## 10) Local Development

### 10.1 Prerequisites

- Java 21, Maven/Gradle
- Docker + Docker Compose
- (Optional) Ollama local runtime

### 10.2 Suggested docker-compose stack

- PostgreSQL/MySQL
- Redis
- Kafka (or Redpanda for simplicity)
- MinIO (S3-compatible) for local media testing
- (Optional) ScyllaDB

### 10.3 Environment Variables (examples)

```bash
# Auth
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_JSON=
JWT_SECRET=
JWT_TTL_SECONDS=3600
REFRESH_TTL_SECONDS=2592000

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Redis
REDIS_URL=redis://localhost:6379

# RDBMS
DB_URL=jdbc:postgresql://localhost:5432/ott
DB_USER=ott
DB_PASS=ott

# Media
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=ott-media
S3_ACCESS_KEY=
S3_SECRET_KEY=
CLOUDFRONT_BASE_URL=http://localhost:9000/ott-media

# AI
GEMINI_API_KEY=
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2
AI_CIRCUIT_BREAKER_TTL_SECONDS=300
```

### 10.4 Run Order

1. Start infra: `docker compose up -d`
2. Start config/discovery (if used)
3. Start microservices
4. Start realtime gateway
5. Run clients

---

## 11) Testing Strategy

- Unit tests: service layer, validators, rate limit logic
- Integration tests: DB + Kafka + Redis
- Realtime tests: reconnect, ordering, receipts
- AI tests:
  - simulate Gemini quota error → Ollama fallback
  - opt-in enforcement
- Security tests: JWT expiration, refresh flow, spam prevention

---

## 12) Operational Runbooks (Short)

### 12.1 Common Incidents

- **High latency in chat**
  - check gateway CPU/memory
  - check Kafka consumer lag
  - check Redis latency

- **Duplicate messages**
  - ensure `messageId` idempotency in consumers
  - verify reconnect sync logic

- **AI returns errors**
  - check Gemini rate-limit and circuit breaker state
  - verify Ollama health endpoint and model availability

### 12.2 Dashboards (recommended)

- Realtime gateway: active connections, msg/sec, p95 latency
- Kafka: consumer lag per topic
- Redis: ops/sec, latency
- RDBMS: slow queries
- AI: provider distribution, error codes, fallback rate

---

## 13) Glossary

- **Hot path**: critical low-latency path for sending/receiving messages.
- **Cold path**: background/async work (persistence, thumbnails, analytics).
- **ACK**: acknowledgement for message state transitions.
- **Circuit breaker**: temporarily blocks calls to a failing dependency.

---

## 14) Frontend Architecture (React Native / Web)

### 14.1 Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Mobile | React Native 0.76+ | Cross-platform iOS/Android |
| Web | React 19+ / Next.js 15 | Web client |
| State Management | Zustand + React Query | Client state + Server state |
| Realtime | Native WebSocket | Persistent connection |
| Local Storage | MMKV (mobile) / IndexedDB (web) | Offline cache |
| UI Components | NativeWind / TailwindCSS | Styling |

### 14.2 Offline-First Strategy

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT APP                           │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   UI Layer  │ ←→ │ State Store │ ←→ │ Sync Engine │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
│                            ↓                  ↓        │
│                     ┌─────────────┐    ┌─────────────┐ │
│                     │ Local Cache │    │  WebSocket  │ │
│                     │ (MMKV/IDB)  │    │  Manager    │ │
│                     └─────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

- **Optimistic Updates**: UI updates immediately, sync in background
- **Pending Queue**: Messages queued when offline, sent on reconnect
- **Conflict Resolution**: Server timestamp wins (last-write-wins)
- **Sync Cursor**: Track `lastSeq` per conversation (cursor = `base64({convId, lastSeq})`)

### 14.3 WebSocket Reconnection Strategy

```typescript
const RECONNECT_CONFIG = {
  initialDelay: 1000,      // 1 second
  maxDelay: 30000,         // 30 seconds max
  multiplier: 1.5,         // exponential backoff
  jitter: 0.3,             // 30% randomization
  maxAttempts: Infinity    // never give up
};
```

---

## 15) Database Schema Summary

> **Chi tiết đầy đủ**: Xem [OTT_Zalo_Database_Design_By_Service.md](./OTT_Zalo_Database_Design_By_Service.md)

### 15.1 Schema Overview by Service

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │  AUTH SERVICE   │    │  USER SERVICE   │                     │
│  │  ─────────────  │    │  ─────────────  │                     │
│  │  auth_account   │    │  user_profile   │                     │
│  │  auth_refresh_  │    │  user_privacy_  │                     │
│  │  token          │    │  setting        │                     │
│  │  auth_otp       │    │                 │                     │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ SOCIAL SERVICE  │    │ CONVERSATION SVC│                     │
│  │  ─────────────  │    │  ─────────────  │                     │
│  │  friend_request │    │  conversation   │                     │
│  │  friendship     │    │  conversation_  │                     │
│  │  block_list     │    │  member         │                     │
│  │                 │    │  conversation_  │                     │
│  │                 │    │  direct_map     │                     │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ MESSAGE SERVICE │    │  MEDIA SERVICE  │                     │
│  │  ─────────────  │    │  ─────────────  │                     │
│  │  message        │    │  media_object   │                     │
│  │  message_       │    │  media_access_  │                     │
│  │  reaction       │    │  scope          │                     │
│  │  message_       │    │                 │                     │
│  │  receipt (opt)  │    │                 │                     │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │NOTIFICATION SVC │    │ MODERATION SVC  │                     │
│  │  ─────────────  │    │  ─────────────  │                     │
│  │  device_token   │    │  report         │                     │
│  │  notification   │    │  admin_action_  │                     │
│  │                 │    │  log            │                     │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 15.2 Key Tables

> **Note**: Bảng dưới đây dùng `last_read_seq` cho Production mode (cursor-based theo serverSeq).

#### `auth_account`
| Field | Type | Description |
|-------|------|-------------|
| `account_id` | UUID | PK |
| `phone` | VARCHAR(20) | UNIQUE, login identifier |
| `firebase_uid` | VARCHAR(128) | Firebase UID |
| `status` | ENUM | ACTIVE, LOCKED, DISABLED |
| `created_at` | TIMESTAMP | |

#### `user_profile`
| Field | Type | Description |
|-------|------|-------------|
| `user_id` | UUID | PK, = account_id |
| `display_name` | VARCHAR(100) | |
| `avatar_url` | VARCHAR(500) | |
| `bio` | VARCHAR(500) | |
| `gender` | ENUM | UNKNOWN, MALE, FEMALE, OTHER |

#### `conversation`
| Field | Type | Description |
|-------|------|-------------|
| `conversation_id` | UUID | PK |
| `type` | ENUM | DIRECT, GROUP |
| `title` | VARCHAR(100) | Group name |
| `created_by` | UUID | Creator user ID |

#### `conversation_member`
| Field | Type | Description |
|-------|------|-------------|
| `conversation_id` | UUID | PK* |
| `user_id` | UUID | PK* |
| `role` | ENUM | OWNER, ADMIN, MEMBER |
| `mute_until` | TIMESTAMP | Nullable |
| `is_pinned` | BOOLEAN | |
| `last_read_seq` | BIGINT | Cursor for unread (serverSeq-based) |

#### `message`
| Field | Type | Description |
|-------|------|-------------|
| `message_id` | UUID | PK |
| `conversation_id` | UUID | |
| `server_seq` | BIGINT | Ordering sequence per conversation |
| `sender_id` | UUID | |
| `type` | ENUM | TEXT, IMAGE, FILE, VOICE, SYSTEM |
| `content` | TEXT | |
| `media_id` | UUID | Nullable |
| `reply_to_message_id` | UUID | Nullable |
| `client_message_id` | UUID | Idempotency key (UNIQUE per sender) |
| `status` | ENUM | SENT, DELETED, REVOKED |
| `server_ts` | TIMESTAMP | Server timestamp |

### 15.3 Key Indexes

```sql
-- Conversation list cho user (sorted by last message)
CREATE INDEX idx_conv_member_user ON conversation_member(user_id, joined_at) 
    WHERE left_at IS NULL;

-- Message history trong conversation (Production: order by server_seq)
CREATE INDEX idx_message_conv ON message(conversation_id, server_seq DESC);

-- Idempotency check per sender
CREATE UNIQUE INDEX idx_message_idempotency ON message(sender_id, client_message_id);

-- Friendship lookup (both directions)
CREATE INDEX idx_friendship_user1 ON friendship(user_id_1);
CREATE INDEX idx_friendship_user2 ON friendship(user_id_2);

-- Friend requests inbox
CREATE INDEX idx_friend_req_to ON friend_request(to_user_id, status, created_at);
```

### 15.4 Read vs Receipt Strategy

> **Decision**: Dùng **cursor-based read tracking** (theo `serverSeq`) thay vì per-message receipts cho scalability.

```
┌─────────────────────────────────────────────────────────────────┐
│          CURSOR-BASED READ TRACKING (serverSeq)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  conversation_member.last_read_seq = 12345                      │
│                                                                  │
│  Messages:  seq=12340  seq=12341  seq=12345  seq=12346  seq=12347│
│                                      ▲                           │
│                                 last_read                        │
│                                                                  │
│  → Unread count = COUNT(*) WHERE server_seq > last_read_seq     │
│  → All messages with seq <= 12345 are considered "read"         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Khi nào dùng per-message receipts?**
- Group nhỏ (< 20 members) cần hiển thị "X người đã xem"
- 1:1 chat cần show tick xanh chính xác

**UI Display Strategy:**
- **1:1 Chat**: Hiển thị tick (✓✓) dựa trên user-level delivered/seen (bất kỳ device nào của recipient nhận/đọc)
- **Group Chat Lớn**: Chỉ hiển thị "seen" theo `last_read_seq`, không cần per-message receipts (scale tốt hơn)
- **Group Chat Nhỏ**: Optional per-message receipts nếu cần show "10/15 đã xem"

**Table `message_receipt` (optional - canonical schema):**
```sql
CREATE TABLE message_receipt (
    conversation_id UUID,
    message_id UUID,
    user_id UUID,
    delivered_at TIMESTAMP,
    seen_at TIMESTAMP,
    PRIMARY KEY (conversation_id, message_id, user_id)
);
```

---

## 16) API Specifications (OpenAPI Style)

### 16.1 Standard Response Format

```json
{
  "success": true,
  "data": { },
  "error": null,
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-01-11T10:00:00Z"
  }
}
```

### 16.2 Error Response Format

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "AUTH_001",
    "message": "Invalid or expired token",
    "details": { }
  },
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-01-11T10:00:00Z"
  }
}
```

### 16.3 Error Codes Registry

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `AUTH_001` | 401 | Invalid or expired token |
| `AUTH_002` | 401 | Refresh token expired |
| `AUTH_003` | 403 | Account suspended |
| `AUTH_004` | 429 | Too many auth attempts |
| `USER_001` | 404 | User not found |
| `USER_002` | 409 | Phone number already registered |
| `SOCIAL_001` | 404 | Friend request not found |
| `SOCIAL_002` | 409 | Already friends |
| `SOCIAL_003` | 403 | User blocked |
| `CONV_001` | 404 | Conversation not found |
| `CONV_002` | 403 | Not a participant |
| `CONV_003` | 403 | Insufficient permissions |
| `MSG_001` | 400 | Invalid message format |
| `MSG_002` | 413 | Message too large |
| `MSG_003` | 429 | Rate limit exceeded |
| `MEDIA_001` | 400 | Invalid file type |
| `MEDIA_002` | 413 | File too large |
| `AI_001` | 503 | AI service unavailable |
| `AI_002` | 429 | AI rate limit exceeded |
| `SYS_001` | 500 | Internal server error |
| `SYS_002` | 503 | Service temporarily unavailable |

### 16.4 Pagination (Cursor-based)

> **D10 Update**: Cursor format khác nhau cho message history vs conversation list

**Conversation List Pagination:**
```json
// Request - Load conversations sorted by last message
GET /api/v1/conversations?cursor=eyJsYXN0TWVzc2FnZVNlcSI6MTIzNDUsImxhc3RDb252ZXJzYXRpb25JZCI6InV1aWQifQ&limit=20

// Cursor decode: {"lastMessageSeq":12345,"lastConversationId":"uuid"}

// Response
{
  "success": true,
  "data": {
    "conversations": [
      {"conversationId": "...", "lastMessageSeq": 12340, ...},
      {"conversationId": "...", "lastMessageSeq": 12339, ...}
    ],
    "pagination": {
      "cursor": "eyJsYXN0TWVzc2FnZVNlcSI6MTIzNDAsImxhc3RDb252ZXJzYXRpb25JZCI6InV1aWQyIn0",
      "nextCursor": "eyJsYXN0TWVzc2FnZVNlcSI6MTIzMzAsImxhc3RDb252ZXJzYXRpb25JZCI6InV1aWQzIn0",
      "hasMore": true,
      "limit": 20
    }
  }
}
```

**Message History Pagination:**
```json
// Request - Load older messages trong 1 conversation
GET /api/v1/messages/conversations/{id}/messages?cursor=eyJjb252SWQiOiJ1dWlkIiwibGFzdFNlcSI6MTIzNDV9&limit=50

// Cursor decode: {"convId":"uuid","lastSeq":12345}

// Response
{
  "success": true,
  "data": {
    "messages": [
      {"messageId": "...", "serverSeq": 12340, ...},
      {"messageId": "...", "serverSeq": 12339, ...}
    ],
    "pagination": {
      "cursor": "eyJjb252SWQiOiJ1dWlkIiwibGFzdFNlcSI6MTIzNDB9",
      "nextCursor": "eyJjb252SWQiOiJ1dWlkIiwibGFzdFNlcSI6MTIyOTB9",
      "hasMore": true
    }
  }
}
```

**Cursor Decode Examples:**
```json
// Message history cursor
base64_decode("eyJjb252SWQiOiJ1dWlkIiwibGFzdFNlcSI6MTIzNDV9")
→ {"convId": "uuid", "lastSeq": 12345}

// Conversation list cursor
base64_decode("eyJsYXN0TWVzc2FnZVNlcSI6MTIzNDUsImxhc3RDb252ZXJzYXRpb25JZCI6InV1aWQifQ")
→ {"lastMessageSeq": 12345, "lastConversationId": "uuid"}
```

---

## 17) Security & Encryption

### 17.1 Message Encryption Strategy

```
┌─────────────────────────────────────────────────────────┐
│                  ENCRYPTION LAYERS                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Transport Layer: TLS 1.3 (HTTPS/WSS)                  │
│           ↓                                            │
│  Application Layer: Internal JWT (signed, not E2E)     │
│           ↓                                            │
│  Message Layer (Optional E2E):                         │
│    - Signal Protocol for 1:1 chats (opt-in)           │
│    - Server-side encryption at rest (AES-256)         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 17.2 Data at Rest Encryption

- **PostgreSQL**: Enable TDE (Transparent Data Encryption) via AWS RDS
- **Cassandra**: Enable encryption with AES-256
- **S3**: Server-side encryption (SSE-S3 or SSE-KMS)
- **Redis**: Enable TLS, use encrypted ElastiCache

### 17.3 Sensitive Data Handling

```yaml
PII_FIELDS:
  - phone_number: masked in logs (****1234)
  - firebase_uid: never logged
  - message_content: never logged (only metadata)
  - push_token: hashed in logs
  - ip_address: anonymized after 30 days

AUDIT_EVENTS:
  - login_success / login_failure
  - password_change (N/A for phone auth)
  - device_added / device_removed
  - admin_action_*
  - data_export_requested
  - account_deleted
```

---

## 18) Monitoring, Alerting & SLOs

### 18.1 Service Level Objectives (SLOs)

| Service | Metric | Target | Alert Threshold |
|---------|--------|--------|-----------------|
| API Gateway | Availability | 99.9% | < 99.5% |
| API Gateway | p95 Latency | < 200ms | > 500ms |
| Realtime Gateway | Connection Success | 99.9% | < 99% |
| Realtime Gateway | Message Delivery | 99.99% | < 99.9% |
| Message Delivery | End-to-End Latency | < 500ms p95 | > 1s |
| AI Service | Availability | 99% | < 95% |
| AI Service | p95 Latency | < 3s | > 5s |

### 18.2 Key Metrics & Alerts

```yaml
# Realtime Gateway
- alert: HighConnectionCount
  expr: gateway_active_connections > 100000
  for: 5m
  severity: warning

- alert: MessageDeliveryLatencyHigh
  expr: histogram_quantile(0.95, gateway_message_delivery_seconds) > 1
  for: 5m
  severity: critical

# Kafka
- alert: ConsumerLagHigh
  expr: kafka_consumer_lag > 10000
  for: 10m
  severity: warning

# Database
- alert: DatabaseConnectionPoolExhausted
  expr: hikari_connections_active / hikari_connections_max > 0.9
  for: 5m
  severity: critical

# AI Service
- alert: AIFallbackRateHigh
  expr: rate(ai_ollama_requests_total[5m]) / rate(ai_total_requests[5m]) > 0.5
  for: 15m
  severity: warning
```

### 18.3 Distributed Tracing

```yaml
# OpenTelemetry Configuration
tracing:
  exporter: otlp
  endpoint: http://otel-collector:4317
  sampling:
    default: 0.1        # 10% of requests
    error: 1.0          # 100% of errors
    slow_threshold: 1s  # trace if > 1s

propagation:
  headers:
    - traceparent
    - tracestate
    - x-request-id
```

---

## 19) CI/CD Pipeline

### 19.1 Pipeline Stages

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Run Tests
        run: ./gradlew test
      - name: Upload Coverage
        uses: codecov/codecov-action@v4

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Build Docker Images
        run: |
          docker build -t ott-auth-service:${{ github.sha }} ./services/auth
          docker build -t ott-user-service:${{ github.sha }} ./services/user
          # ... other services

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Staging EKS
        run: |
          kubectl set image deployment/auth-service \
            auth-service=ott-auth-service:${{ github.sha }}

  deploy-production:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy to Production EKS (Canary)
        run: |
          # Canary deployment: 10% traffic first
          kubectl apply -f k8s/canary/
```

### 19.2 Kubernetes Deployment Example

```yaml
# k8s/auth-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: ott-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
        - name: auth-service
          image: ott-auth-service:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "kubernetes"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: ott-backend
spec:
  selector:
    app: auth-service
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: auth-service-hpa
  namespace: ott-backend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: auth-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

---

## 20) Performance & Capacity Planning

### 20.1 Load Estimates (Target Scale)

| Metric | Target |
|--------|--------|
| DAU (Daily Active Users) | 1,000,000 |
| Peak Concurrent Connections | 200,000 |
| Messages/day | 50,000,000 |
| Peak Messages/second | 2,000 |
| Media Uploads/day | 5,000,000 |
| Average Message Size | 500 bytes |

### 20.2 Resource Sizing (Initial)

| Component | Instance Type | Count | Notes |
|-----------|---------------|-------|-------|
| Realtime Gateway | c6i.2xlarge | 10 | 20K connections each |
| API Services | m6i.large | 3 each | Auto-scale to 10 |
| PostgreSQL | db.r6g.xlarge | 1 primary + 2 read | Multi-AZ |
| Cassandra | i3.xlarge | 6 nodes | 3-node replication |
| Redis | cache.r6g.large | 3 nodes | Cluster mode |
| Kafka (MSK) | kafka.m5.large | 6 brokers | 3 AZs |

### 20.3 Database Partitioning Strategy

```sql
-- PostgreSQL: Partition conversation_metadata by conversation_id hash
CREATE TABLE conversation_metadata (
    conversation_id UUID NOT NULL,
    -- ... other columns
) PARTITION BY HASH (conversation_id);

CREATE TABLE conversation_metadata_p0 PARTITION OF conversation_metadata
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE conversation_metadata_p1 PARTITION OF conversation_metadata
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
-- ... p2, p3
```

```cql
-- Cassandra: Already partitioned by conversation_id
-- Add TTL for auto-expiration of old messages
ALTER TABLE messages_by_conversation 
    WITH default_time_to_live = 31536000; -- 1 year
```

---

## 21) Project Structure (Recommended)

```
cnm-zalo-clone/
├── docs/
│   ├── OTT_AI_Agent_Project_Docs.md
│   └── OTT_Zalo_Complete_Database_Schema.md
├── backend/
│   ├── services/
│   │   ├── auth-service/
│   │   ├── user-service/
│   │   ├── social-service/
│   │   ├── conversation-service/
│   │   ├── message-service/
│   │   ├── media-service/
│   │   ├── notification-service/
│   │   ├── analytics-service/
│   │   ├── ai-service/
│   │   ├── call-service/           # Voice/Video calls (WebRTC)
│   │   ├── story-service/          # Stories 24h (Nhật ký)
│   │   ├── timeline-service/       # Newsfeed posts
│   │   ├── sticker-service/        # Sticker packs + AI
│   │   ├── qr-service/             # QR codes & short links
│   │   ├── backup-service/         # Local backup/restore
│   │   └── moderation-service/     # Reports & admin actions
│   ├── realtime-gateway/
│   │   └── (Netty WebSocket + WebRTC signaling)
│   ├── turn-server/                # ⭐ NEW - TURN/STUN for WebRTC
│   ├── shared/
│   │   ├── common-dto/
│   │   ├── common-security/
│   │   ├── common-kafka/
│   │   └── common-webrtc/          # ⭐ NEW
│   ├── docker-compose.yml
│   └── build.gradle (or pom.xml)
├── frontend/
│   ├── mobile/                     # React Native
│   │   ├── src/
│   │   │   ├── screens/
│   │   │   │   ├── auth/
│   │   │   │   ├── chat/
│   │   │   │   ├── call/           # ⭐ NEW
│   │   │   │   ├── story/          # ⭐ NEW
│   │   │   │   ├── timeline/       # ⭐ NEW
│   │   │   │   └── profile/
│   │   │   ├── components/
│   │   │   ├── hooks/
│   │   │   ├── stores/
│   │   │   ├── services/
│   │   │   └── utils/
│   │   └── package.json
│   └── web/                        # React/Next.js
│       ├── src/
│       └── package.json
├── k8s/
│   ├── base/
│   ├── staging/
│   └── production/
├── terraform/
│   ├── modules/
│   └── environments/
└── scripts/
    ├── setup-local.sh
    └── seed-data.sh
```

---

## 22) Implementation Roadmap

#### Phase 1: Foundation (Weeks 1-4)
- [ ] Set up monorepo structure
- [ ] Configure local Docker Compose stack
- [ ] Implement Auth Service (Firebase + JWT)
- [ ] Implement User/Profile Service
- [ ] Basic React Native app with login

#### Phase 2: Core Messaging (Weeks 5-8)
- [ ] Implement Conversation Service
- [ ] Implement Message Service (Cassandra)
- [ ] Build Netty Realtime Gateway
- [ ] WebSocket integration in mobile app
- [ ] Basic 1:1 chat functionality
- [ ] Message types: text, reply, forward

#### Phase 3: Social & Groups (Weeks 9-12)
- [ ] Implement Social Graph Service
- [ ] Friend request flow
- [ ] Group chat functionality (up to 1000 members)
- [ ] Group management (roles: Owner/Admin/Member)
- [ ] @Mention in groups

#### Phase 4: Media & Stickers (Weeks 13-16)
- [ ] Implement Media Service (S3 uploads up to 1GB)
- [ ] Thumbnail generation pipeline
- [ ] Image/Video/File/Voice messages
- [ ] Implement Sticker Service
- [ ] Sticker packs & download
- [ ] zSticker AI generation

#### Phase 5: Calls (Weeks 17-20) ⭐ NEW
- [ ] Implement Call Service
- [ ] Setup WebRTC TURN/STUN server
- [ ] Voice call 1:1
- [ ] Video call 1:1
- [ ] Group voice/video call (up to 20)
- [ ] Screen sharing

#### Phase 6: Story & Timeline (Weeks 21-24) ⭐ NEW
- [ ] Implement Story Service (Nhật ký)
- [ ] Story with 24h expiration
- [ ] Story views, reactions, replies
- [ ] Close friends feature
- [ ] Implement Timeline Service (Newsfeed)
- [ ] Posts with likes, comments, shares

#### Phase 7: Notifications & QR (Weeks 25-28)
- [ ] Push notification service (FCM/APNs)
- [ ] Implement QR & Link Service
- [ ] Personal QR codes
- [ ] Group invite links
- [ ] Notification center

#### Phase 8: AI & Analytics (Weeks 29-32)
- [ ] Implement AI Service (Gemini + Ollama)
- [ ] Quick Reply suggestions
- [ ] Message summary
- [ ] Smart translation
- [ ] Analytics pipeline
- [ ] Admin dashboard

#### Phase 9: Production Readiness (Weeks 33-36)
- [ ] Security hardening
- [ ] Performance testing (1M+ DAU target)
- [ ] Kubernetes deployment
- [ ] Monitoring & alerting setup
- [ ] Documentation finalization

---

## 23) Decisions Log (Resolved)

> Các quyết định đã được đưa ra trong tài liệu này.

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| D1 | Realtime Protocol | **JSON over WebSocket** | Đơn giản hơn Protobuf, dễ debug, đủ cho hầu hết use cases |
| D2 | Message ID Generation | **Gateway generates** | Fast ACK, không cần đợi Message Service |
| D3 | Conversation Settings Owner | **Conversation Service** | Single source of truth |
| D4 | RDBMS Choice | **PostgreSQL** | JSONB support tốt, extensions phong phú |
| D5 | Read Tracking Strategy | **Cursor-based** | Scale tốt hơn per-message receipts |
| D6 | Device Service | **Merge into Auth** | Giảm complexity |
| D7 | Message Ordering | **(Deprecated)** | See D8 |
| **D8** | **Message Ordering** | **`serverSeq` per conversation** | Monotonic sequence, no timestamp collision |
| **D9** | **Receipt Semantics** | **User-level (any-device)** | Giống Zalo: delivered/seen khi bất kỳ device nào nhận/đọc |
| **D10** | **Cursor Format** | **Per use case: message `{convId,lastSeq}`, conversation list `{lastMessageSeq,lastConversationId}`** | Tránh nhầm lẫn giữa các loại pagination |
| **D11** | **Metadata Ownership** | **Message Service owns unread/lastMessage** | Single source of truth, avoid cross-service queries |
| **D12** | **Idempotency Key** | **`clientMessageId` (persistent store + Redis)** | Reliable hơn TTL-based dedupe, survive restarts |

---

## 23.1) Implementation Checklist (Post-Feedback v7)

> **Critical validations** để đảm bảo implementation đúng architecture decisions

**Gateway & Idempotency:**
- [ ] Gateway retry muộn (sau cache expiration) vẫn trả ACK đúng `messageId/serverSeq` cũ (query idempotency store nếu Redis miss)
- [ ] Redis dedupe cache lưu **cả messageId và serverSeq**, không chỉ messageId
- [ ] Redis TTL >= 24h (hoặc 7d khớp Cassandra lookup TTL) để giảm query idempotency store
- [ ] Idempotency resolution flow đầy đủ (Redis → Cassandra lookup → allocate new)

**Cursor Format:**
- [ ] Message history cursor: `base64({convId, lastSeq})`
- [ ] Conversation list cursor: `base64({lastMessageSeq, lastConversationId})` hoặc `{lastUpdatedAt, convId}`
- [ ] API responses trả đúng cursor type cho từng endpoint
- [ ] Client không nhầm lẫn 2 loại cursor

**Receipt Schema:**
- [ ] `message_receipt` table có PK `(conversation_id, message_id, user_id)` ở cả Section 5 và Section 15
- [ ] User-level receipts được implement đúng (1 device ACK → mark cho cả user)

**serverSeq Generation:**
- [ ] Redis INCR với `min-replicas-to-write 1` + `min-replicas-max-lag 10`
- [ ] Redis persistence: AOF enabled + replication config đúng
- [ ] Có monitoring cho sequence gap/rollback khi Redis failover

**Idempotency Storage:**
- [ ] Cassandra `message_idempotency_by_sender` với TTL 7d
- [ ] Event consumers implement idempotent với eventId hoặc messageId

---

## 24) Open Questions (To Decide During Implementation)

- [ ] **E2E Encryption**: Có implement Signal Protocol không? Hay chỉ TLS?
- [ ] **Message Retention**: 1 năm default? Configurable per conversation?
- [ ] **Multi-device Sync**: Sync toàn bộ history hay chỉ recent?
- [ ] **Voice/Video Call**: Phase 2? Dùng WebRTC hay third-party?
- [ ] **Offline Queue**: Queue bao nhiêu messages khi offline?
- [ ] **Search**: Full-text search trong messages? Elasticsearch?
- [ ] **Backup/Export**: Cho phép user export chat history?

---

## Appendix A: Quick Reference Commands

```bash
# ==========================================
# Local Development
# ==========================================
docker compose up -d                          # Start infra
./gradlew :services:auth-service:bootRun     # Start auth service
./gradlew test                                # Run all tests

# ==========================================
# Database
# ==========================================
psql -h localhost -U ott -d ott              # Connect PostgreSQL
redis-cli -h localhost                        # Connect Redis
redis-cli MONITOR                             # Monitor Redis commands

# ==========================================
# Kafka (if using)
# ==========================================
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic topic.message-events --from-beginning

kafka-console-producer --bootstrap-server localhost:9092 \
  --topic topic.message-events

# ==========================================
# Kubernetes (Production)
# ==========================================
kubectl get pods -n ott-backend              # List pods
kubectl logs -f deployment/auth-service      # View logs
kubectl rollout restart deployment/auth-service  # Restart
kubectl port-forward svc/auth-service 8080:80    # Port forward

# ==========================================
# Debugging
# ==========================================
curl -X POST http://localhost:8080/api/v1/auth/firebase/verify \
  -H "Content-Type: application/json" \
  -d '{"firebaseIdToken": "..."}'

wscat -c "ws://localhost:8081/ws?token=JWT_TOKEN"  # Test WebSocket
```

---

## Appendix B: Environment Variables

```bash
# ==========================================
# Auth Service
# ==========================================
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_JSON=path/to/service-account.json
JWT_SECRET=your-super-secret-key-min-32-chars
JWT_TTL_SECONDS=3600
REFRESH_TTL_SECONDS=2592000

# ==========================================
# Database
# ==========================================
DB_URL=jdbc:postgresql://localhost:5432/ott
DB_USER=ott
DB_PASS=ott
DB_POOL_SIZE=10

# ==========================================
# Redis
# ==========================================
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# ==========================================
# Kafka (Optional)
# ==========================================
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_CONSUMER_GROUP=ott-services

# ==========================================
# Media/S3
# ==========================================
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=ott-media
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_REGION=us-east-1
MEDIA_BASE_URL=http://localhost:9000/ott-media

# ==========================================
# AI Service (Production only)
# ==========================================
GEMINI_API_KEY=your-gemini-api-key
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2
AI_RATE_LIMIT_RPM=10
AI_CIRCUIT_BREAKER_TTL_SECONDS=300

# ==========================================
# Push Notifications
# ==========================================
FCM_PROJECT_ID=your-firebase-project
FCM_SERVICE_ACCOUNT_JSON=path/to/fcm-service-account.json
```

---

## Appendix C: Useful Links

**Backend:**
- [Spring Boot 3.x](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Spring WebSocket](https://docs.spring.io/spring-framework/reference/web/websocket.html)
- [Netty](https://netty.io/wiki/)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)

**Database:**
- [PostgreSQL](https://www.postgresql.org/docs/)
- [Apache Cassandra](https://cassandra.apache.org/doc/latest/)
- [Redis](https://redis.io/docs/)

**Messaging:**
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Redpanda](https://docs.redpanda.com/) (Kafka alternative cho local dev)

**Frontend:**
- [React Native](https://reactnative.dev/docs/getting-started)
- [Expo](https://docs.expo.dev/)
- [Zustand](https://docs.pmnd.rs/zustand/getting-started/introduction)
- [React Query](https://tanstack.com/query/latest)

**AI (Production):**
- [Google Gemini API](https://ai.google.dev/docs)
- [Ollama](https://ollama.ai/)

**DevOps:**
- [Docker Compose](https://docs.docker.com/compose/)
- [Kubernetes](https://kubernetes.io/docs/)
- [AWS EKS](https://docs.aws.amazon.com/eks/)

---

## Appendix D: Zalo Features Mapping

### Messaging & Communication

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Phone OTP Login | ✅ | Firebase Auth |
| Profile (name, avatar, bio, cover) | ✅ | |
| Privacy Settings | ✅ | Last seen, story visibility, etc. |
| Friend Request | ✅ | With source tracking |
| Block User | ✅ | |
| Contact Sync | ✅ | Match phone contacts |
| 1:1 Chat | ✅ | Direct message |
| Group Chat (up to 1000 members) | ✅ | With roles: Owner/Admin/Member |
| Send Text | ✅ | Up to 1500 chars |
| Send Image/Video | ✅ | Multiple files |
| Send File | ✅ | Up to 1GB |
| Voice Message | ✅ | Up to 5 minutes |
| Reply Message | ✅ | |
| React Message | ✅ | 6 emoji types |
| Recall Message | ✅ | Within 24h |
| Forward Message | ✅ | |
| @Mention | ✅ | In groups |
| Pin Message | ✅ | |
| Typing Indicator | ✅ | |
| Read Receipts | ✅ | Cursor-based (user-level) |
| Online Status | ✅ | |
| Push Notification | ✅ | FCM/APNs |
| Mute Conversation | ✅ | |
| Pin Conversation | ✅ | |
| Hide Conversation | ✅ | |
| Poll in Chat | ✅ | Create polls in groups |

### Calls

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Voice Call 1:1 | ✅ | WebRTC |
| Video Call 1:1 | ✅ | WebRTC |
| Group Voice Call | ✅ | Up to 20 participants |
| Group Video Call | ✅ | Up to 20 participants |
| Screen Sharing | ✅ | In video calls |
| Call History | ✅ | Missed, incoming, outgoing |

### Stickers

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Sticker Packs | ✅ | Download from store |
| Animated Stickers | ✅ | GIF/Lottie |
| zSticker AI | ✅ | AI-generated stickers |
| Recent Stickers | ✅ | Usage tracking |
| Sticker Search | ✅ | By keywords |

### Story (Nhật ký)

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Post Story (Image/Video/Text) | ✅ | 24h expiration |
| Story Background & Fonts | ✅ | For text stories |
| Story Reactions | ✅ | |
| Story Replies | ✅ | Private message |
| Story Views | ✅ | See who viewed |
| Story Highlights | ✅ | Save beyond 24h |
| Close Friends | ✅ | Restricted visibility |

### Timeline (Newsfeed)

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Create Post | ✅ | Text + multiple images/videos |
| Like/React Post | ✅ | 6 emoji types |
| Comment on Post | ✅ | Nested replies |
| Tag Friends | ✅ | |
| Share Post | ✅ | |
| Post Visibility | ✅ | Public/Friends/Only Me |
| Feeling/Activity | ✅ | |
| Check-in Location | ✅ | |

### QR & Links

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| Personal QR Code | ✅ | Add friend by QR |
| Group Invite QR | ✅ | Join group by QR |
| Share Link | ✅ | Short links |
| Scan QR to add friend | ✅ | |

### AI Features

| Zalo Feature | Status | Notes |
|--------------|--------|-------|
| AI Assistant | ✅ | Gemini + Ollama fallback |
| Quick Reply Suggestions | ✅ | AI-generated |
| Message Summary | ✅ | Opt-in |
| Smart Translation | ✅ | Real-time |
| Voice to Text | ✅ | |

**Legend:** ✅ Core Feature (Fully Supported)

---

**End of Document**

> Last updated: 2026-01-16
> Version: 3.0 - Full Zalo Features (16 Services)

