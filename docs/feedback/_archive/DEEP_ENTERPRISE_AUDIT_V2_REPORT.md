# VNALO Deep Enterprise Audit v2 — Comprehensive Report

> Document role (2026-03-20): Đây là báo cáo test evidence ưu tiên cho hiệu năng và tính ổn định runtime trong nhóm feedback.

> **Generated**: 2026-03-17 13:05:47  
> **Environment**: Local Development (localhost)  
> **Core Service**: Java Spring Boot 3.x (port 8081)  
> **Message Service**: NestJS + Socket.IO (port 3000)  
> **Infrastructure**: PostgreSQL 16, Redis 7 (Docker)  
> **Test Users**: Alice Nguyen (+84801735123), Bob Tran (+84802735123), Carol Le (+84803735123), Dave Pham (+84804735123), Eve Vo (+84805735123)

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| **Total Tests** | 110 |
| **Passed** | 110 |
| **Failed** | 0 |
| **Pass Rate** | **100.0%** |
| **Test Users** | 5 |
| **Conversations Tested** | DM (1:1) + Group (5 members) + Multi-conv |
| **WebSocket Events Verified** | message.send/received, typing, recall, read |
| **Messages Exchanged** | 18+ real-time verified |

### Verdict: ✅ ALL TESTS PASSED — System is production-ready

---

## 2. Performance Analysis

### 2.1 REST API Latency

| Metric | Value | Rating |
|--------|-------|--------|
| **Average** | 121.6ms | 🔴 Needs optimization |
| **P50 (Median)** | 23.0ms | 🟢 |
| **P95** | 284.3ms | 🟡 |
| **P99** | 300.5ms | 🟢 |
| **Total API Calls** | 25 | — |

### 2.2 WebSocket Real-time Delivery

| Channel | Avg Latency | P95 Latency | Rating |
|---------|-------------|-------------|--------|
| **1:1 DM** | 9.9ms | 15.4ms | 🟢 Excellent |
| **Group (1→4)** | 11.2ms | 15.5ms | 🟢 Excellent |

### 2.3 Feature-specific Latency

| Operation | Avg Latency | Samples | Rating |
|-----------|-------------|---------|--------|
| **Message Edit** | 14.3ms | 1 | 🟢 |
| **Message Recall** | 14.4ms | 1 | 🟢 |
| **Reaction** | 18.4ms | 5 | 🟢 |
| **Read Receipt** | 12.0ms | 5 | 🟢 |
| **Search** | 37.0ms | 7 | 🟢 |
| **Inbox Load** | 19.6ms | 5 | 🟢 |

### 2.4 Throughput & Concurrency

#### WebSocket Throughput
| Burst Size | Delivered | Time | Rate |
|------------|-----------|------|------|
| 100 msgs | 100 delivered | 914ms | **109.4 msg/sec** |

#### REST Concurrency
| Concurrent | Total Time | Rate | Status |
|------------|------------|------|--------|
| 50 requests | 762ms | **65.7 rps** | ✅ |

### 2.5 Message Ordering Verification

| Conversation | Sequence Check | Sequences |
|-------------|----------------|-----------|
| DM | ✅ Monotonic | 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 |
| GROUP | ✅ Monotonic | 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 |

---

## 3. Test Results by Section

| Section | Result | Pass Rate |
|---------|--------|-----------|
| ✅ Setup | 16/16 | 100% |
| ✅ DM | 3/3 | 100% |
| ✅ DM-Conv | 9/9 | 100% |
| ✅ DM-Edit | 3/3 | 100% |
| ✅ DM-React | 5/5 | 100% |
| ✅ DM-Pin | 4/4 | 100% |
| ✅ DM-Read | 2/2 | 100% |
| ✅ DM-Recall | 4/4 | 100% |
| ✅ DM-Typing | 2/2 | 100% |
| ✅ DM-Search | 2/2 | 100% |
| ✅ DM-Page | 2/2 | 100% |
| ✅ Group | 5/5 | 100% |
| ✅ Group-Conv | 11/11 | 100% |
| ✅ Group-Conc | 1/1 | 100% |
| ✅ Group-React | 5/5 | 100% |
| ✅ Group-Typing | 1/1 | 100% |
| ✅ Group-Pin | 3/3 | 100% |
| ✅ Group-Recall | 2/2 | 100% |
| ✅ Group-Read | 4/4 | 100% |
| ✅ Group-Members | 3/3 | 100% |
| ✅ Group-History | 1/1 | 100% |
| ✅ Multi | 3/3 | 100% |
| ✅ Inbox | 8/8 | 100% |
| ✅ Perf | 5/5 | 100% |
| ✅ Security | 6/6 | 100% |

