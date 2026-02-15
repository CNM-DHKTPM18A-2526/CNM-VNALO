# API Reference

> All REST endpoints and WebSocket events for VNALO services.

---

## core-service (Port 8081)

Base path: `/api/v1`

### Auth — `/auth`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/auth/register/send-otp` | Send OTP for registration | No |
| POST | `/auth/register` | Register with OTP + password | No |
| POST | `/auth/login` | Login (phone + password → JWT) | No |
| POST | `/auth/refresh` | Refresh access token | No |
| POST | `/auth/logout` | Revoke refresh token | Yes |
| POST | `/auth/logout-all` | Revoke all refresh tokens | Yes |
| GET | `/auth/otp/status` | Check OTP config status | No |

### Users — `/users`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/users/me` | Get current user profile | Yes |
| GET | `/users/{userId}` | Get user by ID | Yes |
| PATCH | `/users/me` | Update profile | Yes |
| GET | `/users/search?keyword=` | Search users (paginated) | Yes |
| GET | `/users/me/privacy` | Get privacy settings | Yes |
| PUT | `/users/me/privacy` | Update privacy settings | Yes |

### Friends — `/friends`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/friends/requests` | Send friend request | Yes |
| GET | `/friends/requests/incoming` | Get incoming requests | Yes |
| GET | `/friends/requests/sent` | Get sent requests | Yes |
| POST | `/friends/requests/{id}/accept` | Accept request | Yes |
| POST | `/friends/requests/{id}/decline` | Decline request | Yes |
| DELETE | `/friends/requests/{id}` | Cancel sent request | Yes |
| GET | `/friends` | Get friends list | Yes |
| DELETE | `/friends/{friendId}` | Unfriend | Yes |
| GET | `/friends/{userId}/status` | Check friendship status | Yes |
| GET | `/friends/stats` | Get friend count + pending count | Yes |

### Blocks — `/blocks`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/blocks/{userId}` | Block user | Yes |
| DELETE | `/blocks/{userId}` | Unblock user | Yes |
| GET | `/blocks` | Get blocked users | Yes |
| GET | `/blocks/{userId}/status` | Check block status (bidirectional) | Yes |

### QR Code — `/qr`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/qr/generate` | Generate QR payload (token + nonce) | Yes |
| POST | `/qr/scan` | Validate scanned QR, return user info | Yes |
| POST | `/qr/scan/add-friend` | Scan + send friend request | Yes |

### Contacts — `/contacts`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/contacts/sync` | Batch sync phone contacts | Yes |
| GET | `/contacts/matched` | Get contacts registered on VNALO | Yes |
| GET | `/contacts` | Get all synced contacts | Yes |
| DELETE | `/contacts` | Clear all synced contacts | Yes |

---

## message-service (Port 8082)

Base path: `/api/v1`

### Conversations

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/conversations/direct` | Create or get 1:1 conversation | Yes |
| POST | `/conversations/group` | Create group conversation | Yes |
| GET | `/conversations/{id}` | Get conversation details | Yes |
| PATCH | `/conversations/{id}` | Update group settings | Yes |
| POST | `/conversations/{id}/members` | Add members to group | Yes |
| DELETE | `/conversations/{id}/members/{uid}` | Remove/leave group | Yes |

### Messages

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/messages` | Send message (REST) | Yes |
| GET | `/conversations/{id}/messages` | Get message history (cursor-based) | Yes |
| GET | `/conversations/{id}/messages/search` | Search messages (keyword + type) | Yes |
| PATCH | `/messages/{id}` | Edit message | Yes |
| DELETE | `/messages/{id}` | Recall message | Yes |

### Reactions

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/messages/{id}/reactions` | Add emoji reaction | Yes |
| DELETE | `/messages/{id}/reactions` | Remove reaction | Yes |
| GET | `/messages/{id}/reactions` | Get reactions | Yes |

### Pins

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/conversations/{id}/pin/{mid}` | Pin message | Yes |
| DELETE | `/conversations/{id}/pin/{mid}` | Unpin message | Yes |
| GET | `/conversations/{id}/pins` | Get pinned messages | Yes |

### Read Receipts

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/conversations/{id}/read` | Mark as read (seq-based) | Yes |

### Inbox

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/inbox` | Get inbox (sorted by last message) | Yes |

---

## WebSocket Events (Socket.IO)

Connection: `ws://localhost:8082` with JWT in handshake auth.

| Event | Direction | Payload |
|-------|-----------|---------|
| `send_message` | Client → Server | `{ conversationId, content, messageType, clientMessageId }` |
| `new_message` | Server → Client | Full message object |
| `typing_start` | Client → Server | `{ conversationId }` |
| `typing_stop` | Client → Server | `{ conversationId }` |
| `user_typing` | Server → Client | `{ conversationId, userId, isTyping }` |
| `join_conversation` | Client → Server | `{ conversationId }` |
| `presence` | Server → Client | `{ userId, status }` |

---

## Common Response Format

```json
{
  "success": true,
  "code": null,
  "message": "Success",
  "data": { }
}
```

## Authentication

All authenticated endpoints require:
```
Authorization: Bearer <access_token>
```

Access tokens: 15 min validity, HS512 signed.
Refresh tokens: 30 day validity, stored hashed in DB.

## Pagination

```
GET /endpoint?page=0&size=20&sort=createdAt,desc
```
