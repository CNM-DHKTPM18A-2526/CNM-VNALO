# VNALO Mobile - Team Setup and Run Guide

Updated: 2026-04-05
Target readers: all team members (backend, mobile, QA)

This guide is a practical runbook to set up, run, debug, and troubleshoot the Flutter mobile app in this repository.

## 1. What This App Connects To

The mobile app talks to these backend services:

- `core-service`: auth/user/social APIs (default `:8081`)
- `message-service`: chat/inbox APIs + socket (default `:3000`)
- `media-service`: avatar/media upload APIs (default `:8083`)

Configuration is read from `--dart-define` values in `lib/main.dart`.

Supported runtime defines:

- `ENV` (`dev|staging|production`)
- `CORE_SERVICE_URL`
- `MESSAGE_SERVICE_URL`
- `MEDIA_SERVICE_URL`
- `SOCKET_URL`

## 2. Quick Start (If You Already Have Toolchains)

From `frontend/mobile`:

```bash
flutter pub get
flutter devices

# Android emulator (uses 10.0.2.2 for host machine)
flutter run \
	--dart-define=ENV=dev \
	--dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
	--dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
	--dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
	--dart-define=SOCKET_URL=http://10.0.2.2:3000
```

If using a physical phone, do not use `10.0.2.2`; see section 7 for network mapping.

## 3. Prerequisites by OS

## 3.1 Windows

Required:

- Flutter SDK (stable)
- Android Studio + Android SDK + emulator image
- JDK 17+ (for Android toolchain)
- Git

Recommended:

- VS Code with Flutter and Dart extensions

Check:

```powershell
flutter doctor -v
```

## 3.2 macOS

Required for Android only:

- Flutter SDK
- Android Studio + SDK

Required for iOS:

- Xcode + Xcode Command Line Tools
- CocoaPods

Checks:

```bash
flutter doctor -v
xcode-select -p
pod --version
```

## 3.3 Linux

Required:

- Flutter SDK
- Android Studio + SDK

Checks:

```bash
flutter doctor -v
```

Note: iOS build/run is not supported on Linux.

## 4. Backend Runtime Prerequisite

Mobile app requires backend services to be reachable from your device/emulator.

At repository root, bring up required services:

```powershell
docker compose -f docker/docker-compose.yml --env-file config/environments/.env up -d postgres redis rabbitmq core-service media-service message-service
docker compose -f docker/docker-compose.yml --env-file config/environments/.env ps
```

Expected ports:

- `8081` core
- `3000` message
- `8083` media

## 5. Project Bootstrap

From `frontend/mobile`:

```bash
flutter clean
flutter pub get
flutter pub deps --style=compact
```

Optional checks:

```bash
flutter analyze
flutter test
```

## 6. Running the App

## 6.1 Android Emulator (recommended first run)

```bash
flutter emulators
flutter emulators --launch <emulator_id>
flutter devices
```

Run:

```bash
flutter run \
	--dart-define=ENV=dev \
	--dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
	--dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
	--dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
	--dart-define=SOCKET_URL=http://10.0.2.2:3000
```

Why `10.0.2.2`: Android emulator special host alias for localhost of your dev machine.

## 6.2 Android Physical Device (USB)

1. Enable Developer Options and USB Debugging on phone.
2. Connect USB.
3. Verify device:

```bash
adb devices
flutter devices
```

4. Use your PC LAN IP (example `192.168.1.50`):

```bash
flutter run \
	--dart-define=ENV=dev \
	--dart-define=CORE_SERVICE_URL=http://192.168.1.50:8081/api/v1 \
	--dart-define=MESSAGE_SERVICE_URL=http://192.168.1.50:3000/api/v1 \
	--dart-define=MEDIA_SERVICE_URL=http://192.168.1.50:8083/api/v1 \
	--dart-define=SOCKET_URL=http://192.168.1.50:3000
```

## 6.3 iOS Simulator (macOS)