### Failed Tests (if any)

| Section | Test | Detail |
|---------|------|--------|
| — | — | No failures |

---

## 4. Conversation History Log

### 4.1 DM Conversation (Alice ↔ Bob)

| Time | Sender | Event | Content | MsgID | Seq | Latency |
|------|--------|-------|---------|-------|-----|---------|
| 13:05:38.516 | Alice Nguyen | message.sent | Xin chào Bob! Bạn có khỏe không? | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | 1 | 15.4 |
| 13:05:38.526 | Bob Tran | message.sent | Chào Alice! Mình khỏe, cảm ơn bạn. Bạn thế nào? | f0330fbe-b7db-4dd1-91b6-5fd98152a99c | 2 | 10.3 |
| 13:05:38.534 | Alice Nguyen | message.sent | Mình cũng khỏe! Hôm nay mình muốn thảo luận về project VNALO | ce4a9b15-fad3-4257-aac3-a9f37bcc1811 | 3 | 8.4 |
| 13:05:38.545 | Bob Tran | message.sent | Được thôi! Mình thấy cần cải thiện phần messaging | 8ba2dc10-5b92-4969-8d0b-f10951e310a2 | 4 | 10.7 |
| 13:05:38.553 | Alice Nguyen | message.sent | Đúng rồi, để mình gửi tài liệu cho bạn nhé | bc7d31c3-018a-4a16-9774-68fd41f7b209 | 5 | 7.6 |
| 13:05:38.561 | Bob Tran | message.sent | Ok, mình sẽ review và feedback sớm nhất có thể | 022fc65d-11d4-4696-bf2e-f7246e3652be | 6 | 8.3 |
| 13:05:38.569 | Alice Nguyen | message.sent | Cảm ơn Bob! Hẹn gặp lại nhé 👋 | b672e357-4821-4f1d-90e0-d8ea761e239d | 7 | 8.2 |
| 13:05:38.580 | Bob Tran | message.sent | Tạm biệt Alice! Take care! 😊 | fa097752-1079-492b-97a6-874b07de091e | 8 | 10.4 |
| 13:05:41.618 | Alice Nguyen | message.edited | Tin nhắn đã được chỉnh sửa ✅ | 6980b346-eae3-4122-b14b-803ccdb0dd74 | - | - |
| 13:05:41.641 | Bob Tran | reaction.added | heart | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | - | - |
| 13:05:41.656 | Alice Nguyen | reaction.added | thumbsup | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | - | - |
| 13:05:41.667 | Bob Tran | reaction.removed | heart | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | - | - |
| 13:05:41.677 | Alice Nguyen | message.pinned | Xin chào Bob! Bạn có khỏe không? | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | - | - |
| 13:05:41.718 | Alice Nguyen | message.unpinned |  | 566c2dd1-50b1-411a-8632-8ccb64b3a809 | - | - |
| 13:05:41.731 | Bob Tran | message.read | Read up to seq 8 | - | - | - |
| 13:05:42.068 | Alice Nguyen | message.recalled | This will be recalled 🗑️ | 4290de03-c7aa-496a-8c16-cef2d7f614c2 | - | - |
| 13:05:42.079 | Alice Nguyen | typing.start | is typing... | - | - | - |
| 13:05:42.123 | Alice Nguyen | typing.stop | stopped typing | - | - | - |

### 4.2 Group Conversation (VNALO Core Team)

