# VNALO Web — Setup & Development Guide

> **Stack:** React 19 · TypeScript 5.9 · Vite 8 · TailwindCSS 3.4 · Socket.IO  
> **Updated:** 2026-05-23 | **Audience:** Frontend developers, QA, DevOps

---

## 1. Tổng Quan

Web frontend của VNALO là ứng dụng React SPA kết nối tới các backend services và được phục vụ qua Nginx trong môi trường production.

**Tính năng:**

| Module | Tính năng |
|--------|-----------|
| **Auth** | Đăng nhập (phone/email), Đăng ký, Quên mật khẩu, **QR Login** (quét từ mobile) |
| **Chat** | Real-time messaging (Socket.IO), gửi file/sticker, phản ứng tin nhắn, pin |
| **Calls** | WebRTC voice call 1-1, video call 1-1, group call |
| **Contacts** | Danh sách liên hệ, quản lý bạn bè |
| **Profile** | Chỉnh sửa hồ sơ, avatar upload |
| **Notifications** | Thông báo real-time |
| **AI Chat** | Trò chuyện với AI assistant (Gemini) |

**Routing:**

| Path | Component | Auth required |
|------|-----------|:---:|
| `/login` | LoginPage | ❌ |
| `/login/qr` | QrLoginPage | ❌ |
| `/register` | RegisterPage | ❌ |
| `/forgot-password` | ForgotPasswordPage | ❌ |
| `/chat/:conversationId?` | ChatPage | ✅ |
| `/contacts` | ContactsPage | ✅ |
| `/profile` | ProfilePage | ✅ |
| `/chat-ai` | AiChatPage | ✅ |
| `/call/:callId` | CallPage | ✅ |

---

## 2. Yêu Cầu

```bash
Node.js 20+
npm 10+
# Backend services đang chạy (xem mục 4)
```

---

## 3. Cài Đặt & Chạy Development

```bash
cd frontend/web

# Cài đặt dependencies
npm install

# Tạo file môi trường
cp .env.example .env
# Chỉnh sửa .env theo hướng dẫn mục 5

# Chạy dev server
npm run dev
# → http://localhost:5173
```

### Scripts khả dụng

```bash
npm run dev       # Dev server với HMR (http://localhost:5173)
npm run build     # Production build (output: dist/)
npm run preview   # Preview production build cục bộ
npm run lint      # ESLint check
```

---

## 4. Yêu Cầu Backend

Web app cần các backend services đang chạy và reachable:

```bash
# Khởi động từ thư mục gốc project
cd docker

# Cách 1 — Đầy đủ với Docker
docker compose up -d postgres redis rabbitmq core-service message-service media-service realtime-gateway ai-service

# Cách 2 — Chỉ infra, chạy services local
docker compose -f docker-compose.infra.yml up -d
# Sau đó chạy từng service trong terminal riêng (xem README gốc)
```

**Cổng cần mở:**

| Service | Port | Chức năng |
|---------|:----:|-----------|
| core-service | 8081 | Auth, Users, Social APIs |
| message-service | 3000 | Chat APIs + Socket.IO |
| media-service | 8083 | File/media upload |
| realtime-gateway | 8085 | WebSocket presence (`/realtime`) |
| ai-service | 8094 | AI chatbot |

---

## 5. Biến Môi Trường

Tạo file `frontend/web/.env` từ `.env.example`:

```bash
# Core service URL
VITE_CORE_URL=http://localhost:8081/api/v1

# Message service URL (REST)
VITE_MESSAGE_URL=http://localhost:3000/api/v1

# Media service URL
VITE_MEDIA_URL=http://localhost:8083/api/v1

# Socket.IO URL (không có /api/v1)
VITE_SOCKET_URL=http://localhost:3000

# AI service URL
VITE_AI_URL=http://localhost:8094/api/v1

# Realtime Gateway (WebSocket presence)
VITE_REALTIME_URL=http://localhost:8085
```

> **Production**: Tất cả URLs được proxy qua Nginx (`vnalo.fit`), không cần cấu hình riêng.

---

## 6. Cấu Trúc Source Code

```
frontend/web/src/
├── App.tsx                    # Root component + routing
├── main.tsx                   # Entry point + providers
├── api.client.ts              # Axios HTTP client (token injection)
│
├── features/
│   ├── auth/                  # Authentication
│   │   ├── ProtectedRoute.tsx # Route guard
│   │   ├── useAuth.ts         # Auth hook
│   │   └── ...
│   ├── chat/                  # Real-time chat
│   │   ├── chat.api.ts        # Chat REST APIs (38KB)
│   │   ├── chat.socket.ts     # Socket.IO events
│   │   ├── useChatSocket.ts   # WebSocket hook
│   │   ├── webrtcCallService.ts       # WebRTC 1-1 call
│   │   ├── webrtcGroupCallService.ts  # WebRTC group call
│   │   └── components/        # UI components
│   ├── contacts/              # Contacts management
│   ├── friends/               # Friend management
│   ├── notifications/         # NotificationContext
│   ├── profile/               # User profile
│   └── settings/              # App settings
│
├── layouts/
│   └── MainLayout.tsx         # Authenticated app shell
│
├── pages/
│   ├── LoginPage.tsx
│   ├── QrLoginPage.tsx        # QR login (scan from mobile)
│   ├── RegisterPage.tsx
│   ├── ForgotPasswordPage.tsx
│   ├── ChatPage.tsx
│   ├── CallPage.tsx           # WebRTC call page
│   ├── ContactsPage.tsx
│   ├── ProfilePage.tsx
│   └── AiChatPage.tsx         # AI chatbot page
│
├── shared/                    # Shared utilities & components
├── styles/                    # Global CSS (app.css, TailwindCSS)
└── utils/                     # Helper utilities
```