```bash
open -a Simulator
flutter devices

flutter run \
	--dart-define=ENV=dev \
	--dart-define=CORE_SERVICE_URL=http://127.0.0.1:8081/api/v1 \
	--dart-define=MESSAGE_SERVICE_URL=http://127.0.0.1:3000/api/v1 \
	--dart-define=MEDIA_SERVICE_URL=http://127.0.0.1:8083/api/v1 \
	--dart-define=SOCKET_URL=http://127.0.0.1:3000
```

## 6.4 iOS Physical Device (macOS)

Use Mac LAN IP in all URLs (similar Android physical device approach), then run on selected iPhone in Xcode/Flutter.

## 7. Network Mapping Matrix (Very Important)

Use correct host mapping based on where app runs:

| Target | Host to backend on your dev machine |
|---|---|
| Android emulator | `10.0.2.2` |
| iOS simulator | `127.0.0.1` or `localhost` |
| Physical Android/iOS | your dev machine LAN IP (ex: `192.168.x.x`) |

If app runs on physical device and cannot connect:

- Ensure phone and dev machine are on same Wi-Fi.
- Ensure firewall allows inbound ports `8081`, `3000`, `8083`.
- Ensure Docker services are mapped to `0.0.0.0` (already in compose default).

## 8. Wireless Debugging (Android)

This section covers cases where USB is unstable or team members need network-only debug.

## 8.1 Android 11+ (Wireless Debugging Pairing)

On phone:

1. Developer options -> Wireless debugging -> enable.
2. Choose pair device with pairing code.

On machine:

```bash
adb pair <phone_ip>:<pair_port>
# enter pairing code shown on phone

adb connect <phone_ip>:<debug_port>
adb devices
```

Then run Flutter normally with LAN IP backend URLs.

## 8.2 Legacy `adb tcpip` (when pairing flow unavailable)

1. Connect phone via USB once.
2. Run:

```bash
adb devices
adb tcpip 5555
adb connect <phone_ip>:5555
adb devices
```

3. Unplug USB, continue debug over network.

Security note: disable wireless debugging when done.

## 9. Team "Shared Wireless Debug" Workflow

When one device is shared across team members over same network:

1. Device owner enables wireless debugging and shares `ip:port` privately.
2. Each developer runs `adb connect <ip:port>`.
3. Only one active deploy/debug session should run at a time to avoid install conflicts.
4. Use a team lock protocol (simple chat message):
	 - `LOCK DEVICE <name> <duration>`
	 - `RELEASE DEVICE <name>`

Suggested naming for logs:

- Build variant tag: `<member>-<feature>-<timestamp>`

## 10. Useful Commands During Development

From `frontend/mobile`:

```bash
flutter devices
flutter run -d <device_id>
flutter logs
flutter attach
flutter hotreload
flutter test
flutter analyze
```

Android ADB helpers:

```bash
adb devices
adb kill-server
adb start-server
adb reverse --remove-all
adb reverse tcp:8081 tcp:8081
adb reverse tcp:3000 tcp:3000
adb reverse tcp:8083 tcp:8083
```

Note: `adb reverse` is optional and mostly useful in USB-debug scenarios.

## 11. Troubleshooting Playbook

## 11.1 App cannot call backend (timeout/refused)

Checklist:

1. Confirm service health via Docker.
2. Confirm correct URL host mapping from section 7.
3. Confirm firewall rules allow ports.
4. Confirm phone and dev machine share same network.

## 11.2 Login works but inbox/media fails

Possible causes:

- Message/media URL mismatch in `--dart-define`.
- Token refresh path issue from older build.

Action:

- Clean and rerun:

```bash
flutter clean
flutter pub get
flutter run ...
```

## 11.3 Device not found

```bash
adb devices
flutter devices
```

If empty:

- Reconnect USB or re-run wireless `adb connect`.
- Restart adb server.

## 11.4 Gradle or Android build cache issues

