# VNALO Mobile — Setup & Run Guide

> **Updated:** 2026-05-23 | **Audience:** All team members (backend, mobile, QA)

Hướng dẫn thực hành để setup, chạy, debug và troubleshoot Flutter mobile app của VNALO.

---

## 1. App kết nối tới các backend nào?

| Service | Port | Chức năng |
|---------|:----:|-----------|
| `core-service` | 8081 | Auth, user, social APIs |
| `message-service` | 3000 | Chat/inbox APIs + Socket.IO |
| `media-service` | 8083 | Avatar/media upload APIs |
| `ai-service` | 8094 | AI assistant chatbot |

Tất cả URL được đọc từ `--dart-define` khi chạy `flutter run`.

**Các define được hỗ trợ:**

| Define | Mô tả | Mặc định (dev) |
|--------|-------|---------------|
| `ENV` | Môi trường (`dev\|staging\|production`) | `dev` |
| `CORE_SERVICE_URL` | URL core-service | `http://10.0.2.2:8081/api/v1` |
| `MESSAGE_SERVICE_URL` | URL message-service | `http://10.0.2.2:3000/api/v1` |
| `MEDIA_SERVICE_URL` | URL media-service | `http://10.0.2.2:8083/api/v1` |
| `SOCKET_URL` | Socket.IO URL (không có `/api/v1`) | `http://10.0.2.2:3000` |
| `AI_SERVICE_URL` | URL ai-service | `http://10.0.2.2:8094/api/v1` |

---

## 2. Quick Start (đã có toolchain)

```bash
cd frontend/mobile
flutter pub get
flutter devices

# Android emulator — 10.0.2.2 trỏ tới host machine
flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=AI_SERVICE_URL=http://10.0.2.2:8094/api/v1
```

Thiết bị thật → không dùng `10.0.2.2`, xem mục 7.

---

## 3. Prerequisites theo OS

### 3.1 Windows

| Thành phần | Ghi chú |
|-----------|---------|
| Flutter SDK (stable) | Thêm vào PATH |
| Android Studio + Android SDK | Cần emulator image |
| JDK 17+ | Cho Android toolchain |
| Git | — |

Kiểm tra:
```powershell
flutter doctor -v
```

### 3.2 macOS

**Android only:**
- Flutter SDK + Android Studio + SDK

**iOS thêm:**
- Xcode + Xcode Command Line Tools
- CocoaPods

```bash
flutter doctor -v
xcode-select -p
pod --version
```

### 3.3 Linux

- Flutter SDK + Android Studio + SDK

```bash
flutter doctor -v
```

> iOS build/run không hỗ trợ trên Linux.

---

## 4. Khởi động backend

Mobile app cần backend reachable từ device/emulator.

```powershell
# Infra + core services
docker compose -f docker/docker-compose.yml up -d postgres redis rabbitmq core-service message-service media-service ai-service

# Kiểm tra
docker compose -f docker/docker-compose.yml ps
```

Cổng cần mở:

| Cổng | Service |
|:----:|---------|
| 8081 | core-service |
| 3000 | message-service |
| 8083 | media-service |
| 8094 | ai-service |

---

## 5. Project Bootstrap

```bash
cd frontend/mobile

flutter clean
flutter pub get
flutter pub deps --style=compact

# Kiểm tra tùy chọn
flutter analyze    # phải xanh trước khi PR
flutter test
```

---

## 6. Chạy App

### 6.1 Android Emulator (khuyến nghị first run)

```bash
flutter emulators
flutter emulators --launch <emulator_id>
flutter devices

flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://10.0.2.2:8083/api/v1 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=AI_SERVICE_URL=http://10.0.2.2:8094/api/v1
```

> `10.0.2.2` = alias đặc biệt của Android emulator trỏ tới localhost của máy dev.

### 6.2 Android Physical Device (USB)

