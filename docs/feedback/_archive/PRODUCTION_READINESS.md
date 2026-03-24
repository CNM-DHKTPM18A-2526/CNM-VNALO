# VNALO — Production Readiness Checklist

> **Mục tiêu:** Phase 1 deployment (~10k user)
> **Cập nhật:** 2026-02-27 (commit `7ef8462`)

> Reconcile update (2026-03-20): Một số mục trong checklist gốc đã thay đổi trạng thái theo code hiện tại (đặc biệt CORS). Xem trạng thái đã cập nhật bên dưới.

---

## Blocker (Phải fix trước khi deploy)

- [x] **SEQ-001**: Thay `getNextSeq()` in-memory Map bằng Redis INCR  ✅ `33c68d5`
  - Sử dụng Redis `INCR conv:{id}:seq` — atomic, distributed-safe
  - Khởi tạo từ DB MAX(server_seq) bằng SETNX (tránh race condition)
  - File: `message.service.ts` → `getNextSeq()`

- [ ] **PRES-001**: Giới hạn presence broadcast  
  - Hiện tại: `this.server.emit()` gửi ra tất cả client  
  - Cần: Chỉ gửi cho friend list hoặc conversation room members  
  - File: `chat.gateway.ts` → `handleConnection()`, `handleDisconnect()`

- [ ] **TLS-001**: Reverse proxy với TLS termination  
  - nginx hoặc Traefik phía trước  
  - Terminate HTTPS, proxy đến service qua HTTP internal  
  - WebSocket upgrade headers

---

## Cao (Nên fix trước deploy)

- [x] **CORS-001**: Restrict CORS origin  
  - REST và WebSocket đã dùng allow-list từ `CORS_ALLOWED_ORIGINS`.
  - Cần duy trì cấu hình domain đúng theo từng môi trường triển khai.

- [ ] **AUTH-001**: WebSocket token re-verification  
  - Handshake verify 1 lần, token hết hạn nhưng socket vẫn active  
  - Phương án: Middleware kiểm tra token mỗi N phút, disconnect nếu expired

- [ ] **REDIS-001**: Set Redis password đồng nhất mọi profile chạy  
  - `docker/docker-compose.yml` đã hỗ trợ `--requirepass` dạng optional.
  - `docker/docker-compose.infra.yml` vẫn chưa bật `requirepass`.
  - Cần thống nhất policy và env cho cả core-service/message-service.

- [x] **INBOX-001**: Wrap sendMessage + inbox update trong transaction  ✅ `33c68d5`
  - sendMessage sử dụng `dataSource.transaction()` bao gồm save message + batch inbox update
  - File: `message.service.ts` → `sendMessage()`

- [x] **INBOX-002**: Fix `markAsRead()` unread_count logic  ✅ `33c68d5`
  - Tính chính xác unread count bằng query COUNT thay vì hardcode 0
  - File: `message.service.ts` → `markAsRead()`

---

## Trung bình (Cải thiện dần)

- [ ] **MIG-001**: Tạo TypeORM migration files cho message-service  
  - Thay `synchronize: true` bằng migration  
  - Đảm bảo schema khớp với Flyway V8-V9

- [ ] **ENV-001**: Tạo `.env.example` cho cả 2 service  
  - Document tất cả env var cần thiết  
  - Bao gồm: `JWT_SECRET`, `DB_*`, `REDIS_*`, `FIREBASE_CREDENTIALS_PATH`

- [ ] **TEST-001**: WebSocket integration test  
  - Kiểm tra: connect, auth, join room, send/receive message  
  - Tool: socket.io-client trong test suite

- [ ] **TEST-002**: Concurrent message test  
  - Gửi N message cùng lúc trong 1 conversation  
  - Kiểm tra: `server_seq` unique, không duplicate

- [ ] **LOG-001**: Structured logging  
  - JSON format cho log aggregator  
  - Request ID correlation giữa 2 service

- [ ] **RACE-001**: Handle `createDirect()` concurrent race  
  - 2 user cùng tạo DM → unique constraint violation  
  - Catch exception → retry `findOne()`

---

## Thấp (Phase 2+)

- [ ] **RATE-001**: Rate limiting trên auth endpoints
- [ ] **KAFKA-001**: Dọn dẹp hoặc enable Kafka cho event-driven
- [ ] **SOCK-001**: Redis Adapter cho Socket.IO (multi-instance)
- [ ] **MON-001**: Prometheus + Grafana monitoring stack
- [ ] **CI-001**: GitHub Actions CI/CD pipeline

---

## Đã fix trong commit `33c68d5` (ngoài danh sách gốc)

| Fix | Mô tả |
|-----|-------|
| UNIQUE constraints | `(conversation_id, server_seq)` + `(sender_id, client_message_id)` |
| Batch inbox update | Thay N queries sequential → 1 batch INSERT ON CONFLICT |
| N+1 inbox query | `getInbox` dùng IN clause thay N x findOne |
| editMessage | Uncomment method bị comment out → controller hoạt động |
| Recall time limit | Giới hạn 24h, xóa media/pin/reactions |
| Recall broadcast | WebSocket `message.recall` event |
| Content validation | TEXT phải có content, media phải có mediaUrl |
| Forward auth | Kiểm tra quyền truy cập conversation nguồn |
| Member limit | Enforce `memberLimit` khi addMembers |
| Connection pool | 10 → 50 connections |

---

## Điều kiện tối thiểu cho deployment

```
[DONE]  SEQ-001 + INBOX-001 + INBOX-002
[MUST]  PRES-001 + TLS-001
[SHOULD] AUTH-001 + REDIS-001
[MAY]   Còn lại
```

Còn ~8h engineering effort để đạt mức deploy được cho 10k user beta (giảm từ ~16h ban đầu).