```bash
flutter clean
cd android
./gradlew clean    # Windows: gradlew.bat clean
cd ..
flutter pub get
flutter run
```

## 11.5 iOS signing errors (macOS)

- Open `ios/Runner.xcworkspace` in Xcode.
- Configure Team + Signing certificate.
- Retry `flutter run`.

## 12. Verification Checklist for New Team Members

A member is considered fully onboarded when all checks pass:

1. `flutter doctor -v` no blocking issues.
2. Device/emulator is visible in `flutter devices`.
3. App launches with dev URLs.
4. Register/login succeeds.
5. Inbox endpoint loads.
6. Avatar upload flow succeeds.

## 13. Recommended Team Convention

- Always run with explicit `--dart-define` in dev.
- Do not hardcode machine-specific IP inside source code.
- Keep `ENV=dev` for local testing.
- Before PR:
	- run `flutter analyze`
	- run `flutter test`
	- test one real login flow on device/emulator.

## 14. Related Files

- `lib/main.dart` (reads dart-defines)
- `lib/config/app_config.dart` (environment defaults)
- `lib/config/env.dart` (env model)
- `lib/services/auth_service.dart`
- `lib/services/api_service.dart`

## 15. Escalation Path

If blocked > 30 minutes:

1. Post logs and exact command in team channel.
2. Include:
	 - device type and OS
	 - exact `flutter run` command
	 - endpoint URLs used
	 - first failing stack trace.

This significantly reduces debug turnaround time for the team.

## Phân tích kỹ thuật mobile (hiệu năng, sẵn sàng, search, load dữ liệu, local DB)

Phần này mở rộng chi tiết theo code hiện tại trong `frontend/mobile/lib`, tập trung vào cách hệ thống đang vận hành thực tế, điểm mạnh, trade-off và các giới hạn cần theo dõi.

### 1) Search (Hybrid Search: local + remote)

#### 1.1 Cơ chế tìm kiếm local

- Dùng **SQLite FTS5** cho `messages_fts` và `contacts_fts` (`lib/core/database/local_database.dart`).
- Dùng trigger `AFTER INSERT/DELETE` để giữ index FTS đồng bộ với bảng gốc (`messages`, `contacts`).
- Query message search:
  - match trên FTS (`MATCH '$query*'`)
  - join qua `conversations` để lấy tên/ảnh hội thoại phục vụ render kết quả.
- Query contact search:
  - kết hợp FTS (`display_name MATCH`) + phone `LIKE` để xử lý cả trường hợp người dùng gõ số điện thoại.

**Ý nghĩa hiệu năng:**
- FTS5 cho độ trễ thấp hơn so với `LIKE '%...%'` trên dữ liệu text dài.
- Trigger giúp tránh “rebuild index toàn bộ” sau mỗi lần sync.

#### 1.2 Cơ chế hybrid search trên UI

Trong `UnifiedSearchScreen._performHybridSearch`:

1. Chuẩn hóa query (`trim`), rỗng thì reset state ngay.
2. Chạy song song bằng `Future.wait`:
   - `db.searchContacts(q)`
   - `db.searchMessages(q)`
   - remote `searchUserByPhone` (chỉ khi query giống số điện thoại)
3. Gộp kết quả local + remote để render.

**Ý nghĩa hiệu năng và UX:**
- Local query trả nhanh để UI phản hồi sớm.
- Remote phone lookup bổ sung kết quả “ngoài local cache” (đặc biệt tìm người lạ theo số).
- Cân bằng giữa tốc độ và độ bao phủ dữ liệu.

#### 1.3 Chống race-condition khi người dùng gõ nhanh

- Dùng `_searchRequestId` tăng dần theo mỗi lần search.
- Chỉ request có `requestId` mới nhất mới được phép cập nhật state.

**Lợi ích:**
- Tránh hiện tượng response cũ “đè” response mới (stale UI).
- Tăng độ ổn định cảm nhận khi mạng dao động.

