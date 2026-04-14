# Implementation Status

> Last updated: 2026-04-14

---

## Backend Runtime Status

| Service | Port | Status | Notes |
|--------|------|--------|-------|
| core-service | 8081 | ✅ Complete | Auth, user, social, QR, contact sync; Flyway owner |
| message-service | 3000 | ✅ Complete | Conversations, messages, inbox, Socket.IO gateway |
| media-service | 8083 | 🔄 In Progress | Upload/sticker APIs available; S3 and local fallback modes |
| realtime-gateway | 8085 | 🔄 In Progress | Redis-based WS adapter skeleton, health endpoint |
| moderation-service | 8082 | 🔄 In Progress | Moderation workflows, dedicated docs/runbooks |
| content-service | 8086 | 🧪 Scaffolded | Service scaffold in repo + compose |
| notification-service | 8087 | 🧪 Scaffolded | Service scaffold in repo + compose |
| ai-service | 8094 | 🧪 Experimental | Gemini + Ollama fallback service |
| analytics-service | 8084 (profile) | ⏳ Planned | Compose profile placeholder, source not yet present |

---

## Data and Migration Status

| Item | Status | Notes |
|------|--------|-------|
| PostgreSQL | ✅ Active | Primary persistent store |
| Redis | ✅ Active | Cache, presence/sequence support |
| Flyway | ✅ Active | V1 -> V13 in core-service |
| Message persistence | ✅ Active | PostgreSQL via TypeORM entities |
| Cassandra | ❌ Not runtime | Historical/planned references only in legacy docs |

---

## Frontend Status (Flutter Mobile)

| Area | Status | Notes |
|------|--------|-------|
| Project setup and env config | ✅ Complete | `--dart-define` driven environments |
| Authentication flow | ✅ Complete | Register/login/profile hydration with resilient fallback |
| Avatar upload flow | 🔄 Hardened | Retry + timeout handling + non-fatal completion path |
| Search + local sync remediation | ✅ Stabilized | Local-first search fallback, API normalization, post-auth sync ordering fixed |
| Notification messaging integration | ✅ Restored | `firebase_messaging` dependency re-aligned with `NotificationService` implementation |
| Chat/contact/profile feature modules | 🔄 In Progress | Module folders exist and active development ongoing |
| WebRTC voice/video call | 🧪 Prototype only | Mobile has UI + `flutter_webrtc` service, but end-to-end signaling is not complete yet |
| Test coverage (mobile unit) | 🔄 In Progress | Key config/auth service tests present |

---

## Verification Snapshot

| Track | Result |
|------|--------|
| core-service tests | ✅ pass in recent runs |
| node-services tests | ✅ available and executable from workspace |
| mobile unit tests (`flutter test`) | ✅ pass (latest run: all tests passed) |
| mobile static analysis (`flutter analyze`) | ✅ no errors/warnings (remaining info-level lint debt only) |
| smoke auth-avatar-inbox flow | ✅ pass in recent reconciled runs |
| docker compose runtime | ✅ infra + services compose definitions aligned with docs |

---

## Known Gaps / Next Priorities

1. Complete feature implementation for content-service and notification-service.
2. Finalize analytics-service source module (compose profile currently placeholder).
3. Continue strengthening end-to-end tests across mobile + media/realtime paths.
4. Keep docs synchronized after each service milestone.

---

## WebRTC Call Readiness (Voice/Video) — Detailed Assessment (Đánh giá chi tiết)

### 1) Implemented pieces (Những phần đã có trong code)

- Mobile đã có call UI riêng cho voice/video:
  - `frontend/mobile/lib/features/call/screens/voice_call_screen.dart`
  - `frontend/mobile/lib/features/call/screens/video_call_screen.dart`
- Mobile đã có `WebRtcCallService` dùng `flutter_webrtc`:
  - Tạo `RTCPeerConnection`, mở local media (`getUserMedia`)
  - Tạo/gửi SDP offer-answer
  - Gửi/nhận ICE candidate
  - Kết thúc cuộc gọi + timeout theo `CALL_RING_TIMEOUT_SECONDS` (mặc định 38 giây, khai báo tại `frontend/mobile/lib/features/call/services/webrtc_call_service.dart`)
- SocketService đã phát/nhận các event signaling:
  - emit: `call.offer`, `call.answer`, `call.ice-candidate`, `call.end`
  - listen: cùng các event trên + `call.signal`

### 2) Main blockers for end-to-end calling (Các blocker chính)

1. **Backend chưa có handler signaling call**
   - Trong `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts` chưa có `@SubscribeMessage` cho:
     - `call.offer`
     - `call.answer`
     - `call.ice-candidate`
     - `call.end`
   - `realtime-gateway` hiện cũng chưa có luồng relay signaling call.

2. **Thiếu luồng incoming call trên mobile**
   - `WebRtcCallService` hiện chỉ được khởi tạo từ màn chat khi người dùng **chủ động bấm gọi**, với `isCaller: true`.
   - Chưa thấy nơi nào khởi tạo service với `isCaller: false` để nhận offer/incoming call và phản hồi answer.

3. **`callId` không đồng bộ 2 đầu**
   - `VoiceCallScreen`/`VideoCallScreen` tự tạo `callId` theo timestamp local.
   - Service chỉ xử lý signal khi `conversationId` và `callId` trùng tuyệt đối.
   - Không có cơ chế đảm bảo phía nhận dùng đúng `callId` do phía gọi tạo.

4. **Hạ tầng NAT traversal mới dừng ở STUN**
   - Chỉ có Google STUN server, chưa có TURN relay.
   - Dù signaling hoàn chỉnh, call sẽ rớt cao ở mạng NAT/CGNAT khó.

### 3) Current conclusion (Kết luận thực trạng)

- **Chưa thể xác nhận “đã call được thật sự” cho cả voice/video theo E2E production flow.**
- Trạng thái hiện tại phù hợp với mức **prototype UI + local WebRTC plumbing**, chưa đủ để vận hành cuộc gọi ổn định giữa 2 user thật.