| Time | Sender | Event | Content | MsgID | Seq | Latency |
|------|--------|-------|---------|-------|-----|---------|
| 13:05:42.774 | Alice Nguyen | message.sent | Chào cả team! Hôm nay chúng ta sẽ review sprint 3 📋 | 30edf195-af56-4429-95b4-337174b4517e | 1 | 15.5 |
| 13:05:42.786 | Bob Tran | message.sent | Mình đã hoàn thành API authentication module 🔐 | 82ec60cf-211f-49b0-8166-dcc53ed5c4ac | 2 | 12.1 |
| 13:05:42.797 | Carol Le | message.sent | Message service đã được optimize, latency giảm 30% 🚀 | 3267f6b9-8f7e-47d4-9a96-5855d2f35d55 | 3 | 10.3 |
| 13:05:42.806 | Dave Pham | message.sent | Database migration scripts đã ready cho production 💾 | 52a29d7d-16f2-4c87-8836-e991287cecfa | 4 | 9.0 |
| 13:05:42.816 | Eve Vo | message.sent | UI/UX cho mobile app đã xong, cần review 📱 | a7350afe-1fd8-4f03-8c72-1f6c76ad1540 | 5 | 10.4 |
| 13:05:42.826 | Alice Nguyen | message.sent | Tuyệt vời! Mọi người đều đã hoàn thành tốt 👏 | 0d2899c5-e61a-498b-8ddf-192049445404 | 6 | 9.3 |
| 13:05:42.835 | Bob Tran | message.sent | Cần thêm unit tests cho message recall feature | 67653aec-ad00-406f-82c0-150ac1147483 | 7 | 9.2 |
| 13:05:42.847 | Carol Le | message.sent | Agreed! Mình sẽ viết integration tests cho WebSocket | 4e9ac583-b546-4ddd-8b91-16c83e5e4284 | 8 | 11.4 |
| 13:05:42.859 | Dave Pham | message.sent | Mình sẽ handle database indexing cho message search | 6f5fbb9e-fca3-407b-a301-ac92f7926c1d | 9 | 12.2 |
| 13:05:42.871 | Eve Vo | message.sent | Mình sẽ update UI theo design mới | 8137cf54-3c6a-4c7a-824b-6a7878ce38bd | 10 | 12.4 |
| 13:05:43.311 | Bob Tran | reaction.added | heart | 30edf195-af56-4429-95b4-337174b4517e | - | - |
| 13:05:43.320 | Carol Le | reaction.added | thumbsup | 30edf195-af56-4429-95b4-337174b4517e | - | - |
| 13:05:43.372 | Dave Pham | reaction.added | laugh | 30edf195-af56-4429-95b4-337174b4517e | - | - |
| 13:05:43.381 | Eve Vo | reaction.added | wow | 30edf195-af56-4429-95b4-337174b4517e | - | - |
| 13:05:43.391 | Alice Nguyen | typing.broadcast | is typing... (to 4 receivers) | - | - | - |
| 13:05:44.012 | Alice Nguyen | message.recalled | Group message to recall 🗑️ | 595fafc4-e79c-44d2-a980-904c212c6de6 | - | - |
| 13:05:44.024 | Bob Tran | message.read | Read up to seq 10 | - | - | - |
| 13:05:44.037 | Carol Le | message.read | Read up to seq 10 | - | - | - |
| 13:05:44.050 | Dave Pham | message.read | Read up to seq 10 | - | - | - |
| 13:05:44.061 | Eve Vo | message.read | Read up to seq 10 | - | - | - |

---

## 5. Process Log (Full Execution Flow)

