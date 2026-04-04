# Realtime Gateway — Hướng Dẫn Sử Dụng

## Tổng Quan

`realtime-gateway` là service Node.js/NestJS cung cấp kết nối **WebSocket** real-time cho ứng dụng VNALO.

- **Port**: 8085
- **WebSocket Namespace**: `/realtime`
- **Protocol**: Socket.IO (Chỉ hỗ trợ `websocket`, đã tối ưu cho latency thấp)
- **Scaling**: Tích hợp `RedisIoAdapter` cho phép chạy N-instances Gateway song song kết nối vạn người.

---

## Kết Nối WebSocket

### Yêu cầu: JWT token hợp lệ

```js
import { io } from 'socket.io-client';

const socket = io('http://localhost:8085/realtime', {
  auth: { token: '<JWT_ACCESS_TOKEN>' },
  transports: ['websocket']
});
```

---

## Events Client → Server

### Vào / Rời Room (Giới hạn tối đa 50 Rooms/User)

```js
// Vào room (để nhận message realtime)
socket.emit('conversation.join', { conversationId: 'uuid-của-conversation' });

// Rời room
socket.emit('conversation.leave', { conversationId: 'uuid' });
```

### Lấy Presence

```js
socket.emit('presence.get', { userIds: ['user1-uuid', 'user2-uuid'] });
// Server trả về event 'presence.list' với mảng { userId, status, lastSeen }
```

### Typing Indicator

```js
// Bắt đầu gõ
socket.emit('typing.start', { conversationId: 'uuid' });

// Dừng gõ
socket.emit('typing.stop', { conversationId: 'uuid' });
```

### Heartbeat (Giữ Presence)

```js
// Gọi mỗi 30-45 giây để tránh bị tự động offline
setInterval(() => socket.emit('heartbeat'), 30000);
```

---

## Events Server → Client

| Event | Khi nào | Payload |
|---|---|---|
| `presence.changed` | User connect/disconnect | `{ userId, status, lastSeen }` |
| `typing.changed` | User bắt đầu/dừng gõ | `{ userId, conversationId, isTyping }` |
| `message.received` | Tin nhắn mới gửi | Full message object |
| `message.recalled` | Tin nhắn bị thu hồi | `{ messageId, conversationId, recalledBy }` |
| `presence.list` | Response của `presence.get` | Array presence |

---

## Kiến Trúc Luồng Tin

```
Client A (mobile/web)
    │ POST /api/v1/messages
    ▼
message-service (8082)
    │ Save to DB
    │ Publish → RabbitMQ exchange `vnalo.realtime`
    ▼
RabbitMQ (5672)
    │ Queue: realtime.broadcast
    ▼
realtime-gateway (8085)
    │ Broadcast tới room conversation:{id}
    ▼
Client B (WebSocket connected)
    event: message.received
```

---

## Chạy Với Docker

```bash
cd docker

# Chạy toàn bộ hệ thống
docker compose up --build -d

# Chạy chỉ realtime-gateway + dependencies
docker compose up -d redis rabbitmq realtime-gateway

# Xem logs
docker compose logs -f realtime-gateway

# RabbitMQ Management UI
open http://localhost:15672   # guest / guest
```

## Chạy Development

```bash
cd backend/node-services

# Install dependencies
npm install

# Chạy chỉ realtime-gateway
npm run start:realtime:dev

# Chạy cả 2 service song song
npm run start:dev &        # message-service port 3000
npm run start:realtime:dev # realtime-gateway port 8085
```

---

## Biến Môi Trường

| Key | Mô Tả | Mặc Định |
|---|---|---|
| `PORT` | Port HTTP/WS | 8085 |
| `REDIS_HOST` | Redis host | localhost |
| `REDIS_PORT` | Redis port | 6379 |
| `JWT_SECRET` | Base64 encoded secret | (bắt buộc) |
| `JWT_ISSUER` | JWT issuer claim | vnalo |
| `RABBITMQ_URL` | AMQP connection URL | amqp://guest:guest@localhost:5672 |
