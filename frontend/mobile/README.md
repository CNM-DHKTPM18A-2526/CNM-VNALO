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

Phần này tổng hợp theo code hiện tại trong `frontend/mobile/lib` để liệt kê các kỹ thuật “premium” đã áp dụng thực tế.

### Search (Hybrid Search: local + remote)

Kỹ thuật đang dùng:

- **Full-text search local bằng SQLite FTS5** cho `messages` và `contacts`, có trigger đồng bộ index theo insert/delete (`lib/core/database/local_database.dart`).
- **Hybrid query song song** bằng `Future.wait`:
  - local contacts (`db.searchContacts`)
  - local messages (`db.searchMessages`)
  - remote phone lookup khi query giống số điện thoại
  (`lib/features/search/screens/unified_search_screen.dart`).
- **Chống race-condition kết quả search** bằng `requestId` tăng dần (`_searchRequestId`) để bỏ qua response cũ khi người dùng gõ nhanh.

Đánh giá:

- Mạnh ở độ trễ thấp nhờ ưu tiên local FTS.
- Ổn định UI tốt khi có nhiều request chồng nhau.
- **Hiện chưa có debounce/throttle input** (`onChanged` gọi trực tiếp `_performHybridSearch`) nên có thể tạo nhiều request khi gõ rất nhanh; mục này nên theo dõi trong backlog tối ưu hiệu năng.

### Load dữ liệu và đồng bộ realtime

Kỹ thuật đang dùng:

- **Local-first loading**: mở conversation sẽ đọc tin nhắn từ local DB trước, sau đó fetch API để refresh (`ChatProvider.openConversation`).
- **Pagination theo `before + limit`** ở API lấy message (`ChatService.getMessages`) để tải từng lát dữ liệu.
- **Batch enrich dữ liệu hội thoại**: gom member IDs và gọi profile song song qua `Future.wait` để giảm tuần tự hóa request (`ChatService`).
- **Realtime socket với auto reconnect** (`SocketService`):
  - websocket + polling fallback
  - auto reconnect với delay 1s, tối đa 10 lần.

Đánh giá:

- Tối ưu perceived performance (mở màn hình chat nhanh vì có cache local).
- Realtime có khả năng tự phục hồi kết nối tốt cho mobile network không ổn định.

### Độ sẵn sàng và chịu lỗi (availability/reliability)

Kỹ thuật đang dùng:

- **HTTP timeout cứng**:
  - 30s cho JSON API
  - 90s cho multipart upload
  (`ApiService`).
- **Coalescing refresh token**: dùng `_refreshInFlight` để gộp nhiều luồng 401 concurrent, tránh đua refresh token.
- **Fail-fast network error mapping**: phân biệt timeout, mất mạng, client exception để UI xử lý rõ ràng hơn.
- **Socket ACK + retry backoff cho gửi tin nhắn**:
  - optimistic message
  - retry tối đa 3 lần, backoff tăng dần
  - chuyển trạng thái FAILED khi quá ngưỡng
  (`ChatProvider._sendWithRetry`, `_scheduleRetry`).

Đánh giá:

- Có đầy đủ lớp phòng thủ ở cả REST lẫn socket.
- Phù hợp bài toán chat cần tính liên tục cao trên mạng di động thực tế.

### Local DB, cache và tối ưu I/O

Kỹ thuật đang dùng:

- **Drift + SQLite** cho offline cache có schema migration (`schemaVersion = 3`).
- **Native DB chạy background isolate** (`NativeDatabase.createInBackground`) giúp giảm blocking UI thread.
- **LazyDatabase** để trì hoãn mở DB đến khi thực sự cần.
- **Batch upsert** (`InsertMode.insertOrReplace`) cho sync contacts/messages.
- **Read-state local (conversation_read_state)** với cập nhật đơn điệu (`ON CONFLICT ... CASE WHEN excluded > current`) để không ghi đè lùi trạng thái đã đọc.
- **Media file cache on-demand**:
  - tải file khi cần, lưu path local vào DB
  - kiểm tra stale path và tự clear khi file vật lý đã mất
  (`MediaCacheService`).

Đánh giá:

- Đây là nhóm kỹ thuật “premium” rõ rệt cho mobile chat:
  - vừa tối ưu tốc độ hiển thị
  - vừa giảm network round-trip
  - vẫn giữ được tính nhất quán dữ liệu quan trọng (read-state, media path).

### Tổng hợp kỹ thuật “premium” đã dùng trong mobile

1. **SQLite FTS5 + trigger-based index maintenance** cho tìm kiếm nội bộ tốc độ cao.
2. **Hybrid search pipeline** (local FTS + remote fallback) chạy song song.
3. **Request race protection** bằng version/request ID.
4. **Local-first rendering + remote reconciliation** cho màn hình chat.
5. **Cursor-style pagination (`before`, `limit`)** cho message loading.
6. **Realtime Socket.IO với auto-reconnect và fallback transport**.
7. **ACK-driven optimistic messaging + bounded retry/backoff**.
8. **HTTP timeout budgets khác nhau theo loại tải (JSON vs multipart)**.
9. **Refresh-token coalescing** chống token-rotation race.
10. **Drift migration + background DB executor + lazy initialization**.
11. **Bulk sync/write bằng batch upsert**.
12. **On-demand media local cache + stale-path self-healing**.
13. **Monotonic local read-state upsert** để bảo toàn trạng thái đã đọc.

> Ghi chú phạm vi: danh sách trên phản ánh **kỹ thuật đã có trong code hiện tại**; chưa bao gồm các kỹ thuật chưa được triển khai (ví dụ: debounce search input, adaptive prefetch theo network class, telemetry/perf tracing theo frame).