1. Bật Developer Options + USB Debugging trên điện thoại
2. Cắm USB
3. Xác nhận: `adb devices` + `flutter devices`
4. Dùng LAN IP của máy tính (ví dụ `192.168.1.50`):

```bash
flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://192.168.1.50:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://192.168.1.50:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://192.168.1.50:8083/api/v1 \
  --dart-define=SOCKET_URL=http://192.168.1.50:3000 \
  --dart-define=AI_SERVICE_URL=http://192.168.1.50:8094/api/v1
```

### 6.3 iOS Simulator (macOS)

```bash
open -a Simulator
flutter devices

flutter run \
  --dart-define=ENV=dev \
  --dart-define=CORE_SERVICE_URL=http://127.0.0.1:8081/api/v1 \
  --dart-define=MESSAGE_SERVICE_URL=http://127.0.0.1:3000/api/v1 \
  --dart-define=MEDIA_SERVICE_URL=http://127.0.0.1:8083/api/v1 \
  --dart-define=SOCKET_URL=http://127.0.0.1:3000 \
  --dart-define=AI_SERVICE_URL=http://127.0.0.1:8094/api/v1
```

### 6.4 iOS Physical Device (macOS)

Dùng LAN IP của Mac (tương tự Android physical device).
Mở `ios/Runner.xcworkspace` trong Xcode → cấu hình Team + Signing → `flutter run`.

---

## 7. Network Mapping Matrix

| Target | Host để trỏ tới backend trên máy dev |
|--------|--------------------------------------|
| Android emulator | `10.0.2.2` |
| iOS simulator | `127.0.0.1` hoặc `localhost` |
| Android/iOS physical | LAN IP máy dev (ví dụ `192.168.x.x`) |

**Nếu app trên thiết bị thật không kết nối được:**
- Máy dev và điện thoại phải cùng Wi-Fi
- Firewall phải cho phép inbound ports 8081, 3000, 8083, 8094
- Docker services phải bind `0.0.0.0` (mặc định đã OK)

---

## 8. Wireless Debugging (Android)

### 8.1 Android 11+ (Wireless Debugging)

Trên điện thoại: Developer Options → Wireless Debugging → Pair device with pairing code

```bash
adb pair <phone_ip>:<pair_port>
# Nhập pairing code hiển thị trên điện thoại

adb connect <phone_ip>:<debug_port>
adb devices
```

### 8.2 Legacy adb tcpip

```bash
# Kết nối USB 1 lần
adb devices
adb tcpip 5555
adb connect <phone_ip>:5555
adb devices
# Rút USB, tiếp tục debug qua network
```

> Tắt wireless debugging sau khi xong để đảm bảo bảo mật.

---

## 9. Tính năng & Module

App được tổ chức theo feature-first architecture trong `lib/features/`:

| Module | Tính năng |
|--------|-----------|
| `auth` | Đăng nhập phone+email+OTP, màn hình splash |
| `chat` | Nhắn tin, reactions, pin tin nhắn, sticker, voice message, gọi |
| `call` | Voice call 1-1, Video call 1-1, Group call (WebRTC) |
| `ai_assistant` | AI floating bubble, chat với Gemini, clarification chips |
| `contacts` | Đồng bộ danh bạ điện thoại, quản lý bạn bè |
| `notifications` | FCM handler, thông báo đẩy background |
| `profile` | Avatar upload, cài đặt tài khoản, quyền riêng tư |
| `timeline` | Bài đăng, stories (đang phát triển) |
| `discover` | Màn hình khám phá |
| `search` | Tìm kiếm toàn cục |

**State management**: Provider (ChangeNotifier) + Riverpod (flutter_riverpod 3.3.1)

**Local database**: Drift (SQLite) — offline-first cho conversations, contacts

---

## 10. Lệnh Hữu Ích Trong Dev