---

## 7. Tính Năng Chi Tiết

### QR Login

1. Mở `/login/qr` trên web → hiển thị QR code
2. Mở VNALO mobile → quét QR
3. Mobile gửi approval → web nhận JWT token → tự động đăng nhập

Backend: `AuthQrController` trong core-service + bảng `auth_qr_login_session` (V15 migration)

### WebRTC Calls

```
1-1 call:   webrtcCallService.ts   → CallPage (/call/:callId)
Group call: webrtcGroupCallService.ts (32KB) → GroupCall UI
```

Signaling qua Socket.IO (message-service). ICE/STUN configuration cần update cho production deployment.

### AI Chat

- Route: `/chat-ai` → `AiChatPage`
- Kết nối tới `ai-service` (port 8094)
- Backend: Gemini 2.5 Flash (primary) + Ollama fallback
- Rate limit: 5 req/min/user

### Real-time Messaging

```
Socket.IO (message-service:3000/chat namespace)
  → Conversations, messages, reactions, typing indicators
  → Thông qua useChatSocket.ts hook

Socket.IO (realtime-gateway:8085/realtime namespace)
  → Presence (online/offline), user status
```

---

## 8. Build & Deploy

### Development

```bash
npm run dev     # HMR dev server → localhost:5173
```

### Production Build

```bash
npm run build
# Output: dist/
# Serve bởi Nginx trong Docker
```

### Docker (Production)

```bash
# Từ thư mục gốc project
cd docker
docker compose up -d frontend-web
# → http://localhost:80 (hoặc https://vnalo.fit với SSL)
```

**Dockerfile** (`frontend/web/Dockerfile`): Multi-stage build (Node builder → Nginx alpine)

**Nginx** (`nginx.conf` ở root): TLS termination, path-based API routing, SPA fallback (`try_files $uri $uri/ /index.html`)

---

## 9. Linting & Code Quality

```bash
# ESLint
npm run lint

# TypeScript type check (built into build)
npm run build
```

**Config files:**
- `eslint.config.js` — ESLint 9 flat config
- `tsconfig.app.json` + `tsconfig.node.json` — TypeScript strict mode
- `tailwind.config.js` — TailwindCSS theme
- `postcss.config.js` — PostCSS + Autoprefixer

---

## 10. Troubleshooting

### CORS errors

Đảm bảo `APP_CORS_ALLOWED_ORIGINS` trong `docker/.env` chứa `http://localhost:5173`.

### WebSocket không kết nối được

```bash
# Kiểm tra message-service
curl http://localhost:3000/api/v1/health

# Kiểm tra realtime-gateway
curl http://localhost:8085/health
```

### API 401 Unauthorized

- Token đã hết hạn → thử logout và login lại
- `JWT_SECRET` không khớp giữa frontend config và backend

### QR Login không hoạt động

- Kiểm tra core-service: `curl http://localhost:8081/api/v1/actuator/health`
- Mobile và web phải kết nối tới cùng backend environment

### AI Chat không phản hồi

- Kiểm tra `GEMINI_API_KEY` trong `docker/.env`
- `curl http://localhost:8094/actuator/health`
- Nếu quota hết → ai-service tự fallback sang Ollama (nếu đang chạy)

---

## 11. Convention Phát Triển

- Sử dụng TypeScript strict — không dùng `any` nếu có thể
- Component: functional component + React hooks
- State: React Context cho global state (UserStoreContext, NotificationContext)
- API calls: qua `api.client.ts` (Axios instance với token injection tự động)
- WebSocket: qua `chat.socket.ts` và `useChatSocket.ts` hook
- CSS: TailwindCSS utility classes, custom styles trong `styles/`
- Trước PR: `npm run lint` phải xanh

---

## 12. File Liên Quan Quan Trọng

| File | Mục đích |
|------|---------|
| `src/api.client.ts` | Axios instance, token injection, refresh logic |
| `src/features/chat/chat.socket.ts` | Socket.IO client wrapper |
| `src/features/chat/useChatSocket.ts` | Chat WebSocket hook (15KB) |
| `src/features/chat/webrtcCallService.ts` | WebRTC 1-1 call service |
| `src/features/chat/webrtcGroupCallService.ts` | WebRTC group call (32KB) |
| `src/features/auth/ProtectedRoute.tsx` | Route authentication guard |
| `src/features/notifications/NotificationContext.tsx` | Global notification state |
| `vite.config.ts` | Vite config (proxy, aliases) |
| `tailwind.config.js` | TailwindCSS theme config |
