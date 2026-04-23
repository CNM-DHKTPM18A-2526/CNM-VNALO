# API Reference

> All REST endpoints and WebSocket events for VNALO services.

## Performance Reviews

- Strict review: `docs/system/performance/ENDPOINT_PERFORMANCE_STRICT_REVIEW_2026-04-05.md`
- Auth/message P95-P99 metrics: `docs/system/performance/AUTH_MESSAGE_P95_P99_METRICS_2026-04-05.md`

---

## core-service (Port 8081)

Base path: `/api/v1`

### Auth — `/auth`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/auth/register/send-otp` | Send OTP for registration | No |
| POST | `/auth/register` | Register with OTP + password | No |
| POST | `/auth/register/verify-otp` | Verify registration OTP before final submit | No |
| POST | `/auth/login` | Login (phone + password → JWT) | No |
| POST | `/auth/refresh` | Refresh access token | No |
| POST | `/auth/logout` | Revoke refresh token | Yes |
| POST | `/auth/logout-all` | Revoke all refresh tokens | Yes |
| GET | `/auth/login-devices` | Get login device history | Yes |
| GET | `/auth/session-audit` | Get session transition audit log | Yes |
| GET | `/auth/otp/status` | Check OTP config status | No |
| POST | `/auth/change-password` | Change password for authenticated user | Yes |
| POST | `/auth/forgot-password` | Send password reset OTP | No |
| POST | `/auth/reset-password` | Reset password via OTP | No |
| GET | `/auth/check-phone/{phone}` | Check whether phone is registered | No |

### Auth QR — `/auth/qr`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/auth/qr/sessions` | Create QR login session | No |
| GET | `/auth/qr/sessions/{token}` | Poll QR login session | No |
| GET | `/auth/qr/sessions/{token}/preview` | Get mobile approval preview | No |
| POST | `/auth/qr/sessions/{token}/approve` | Approve QR login from mobile | Yes |

### Users — `/users`

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/users/me` | Get current user profile | Yes |
| GET | `/users/{userId}` | Get user by ID | Yes |
| PATCH | `/users/me` | Update profile | Yes |
| GET | `/users/search?keyword=` | Search users (paginated) | Yes |
| GET | `/users/phone/{phoneNumber}` | Exact phone lookup (path form) | Yes |
| GET | `/users/search-by-phone?phone=` | Exact phone lookup (query form) | Yes |
| GET | `/users/me/privacy` | Get privacy settings | Yes |
| PUT | `/users/me/privacy` | Update privacy settings | Yes |
| GET | `/users/me/settings/sync` | Get sync control policy | Yes |
| PUT | `/users/me/settings/sync` | Update sync control policy | Yes |

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

## message-service (Port 3000)

Note: In some environments, `PORT` can be overridden (for example mapping to 8082).

Base path: `/api/v1`

### Conversations

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/conversations/direct` | Create or get 1:1 conversation | Yes |
| POST | `/conversations/group` | Create group conversation | Yes |
| GET | `/conversations/{id}` | Get conversation details | Yes |
| PATCH | `/conversations/{id}` | Update group settings | Yes |
| POST | `/conversations/{id}/members` | Add members to group | Yes |
| DELETE | `/conversations/{id}/members/{uid}` | Remove group member (Admin/Deputy) | Yes |
| POST | `/conversations/{id}/leave` | Self-leave group (Admin must transfer first) | Yes |
| POST | `/conversations/{id}/auto-transfer` | Auto-transfer admin role or disband group | Yes |
| DELETE | `/conversations/{id}` | Disband (permanently delete) group (Admin only) | Yes |
| GET | `/conversations/{id}/members` | Get group members (member-only) | Yes |
| POST | `/conversations/{id}/join` | Join by QR/invite id (OPEN) or create approval request (APPROVAL) | Yes |
| GET | `/conversations/{id}/join-requests` | List pending join requests (admin/deputy only) | Yes |
| POST | `/conversations/{id}/join-requests/{uid}/approve` | Approve pending user into group | Yes |
| DELETE | `/conversations/{id}/join-requests/{uid}` | Reject pending join request | Yes |

### Messages

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/messages` | Send message (REST) | Yes |
| GET | `/conversations/{id}/messages` | Get message history (cursor-based) | Yes |
| GET | `/conversations/{id}/messages/search` | Search messages (keyword + type) | Yes |
| PATCH | `/messages/{id}` | Edit message | Yes |
| DELETE | `/messages/{id}` | Recall message | Yes |
| DELETE | `/messages/{id}/for-me` | Hide message only for current user (requires membership) | Yes |

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

Connection: `ws://localhost:3000/chat` with JWT in handshake `auth.token`.

Namespace: `/chat` — Transports: `websocket`, `polling`

### Client → Server Events

| Event | Payload | Response Event | Description |
|-------|---------|---------------|-------------|
| `conversation.join` | `{ conversationId }` | `conversation.joined` / `message.error` | Join a conversation room (membership required) |
| `conversation.leave` | `{ conversationId }` | — | Leave a conversation room |
| `message.send` | `{ conversationId, content, messageType, clientMessageId }` | `message.sent` / `message.error` | Send message (persisted + broadcast) |
| `message.typing` | `{ conversationId, isTyping }` | — | Typing indicator (ignored if sender is not a member) |
| `message.read` | `{ conversationId, lastReadSeq }` | — | Mark messages as read |
| `group.updateSettings` | `{ conversationId, title, avatarUrl, ... }` | `group.settingsChanged` / `conversation.error` | Update group settings |

### Server → Client Events

| Event | Payload | Description |
|-------|---------|-------------|
| `message.received` | Full message object | New message in a joined room |
| `message.typing` | `{ userId, conversationId, isTyping }` | Someone is typing |
| `message.read` | `{ userId, conversationId, lastReadSeq }` | Read receipt from another user |
| `presence.changed` | `{ userId, status: 'online'/'offline' }` | User presence change |
| `group.memberAdded` | `{ conversationId, addedBy, newMembers, conversation }` | Emitted when members join/are added |
| `group.memberRemoved` | `{ conversationId, removedBy, removedUserId }` | Emitted when a member is kicked |
| `group.memberLeft` | `{ conversationId, userId }` | Emitted when a member leaves |
| `group.roleChanged` | `{ conversationId, updatedBy, targetUserId, newRole }` | Emitted when a member's role changes |
| `group.adminTransferred` | `{ conversationId, oldAdminId, newAdminId }` | Emitted when group ownership changes |
| `group.settingsChanged` | `{ conversationId, updatedBy, changes, conversation }` | Emitted when group settings change |
| `group.disbanded` | `{ conversationId, disbandedBy }` | Emitted when the group is permanently deleted |

### Connection Flow

1. Client connects to `/chat` namespace with `auth: { token: '<JWT>' }`
2. Server verifies JWT, tracks socket per userId (multi-device support)
3. Server broadcasts `presence.changed` with `status: 'online'`
4. Client emits `conversation.join` for each active conversation (server verifies membership)
5. Client sends/receives messages via room-scoped events
6. On disconnect, server broadcasts `presence.changed` with `status: 'offline'`

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