```bash
# Từ frontend/mobile:
flutter devices
flutter run -d <device_id>
flutter logs
flutter attach
flutter test
flutter analyze

# Android ADB helpers
adb devices
adb kill-server && adb start-server
adb reverse tcp:8081 tcp:8081    # optional với USB debug
adb reverse tcp:3000 tcp:3000
adb reverse tcp:8083 tcp:8083
adb reverse tcp:8094 tcp:8094
```

---

## 11. Troubleshooting

### 11.1 App không gọi được backend (timeout/refused)

Checklist:
1. Xác nhận service health qua Docker (`docker compose ps`)
2. Xác nhận đúng host mapping từ mục 7
3. Xác nhận firewall cho phép các cổng
4. Điện thoại và máy dev cùng Wi-Fi (thiết bị thật)

### 11.2 Đăng nhập OK nhưng inbox/media/AI lỗi

Nguyên nhân có thể:
- URL mismatch trong `--dart-define` (kiểm tra `AI_SERVICE_URL`)
- Token refresh issue từ build cũ

Giải pháp:
```bash
flutter clean && flutter pub get
flutter run --dart-define=... (đầy đủ tất cả defines)
```

### 11.3 Device not found

```bash
adb devices
flutter devices
# Nếu rỗng: reconnect USB hoặc re-run wireless adb connect
# Restart adb: adb kill-server && adb start-server
```

### 11.4 Gradle / Android build cache issues

```bash
flutter clean
cd android && ./gradlew clean && cd ..    # Windows: gradlew.bat clean
flutter pub get
flutter run ...
```

### 11.5 iOS signing errors (macOS)

- Mở `ios/Runner.xcworkspace` trong Xcode
- Cấu hình Team + Signing certificate
- Chạy lại `flutter run`

### 11.6 AI Assistant không phản hồi

- Kiểm tra `AI_SERVICE_URL` có đúng port 8094 không
- Kiểm tra `GEMINI_API_KEY` đã set trong `docker/.env`
- Kiểm tra ai-service health: `curl http://localhost:8094/actuator/health`

---

## 12. Checklist Onboarding Thành Viên Mới

Member được xem là onboarded đầy đủ khi pass tất cả:

- [ ] `flutter doctor -v` không có blocking issue
- [ ] Device/emulator visible trong `flutter devices`
- [ ] App launch được với dev URLs (tất cả 5 `--dart-define`)
- [ ] Đăng ký / đăng nhập thành công
- [ ] Inbox load được
- [ ] Avatar upload thành công
- [ ] AI assistant phản hồi câu hỏi
- [ ] `flutter analyze` xanh

---

## 13. Convention Nhóm

- Luôn chạy với đầy đủ `--dart-define` trong dev (tất cả 5 biến)
- Không hardcode machine-specific IP vào source code
- Giữ `ENV=dev` khi test local
- Trước PR:
  - `flutter analyze` — phải xanh
  - `flutter test` — phải pass
  - Test luồng login → chat → media trên emulator/device thật

---

## 14. File liên quan

| File | Mục đích |
|------|---------|
| `lib/main.dart` | Entry point, đọc dart-defines, DI providers |
| `lib/config/app_config.dart` | URL resolution theo môi trường |
| `lib/config/env.dart` | Environment enum model |
| `lib/services/auth_service.dart` | Auth API calls |
| `lib/services/api_service.dart` | HTTP client chung (token injection) |
| `lib/services/socket_service.dart` | Socket.IO client |
| `lib/services/ai_service.dart` | AI chatbot API calls |
| `lib/core/database/local_database.dart` | Drift SQLite local DB |

---

## 15. Escalation

Nếu bị block > 30 phút:

1. Post logs + exact `flutter run` command vào team channel
2. Bao gồm:
   - Device type và OS
   - Exact `flutter run` command (tất cả `--dart-define`)
   - Endpoint URLs đang dùng
   - First failing stack trace

Điều này giúp giảm đáng kể thời gian debug cho nhóm.