#### 1.4 Giới hạn hiện tại

- Chưa có debounce/throttle input (`onChanged` gọi trực tiếp `_performHybridSearch`), nên có thể phát sinh burst request khi typing nhanh.
- Đây là điểm nên theo dõi trong backlog tối ưu search.

---

### 2) Load dữ liệu, đồng bộ và realtime

#### 2.1 Local-first load cho màn chat

Luồng `ChatProvider.openConversation`:

1. Join socket room conversation.
2. Đọc message local qua Drift (`_db.getMessagesByConversation`) để render ngay.
3. Gọi API `getMessages` để refresh dữ liệu mới nhất.
4. Sau khi refresh, đồng bộ read-state về server + local.

**Ý nghĩa hiệu năng:**
- Tối ưu **perceived performance**: người dùng thấy dữ liệu gần như tức thì.
- Giảm cảm giác “đợi trắng màn hình” khi mạng chậm.

#### 2.2 Pagination message

- `ChatService.getMessages` dùng query params `before` + `limit`.
- Đây là dạng cursor-style pagination phù hợp dòng thời gian chat.

**Lợi ích:**
- Không tải toàn bộ lịch sử trong một request.
- Giảm RAM/network, giảm jank khi render list dài.

#### 2.3 Enrich dữ liệu conversation theo batch song song

- `ChatService.getInbox` thu thập member IDs và gọi profile qua `Future.wait`.
- Sau khi merge detail conversation, chạy thêm một hydration pass.

**Lợi ích:**
- Hạn chế tuần tự hóa call profile.
- Tăng tốc độ hoàn thành “đủ dữ liệu hiển thị” của inbox.

**Trade-off:**
- Vẫn có nhiều request profile nếu inbox lớn (nhiều thành viên khác nhau).

#### 2.4 Realtime socket

- `SocketService` cấu hình:
  - transports: `websocket` + `polling` fallback
  - `enableReconnection`
  - delay 1s
  - tối đa 10 attempts
- Có stream riêng cho `message`, `typing`, `presence`, `read`, `delivered`, `recalled`, `call signal`.

**Ý nghĩa sẵn sàng:**
- Tự phục hồi tốt hơn khi mạng chuyển trạng thái (Wi-Fi ↔ 4G).
- Polling fallback giúp hoạt động trong môi trường mạng hạn chế websocket.

---

### 3) Độ sẵn sàng và chịu lỗi (availability/reliability)

#### 3.1 Timeout budgeting

Trong `ApiService`:

- JSON API timeout: **30s**
- Multipart upload timeout: **90s**

**Ý nghĩa:**
- Tách ngân sách timeout theo đặc thù request (upload file thường chậm hơn).
- Giảm false timeout cho media nhưng vẫn tránh treo vô hạn.

#### 3.2 Coalescing refresh token khi nhiều request cùng 401

- Dùng `_refreshInFlight` để các request concurrent cùng “chờ chung” 1 lần refresh.
- Tránh nhiều refresh song song gây xoay token liên tiếp.

**Lợi ích reliability:**
- Giảm rủi ro tự logout sai do race token.
- Ổn định phiên đăng nhập khi app phát nhiều request đồng thời.

#### 3.3 Fail-fast và phân loại lỗi mạng

- Tách các nhánh lỗi: `SocketException`, `TimeoutException`, `ClientException`, lỗi bất ngờ.
- Trả về `ApiException` với thông điệp phù hợp để UI map rõ nguyên nhân.

**Lợi ích vận hành:**
- Dễ phân biệt lỗi mất mạng vs lỗi backend vs lỗi client.
- Hỗ trợ xử lý UX chính xác hơn.

#### 3.4 ACK + retry/backoff khi gửi tin nhắn

Trong `ChatProvider`:

1. Tạo optimistic message (`SENDING`) để hiển thị ngay.
2. Gửi qua socket `emitWithAck`.
3. Nếu ACK lỗi/không ACK:
   - retry tối đa 3 lần
   - backoff tăng dần
4. Quá ngưỡng thì chuyển `FAILED`.

**Lợi ích:**
- Giữ được cảm giác “send ngay lập tức”.
- Có cơ chế tự phục hồi khi lỗi ngắn hạn.
- Trạng thái thất bại rõ ràng, cho phép retry thủ công.

---

### 4) Local DB, cache và tối ưu I/O

#### 4.1 Drift + SQLite migration strategy

- `LocalDatabase` dùng Drift với `schemaVersion = 3`.
- Có `onCreate`/`onUpgrade` rõ ràng:
  - tạo FTS tables
  - tạo trigger
  - deduplicate FTS rows
  - tạo bảng `conversation_read_state`.

**Ý nghĩa:**
- Quản lý tiến hóa schema có kiểm soát.
- Giảm rủi ro dữ liệu local “lệch phiên bản”.

#### 4.2 Background DB executor + lazy initialization

- `LazyDatabase` trì hoãn mở DB đến khi cần.
- `NativeDatabase.createInBackground(file)` đẩy tác vụ DB nặng ra background isolate.

**Ý nghĩa hiệu năng UI:**
- Giảm blocking main isolate.
- Giảm frame drop ở pha khởi tạo hoặc thao tác DB lớn.

#### 4.3 Batch upsert trong sync

- `saveMessagesBatch` và các `insertAll(..., InsertMode.insertOrReplace)`.
- `LocalSyncService.syncRecently` sync contacts + conversations + message slice gần nhất.

**Lợi ích:**
- Giảm số lần round-trip SQL.
- Hạn chế duplicate key crash khi dữ liệu đã tồn tại.

#### 4.4 Monotonic read-state

- Bảng `conversation_read_state` lưu `last_read_seq`.
- Upsert dùng `CASE WHEN excluded.last_read_seq > current THEN excluded ELSE current`.

**Lợi ích tính nhất quán:**
- Không cho phép “lùi” trạng thái đã đọc do out-of-order event.
- Quan trọng trong môi trường realtime có packet đến không đồng bộ.

#### 4.5 Media local cache on-demand

`MediaCacheService`:

1. Mở file ưu tiên local path nếu còn tồn tại.
2. Nếu thiếu/stale thì tải từ remote.
3. Lưu `local_path` vào DB để lần sau mở nhanh.
4. Có API `clearAll` để giải phóng dung lượng.

**Lợi ích:**
- Giảm băng thông cho file đã tải.
- Tăng tốc mở lại tài liệu/media.
- Có self-healing cho stale path khi file đã bị OS dọn.

---

### 5) Danh sách kỹ thuật “premium” đã triển khai trong mobile

1. SQLite FTS5 + trigger-based index maintenance.
2. Hybrid search pipeline (local FTS + remote fallback theo ngữ cảnh).
3. Request race protection bằng request/version id.
4. Local-first rendering + remote reconciliation cho chat detail.
5. Cursor-style pagination (`before`, `limit`) cho message timeline.
6. Socket.IO realtime với reconnect policy + transport fallback.
7. ACK-driven optimistic messaging + bounded retry/backoff.
8. Timeout budgeting tách riêng JSON và multipart.
9. Refresh-token coalescing cho concurrent unauthorized flows.
10. Drift migration strategy + lazy DB initialization + background DB executor.
11. Batch upsert sync để tối ưu write path.
12. Monotonic local read-state upsert chống out-of-order overwrite.
13. On-demand media local cache + stale-path self-healing.

> Ghi chú phạm vi: danh sách trên phản ánh kỹ thuật **đã có trong code hiện tại**. Các cải tiến chưa triển khai (ví dụ debounce input search, adaptive prefetch, telemetry profiling theo frame) được xem là backlog tối ưu tiếp theo.