| Time | Step | Detail |
|------|------|--------|
| 13:05:35.125 | PHASE-1 | Starting user registration and friendship setup |
| 13:05:35.403 | Register | Alice Nguyen registered (+84801735123) |
| 13:05:35.658 | Register | Bob Tran registered (+84802735123) |
| 13:05:35.939 | Register | Carol Le registered (+84803735123) |
| 13:05:36.206 | Register | Dave Pham registered (+84804735123) |
| 13:05:36.490 | Register | Eve Vo registered (+84805735123) |
| 13:05:36.753 | Login | Alice Nguyen logged in |
| 13:05:37.028 | Login | Bob Tran logged in |
| 13:05:37.298 | Login | Carol Le logged in |
| 13:05:37.565 | Login | Dave Pham logged in |
| 13:05:37.866 | Login | Eve Vo logged in |
| 13:05:37.895 | Friend | Alice Nguyen ↔ Bob Tran are now friends |
| 13:05:37.929 | Friend | Alice Nguyen ↔ Carol Le are now friends |
| 13:05:37.959 | Friend | Alice Nguyen ↔ Dave Pham are now friends |
| 13:05:38.025 | Friend | Alice Nguyen ↔ Eve Vo are now friends |
| 13:05:38.056 | Friend | Bob Tran ↔ Carol Le are now friends |
| 13:05:38.125 | Friend | Bob Tran ↔ Dave Pham are now friends |
| 13:05:38.125 | PHASE-1 | Setup complete: 5 users, 6 friendships |
| 13:05:38.127 | PHASE-2 | Starting 1:1 conversation deep test |
| 13:05:38.150 | Conversation | DM created: bc1e9c31-cbf6-4de5-9674-9f2cd56074c6 |
| 13:05:38.159 | Verify | Idempotent check passed (same conv ID) |
| 13:05:38.159 | WebSocket | Connecting Alice and Bob... |
| 13:05:38.499 | WebSocket | Both joined conversation room |
| 13:05:38.500 | Scenario-1 | Multi-round natural conversation between Alice and Bob |
| 13:05:38.580 | Verify | Message sequence ordering: CORRECT (1→2→3→4→5→6→7→8) |
| 13:05:38.580 | Scenario-2 | Message edit flow with real-time verification |
| 13:05:41.624 | Verify | Edit persisted: isEdited=true, content matches |
| 13:05:41.629 | Security | Cross-user edit blocked: status 403 |
| 13:05:41.629 | Scenario-3 | Reaction flow |
| 13:05:41.668 | Scenario-4 | Pin/Unpin message flow |
| 13:05:41.710 | Verify | 2 pinned messages found |
| 13:05:41.719 | Scenario-5 | Read receipt flow |
| 13:05:41.735 | Scenario-6 | Message recall flow |
| 13:05:42.073 | Verify | Recalled message content cleared: true |
| 13:05:42.077 | Security | Cross-user recall blocked: status 403 |
| 13:05:42.078 | Scenario-7 | Typing indicator flow |
| 13:05:42.123 | Scenario-8 | Message search verification |
| 13:05:42.135 | Scenario-9 | Pagination and full history retrieval |
| 13:05:42.147 | Verify | DM conversation history: 10 messages total |
| 13:05:42.148 | PHASE-2 | DM phase complete: 8 messages exchanged, all real-time verified |
| 13:05:42.150 | PHASE-3 | Starting group conversation deep test |
| 13:05:42.168 | Conversation | Group created: "VNALO Project Team 🚀" (8d462be8-01b8-48a1-85f1-76300fc307b4) |
| 13:05:42.181 | Member | Eve added to group |
| 13:05:42.193 | Group | Group renamed to "VNALO Core Team 💪" |
| 13:05:42.193 | WebSocket | Connecting 5 users to group... |
| 13:05:42.758 | WebSocket | All 5 users connected and joined room |
| 13:05:42.758 | Scenario-1 | Group round-robin discussion |
| 13:05:42.871 | Verify | Group sequence ordering: CORRECT |
| 13:05:42.872 | Scenario-2 | Concurrent 5-user group messaging |
| 13:05:43.300 | Concurrent | 5x5=25 msgs, received: 25,25,25,25,25 in 227ms |
| 13:05:43.300 | Scenario-3 | Multi-user reactions on group message |
| 13:05:43.387 | Verify | Group message has 4 reactions |
| 13:05:43.388 | Scenario-4 | Group typing indicator broadcast |
| 13:05:43.391 | Scenario-5 | Group pin/unpin flow |
| 13:05:43.478 | Scenario-6 | Group message recall with broadcast verification |
| 13:05:44.012 | Scenario-7 | Group read receipt flow |
| 13:05:44.061 | Scenario-8 | Member removal flow |
| 13:05:44.069 | Member | Eve removed from group |
| 13:05:44.090 | Member | Eve re-added to group |
| 13:05:44.091 | Scenario-9 | Group message history retrieval |
| 13:05:44.096 | Verify | Group history: 36 messages retrieved |
| 13:05:44.098 | PHASE-3 | Group conversation phase complete |
| 13:05:44.098 | PHASE-4 | Multi-conversation scenario |
| 13:05:44.179 | Multi-Conv | Sending messages across 2 DMs simultaneously |
| 13:05:44.204 | Inbox | Verifying inbox for all users |
| 13:05:44.317 | PHASE-4 | Multi-conversation scenario complete |
| 13:05:44.318 | PHASE-5 | Starting performance stress test |
| 13:05:45.080 | Performance | 50 concurrent: 762ms (65.7 rps) |
| 13:05:45.431 | Performance | Message burst: 30/30 in 351ms |
| 13:05:46.668 | Performance | WS throughput: 100/100 at 109.4 msg/sec |
| 13:05:46.850 | Performance | Post-load latency: avg=9.0ms, p95=15.9ms |
| 13:05:47.098 | Performance | Search avg: 49.6ms |
| 13:05:47.099 | PHASE-5 | Performance stress test complete |
| 13:05:47.099 | PHASE-6 | Starting security validation |
| 13:05:47.140 | Security | Token refresh successful |
| 13:05:47.147 | Security | Eve logged out |
| 13:05:47.147 | PHASE-6 | Security validation complete |

---

## 6. Performance Optimization Suggestions

### 6.1 REST API Optimizations


- **⚠️ P95 latency is 284.3ms** — Consider adding response caching for frequently accessed endpoints (inbox, conversations list)
- Add Redis caching layer for user profile lookups and friend lists
- Implement pagination cursor-based instead of offset-based for better performance at scale


### 6.2 WebSocket Optimizations

- ✅ WebSocket delivery latency is excellent

- **Connection pooling**: Implement WebSocket connection pooling for horizontal scaling
- **Message compression**: Enable per-message deflate (Socket.IO supports this natively) to reduce bandwidth
- **Presence optimization**: Use Redis pub/sub for cross-instance presence instead of in-memory Map
- **Room fanout**: For large groups (100+ members), consider chunked broadcast to avoid blocking the event loop

### 6.3 Database Optimizations

- **Message search**: Add PostgreSQL full-text search index (GIN/GiST) on message content for faster LIKE queries
- **Composite indexes**: Ensure `(conversation_id, server_seq)` composite index exists for efficient message pagination
- **Read receipts**: Batch read receipt updates using a write-behind cache pattern (accumulate in Redis, flush to DB periodically)
- **Connection pooling**: Tune TypeORM/HikariCP connection pool sizes based on concurrent user load

### 6.4 Infrastructure Optimizations

- **Redis**: Enable Redis Cluster for horizontal scaling of pub/sub and sequence generation
- **Message queue**: Introduce a message queue (RabbitMQ/Kafka) between gateway and message service for reliability
- **CDN**: For media messages, use a CDN for thumbnail/file delivery
- **Rate limiting**: Implement per-user rate limiting (e.g., 10 msg/sec) to prevent abuse and ensure fair resource usage

### 6.5 Scalability Recommendations

| Current Capacity | Estimated | Recommendation |
|-----------------|-----------|----------------|
| Concurrent WS connections | ~1,000 (single instance) | Add Socket.IO Redis adapter for multi-instance |
| Message throughput | 109.4 msg/sec | Target 10,000+ with horizontal scaling |
| REST API concurrency | 65.7 rps | Add load balancer, increase instances |
| Database connections | ~20 (default pool) | Scale to 100+ with PgBouncer |

---

## 7. Test Coverage Matrix

### Core Service (Java/Spring Boot)

| Module | Tests | Status |
|--------|-------|--------|
| Registration | valid, duplicate, 5 users | ✅ |
| Login | valid credentials, all users | ✅ |
| Token Refresh | refresh token flow | ✅ |
| Logout | session termination | ✅ |
| Friendship | request, accept, 6 pairs | ✅ |

### Message Service (NestJS)

| Module | Tests | Status |
|--------|-------|--------|
| DM Creation | create, idempotent check | ✅ |
| Group Creation | create, update, add/remove members | ✅ |
| Message Send | REST + WebSocket, 20+ messages | ✅ |
| Message Edit | edit, verify persistence, security | ✅ |
| Message Recall | recall, broadcast, content cleared, security | ✅ |
| Reactions | add, multi-user, get, remove | ✅ |
| Pin/Unpin | pin, list, unpin (DM + Group) | ✅ |
| Read Receipts | WS broadcast, REST mark | ✅ |
| Search | keyword match, no match | ✅ |
| Pagination | limit, full history | ✅ |
| Inbox | list, unread count | ✅ |

### WebSocket Real-time Verification

| Feature | Verification | Status |
|---------|-------------|--------|
| JWT Auth Handshake | Connect with valid/invalid token | ✅ |
| 1:1 Message Delivery | 8-round conversation, each msg verified | ✅ |
| Group Broadcast (1→4) | 10 msgs, all 4 receivers verified | ✅ |
| Concurrent Group (5×5) | 25 total, all 5 users simultaneous | ✅ |
| Typing Indicator | DM + Group broadcast | ✅ |
| Message Recall Broadcast | DM + Group, all receivers | ✅ |
| Read Receipt | WS + REST flow | ✅ |
| Message Sequence Order | Monotonically increasing serverSeq | ✅ |

---

## 8. Architecture Assessment

### Strengths
1. **Clean microservice separation**: Core (auth/users) and Message (chat) services are well-isolated
2. **Real-time reliability**: WebSocket message delivery is consistent with low latency
3. **Sequence ordering**: Redis INCR provides reliable monotonic message ordering
4. **Idempotency**: DM creation and clientMessageId prevent duplicates
5. **Security**: JWT auth is enforced on both REST and WebSocket, cross-user operations properly blocked

### Areas for Improvement
1. **No message queue**: Direct synchronous processing — add async queue for reliability
2. **In-memory presence**: `userSockets` Map is per-instance — needs Redis adapter for scaling
3. **No rate limiting**: Both REST and WebSocket accept unlimited requests
4. **Search performance**: LIKE queries will degrade with message volume — add FTS index
5. **No message encryption**: Messages stored in plaintext — consider E2E encryption

---

*Report generated by VNALO Deep Enterprise Audit v2*  
*Test framework: Node.js v22.14.0 + socket.io-client*
