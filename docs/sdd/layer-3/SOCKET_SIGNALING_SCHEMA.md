# SOCKET SIGNALING SCHEMA

> [!IMPORTANT]
> This schema covers both active WS channels in repository runtime.
> Last updated: 2026-04-22. Events marked `[SPEC_ONLY]` exist in spec but not yet in gateway code.
> For multi-device delivery rules and broadcast strategy details, see MODULE_SPEC_REALTIME_SYNC.md (Layer 2).

---

## Namespaces

| Namespace | Service | Port | Purpose |
|---|---|---|---|
| `/chat` | message-service | default | Chat messages, call signaling, read/typing/pin events, group membership events |
| `/realtime` | realtime-gateway | separate | Presence federation and typing across services |

---

## /chat Namespace

### Connection Handshake

```
wss://host/chat
Auth: { token: "<JWT>" }   // or ?token=<JWT> query param
Transport: websocket only (no polling)
CORS: CORS_ALLOWED_ORIGINS env list
```

JWT claims read at connection:

| Claim | Field | Default |
|---|---|---|
| `sub` | userId | required |
| `phone` | phone | required |
| `iat` | loginAtEpochSec | token issue time |
| `clientPlatform` | clientPlatform | `'WEB'` |
| `restrictedWebMode` | **overridden to `false`** (D-008) | — |
| `deviceId` | deviceId | `null` |

---

### Client → Server Events

#### `conversation.join`

Join a conversation room to receive real-time messages. Must be called per conversation, per socket (not persisted across reconnects).

```json
// Payload
{ "conversationId": "uuid" }

// Success response
{ "event": "conversation.joined", "data": { "conversationId": "uuid" } }

// Failure response
{ "event": "conversation.error", "data": { "error": "string" } }
```

**Guard**: Caller must be an active member (`leftAt IS NULL`). Non-members receive `conversation.error`.

---

#### `conversation.leave`

Leave a Socket.IO room (does not affect DB membership).

```json
{ "conversationId": "uuid" }
// No ack response
```

---

#### `message.send`

Send a text, media, reply, or forward message. Persists to DB then broadcasts.

```json
{
  "conversationId": "uuid",           // required
  "content": "string",                // required for TEXT type
  "messageType": "TEXT|IMAGE|VIDEO|FILE|AUDIO|STICKER|REPLY|FORWARD",
  "clientMessageId": "uuid",          // idempotency key
  "mediaUrl": "string",              // required for media types
  "mediaThumbnailUrl": "string",
  "mediaMimeType": "string",
  "mediaSizeBytes": 1234,
  "replyToMessageId": "uuid",        // for REPLY
  "forwardFromMessageId": "uuid",    // for FORWARD
  "forwardFromConversationId": "uuid"
}

// Success ack
{ "event": "message.sent", "data": <Message> }

// Failure ack
{ "event": "message.error", "data": { "error": "string" } }
```

**Guards**:
- Sender must be active member.
- TEXT requires non-empty `content`.
- Media types require `mediaUrl`.
- `restrictedWebMode` sessions are blocked (service-level guard).
- `onlyAdminCanPost=true` blocks MEMBER role `[SPEC_ONLY]`.

---

#### `message.recall`

Recall (soft-delete) a message within 24 hours.

```json
{
  "messageId": "uuid",
  "conversationId": "uuid"
}

// Success ack
{ "event": "message.recalled", "data": <RecalledMessage> }

// Failure ack
{ "event": "message.error", "data": { "error": "string" } }
```

**Guards**: Sender can recall own; ADMIN/DEPUTY can recall any. 24-hour hard window.

---

#### `message.typing`

Typing indicator. Fire-and-forget; no ack.

```json
{
  "conversationId": "uuid",
  "isTyping": true
}
// No response
```

**Broadcast**: `client.to(room)` — excludes sender's emitting socket.

---

#### `message.read`

Mark messages as read up to a sequence number.

```json
{
  "conversationId": "uuid",
  "lastReadSeq": 123
}
// No ack
```

**Side effects**: Updates `lastReadSeq` and `unreadCount` in `conversation_member` and `conversation_inbox`.
**Broadcast**: `client.to(room)` — other members receive `message.read` event.

---

#### `message.pin`

Pin a message in a conversation.

```json
{
  "messageId": "uuid",
  "conversationId": "uuid"
}

// Success ack
{ "event": "message.pinned", "data": <PinnedMessage> }

// Failure ack
{ "event": "message.error", "data": { "error": "string" } }
```

**Guards**: DIRECT chats: any member. GROUP: `allowMemberPin` flag or ADMIN/DEPUTY role. Cannot pin `RECALLED` messages.

---

#### `message.unpin`

Unpin a message.

```json
{
  "messageId": "uuid",
  "conversationId": "uuid"
}

// Success ack
{ "event": "message.unpinned", "data": { "messageId": "uuid" } }

// Failure ack
{ "event": "message.error", "data": { "error": "string" } }
```

**Guards**: Same as pin.

---

#### `call.offer`

Initiate a call. Forwarded to target user's all active sockets.

```json
{
  "conversationId": "uuid",
  "callId": "uuid",
  "targetUserId": "uuid",
  "senderUserId": "uuid",
  "sdp": { "type": "offer", "sdp": "v=0..." },
  "audioOnly": true
}

// Success ack
{ "event": "call.offer.sent", "data": { "conversationId", "callId", "targetUserId" } }

// Failure ack
{ "event": "call.error", "data": { "error": "string" } }
```

**Offline**: If target has no sockets, publishes to Redis channel `CALL_OFFLINE`. FCM consumer not yet wired.

---

#### `call.answer`

Answer an incoming call.

```json
{
  "conversationId": "uuid",
  "callId": "uuid",
  "targetUserId": "uuid",
  "senderUserId": "uuid",
  "sdp": { "type": "answer", "sdp": "v=0..." }
}

// Success ack
{ "event": "call.answer.sent", "data": { "conversationId", "callId", "targetUserId" } }
```

---

#### `call.ice-candidate`

Exchange ICE candidates for WebRTC negotiation.

```json
{
  "conversationId": "uuid",
  "callId": "uuid",
  "targetUserId": "uuid",
  "candidate": { "candidate": "...", "sdpMid": "...", "sdpMLineIndex": 0 }
}

// Success ack
{ "event": "call.ice-candidate.sent", "data": { "conversationId", "callId", "targetUserId" } }
```

---

#### `call.end`

End or reject a call.

```json
{
  "conversationId": "uuid",
  "callId": "uuid",
  "targetUserId": "uuid",
  "reason": "HUNG_UP|REJECTED|TIMEOUT|NETWORK_ERROR"
}

// Success ack
{ "event": "call.end.sent", "data": { "conversationId", "callId", "targetUserId" } }
```

---

### Server → Client Events

#### `message.received`

Delivered when a new message is sent to a conversation. **May be received twice** (room broadcast + per-user direct). Clients must deduplicate by `message.id`.

```json
{
  "id": "uuid",
  "conversationId": "uuid",
  "serverSeq": 42,
  "senderId": "uuid",
  "clientMessageId": "uuid",
  "messageType": "TEXT|IMAGE|VIDEO|FILE|AUDIO|STICKER|SYSTEM|REPLY|FORWARD",
  "content": "string",
  "mediaUrl": "string",
  "mediaThumbnailUrl": "string",
  "mediaMimeType": "string",
  "mediaSizeBytes": 1234,
  "replyToMessageId": "uuid",
  "replyToSenderId": "uuid",
  "replyToContent": "string",
  "forwardFromMessageId": "uuid",
  "forwardFromConversationId": "uuid",
  "status": "SENT|DELIVERED|RECALLED",
  "isEdited": false,
  "editedAt": null,
  "hiddenByUsers": [],
  "createdAt": "ISO8601"
}
```

**Delivery**: Room broadcast (`server.to(room)`) + per-user direct (`emitToUser`) for all active members.

---

#### `message.sent`

Sender-only confirmation that message was persisted.

```json
// Same shape as message.received
```

**Delivery**: Sender's emitting socket only (`client.emit`).

---

#### `message.recalled`

Broadcast when a message is recalled.

```json
{
  "messageId": "uuid",
  "conversationId": "uuid",
  "recalledBy": "uuid"
}
```

**Delivery**: `server.to(room)` — all members including sender.

---

#### `message.typing`

Typing state of another user.

```json
{
  "userId": "uuid",
  "conversationId": "uuid",
  "isTyping": true
}
```

**Delivery**: `client.to(room)` — all room members except the emitting socket.

---

#### `message.read`

Another member has read up to a sequence number.

```json
{
  "userId": "uuid",
  "conversationId": "uuid",
  "lastReadSeq": 123
}
```

**Delivery**: `client.to(room)` — all room members except reader's emitting socket.
> Own other devices are NOT notified (known gap — see MODULE_SPEC_REALTIME_SYNC §4).

---

#### `message.pinned`

A message was pinned.

```json
{
  "pin": {
    "id": "uuid",
    "conversationId": "uuid",
    "messageId": "uuid",
    "serverSeq": 42,
    "pinnedBy": "uuid",
    "pinnedAt": "ISO8601",
    "message": { /* Message object */ }
  },
  "pinnedBy": "uuid"
}
```

**Delivery**: `server.to(room)` — all members.

---

#### `message.unpinned`

A message was unpinned.

```json
{
  "messageId": "uuid",
  "conversationId": "uuid",
  "unpinnedBy": "uuid"
}
```

**Delivery**: `server.to(room)` — all members.

---

#### `presence.changed`

A user came online or went offline.

```json
{
  "userId": "uuid",
  "status": "online" | "offline"
}
```

**Delivery**: `server.emit` — global broadcast to ALL connected sockets.
> ⚠️ Performance concern for large deployments. Scoping to contact graph is planned.

**Offline rule**: `status: 'offline'` is only emitted when the user's **last** socket disconnects.

---

#### `call.offer` / `call.answer` / `call.ice-candidate` / `call.end`

Forwarded call signaling events.

```json
{
  "type": "offer|answer|ice-candidate|end",
  "conversationId": "uuid",
  "callId": "uuid",
  "senderUserId": "uuid",
  "targetUserId": "uuid",
  "sdp": { ... },          // offer, answer only
  "candidate": { ... },    // ice-candidate only
  "audioOnly": true,       // offer only
  "reason": "string"       // end only
}
```

**Delivery**: `emitToUser(targetUserId)` — all sockets of target user.

---

#### `call.error`

Error during call signaling.

```json
{ "error": "string" }
```

**Delivery**: Emitting socket only.

---

#### `group.disbanded` `[NEW — D-014]`

Group has been disbanded. All data deleted. Client must purge local cache.

```json
{
  "conversationId": "uuid",
  "disbandedAt": "ISO8601"
}
```

**Delivery**: `server.to(room)` — all sockets currently in the room.
**Client action required**: Delete local SQLite conversation and messages immediately. Navigate away from chat screen.

---

#### `group.member_added` `[SPEC_ONLY]`

```json
{
  "conversationId": "uuid",
  "addedUserId": "uuid",
  "addedBy": "uuid",
  "role": "MEMBER|DEPUTY",
  "joinedAt": "ISO8601"
}
```

---

#### `group.member_removed` `[SPEC_ONLY]`

```json
{
  "conversationId": "uuid",
  "removedUserId": "uuid",
  "removedBy": "uuid",
  "removedAt": "ISO8601"
}
```

---

#### `group.member_left` `[SPEC_ONLY]`

```json
{
  "conversationId": "uuid",
  "userId": "uuid",
  "silent": false,
  "leftAt": "ISO8601"
}
```

`silent: true` → only ADMIN/DEPUTY clients should display system message.

---

#### `group.admin_transferred` `[SPEC_ONLY]`

```json
{
  "conversationId": "uuid",
  "fromUserId": "uuid",
  "toUserId": "uuid",
  "transferredAt": "ISO8601"
}
```

---

#### `group.updated` `[SPEC_ONLY]`

```json
{
  "conversationId": "uuid",
  "updatedBy": "uuid",
  "changes": {
    "title": "string",
    "avatarUrl": "string",
    "description": "string",
    "onlyAdminCanPost": true
  },
  "updatedAt": "ISO8601"
}
```

---

### Gateway Runtime Notes

- `restrictedWebMode` is hardcoded to `false` at connection (D-008). Service-level guards apply restriction.
- Room membership is per-socket. Re-join required on reconnect.
- `message.received` may arrive twice per message (room + per-user). Deduplicate by `message.id`.
- `/chat` transport: websocket only (polling disabled). Connection must use `auth.token`.

---

## /realtime Namespace

### Client → Server Events

| Event | Required Fields | Return Event |
|---|---|---|
| `conversation.join` | `conversationId` | `conversation.joined` or error |
| `conversation.leave` | `conversationId` | `conversation.left` |
| `presence.get` | `userIds: string[]` | `presence.list` |
| `heartbeat` | none | `heartbeat.ack` |
| `typing.start` | `conversationId` | `typing.changed` broadcast |
| `typing.stop` | `conversationId` | `typing.changed` broadcast |

### Server → Client Events

| Event | Payload Contract |
|---|---|
| `presence.changed` | `{ userId, status: 'online'|'offline', lastSeen: ISO8601 }` |
| `presence.list` | `Array<{ userId, status, lastSeen }>` |
| `typing.changed` | `{ userId, conversationId, isTyping }` |
| `heartbeat.ack` | empty |
| `conversation.joined` | `{ conversationId }` |
| `conversation.left` | `{ conversationId }` |

---

## Flutter SocketService Listener Contract

| Listener Stream | Consuming Events | Status |
|---|---|---|
| `onMessage` | `message.received`, `message.sent` | ✅ Implemented |
| `onTyping` | `message.typing` | ✅ Implemented |
| `onPresence` | `presence.changed` | ✅ Implemented |
| `onRead` | `message.read` | ✅ Implemented |
| `onDelivered` | `message.delivered` | ⚠️ Listened but NOT emitted by gateway |
| `onRecalled` | `message.recalled` | ✅ Implemented |
| `onPinned` | `message.pinned` | ✅ Implemented |
| `onUnpinned` | `message.unpinned` | ✅ Implemented |
| `onCallSignal` | `call.offer`, `call.answer`, `call.ice-candidate`, `call.end`, `call.signal` | ✅ Implemented |
| `onCallError` | `call.error` | ✅ Implemented |
| `onReactionAdded` | `message.reaction.added` | ⚠️ Listened but NOT emitted by gateway |
| `onReactionRemoved` | `message.reaction.removed` | ⚠️ Listened but NOT emitted by gateway |
| `onGroupDisbanded` | `group.disbanded` | ❌ `[SPEC_ONLY]` — not yet subscribed |
| `onGroupMemberAdded` | `group.member_added` | ❌ `[SPEC_ONLY]` |
| `onGroupMemberRemoved` | `group.member_removed` | ❌ `[SPEC_ONLY]` |
| `onGroupMemberLeft` | `group.member_left` | ❌ `[SPEC_ONLY]` |
| `onGroupAdminTransferred` | `group.admin_transferred` | ❌ `[SPEC_ONLY]` |
| `onGroupUpdated` | `group.updated` | ❌ `[SPEC_ONLY]` |

---

## Offline Fallback Architecture

```
call.offer → emitToUser(target)
  target has 0 sockets →
    Redis PUBLISH 'CALL_OFFLINE' {
      channel, targetUserId, event, payload, createdAt
    }
    [No consumer → FCM not sent — KNOWN GAP]
```

All other events: **no offline buffer**. Client pulls REST on reconnect.

---

## Wire Examples

### message.send

```json
{
  "conversationId": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Xin chào!",
  "messageType": "TEXT",
  "clientMessageId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### call.offer

```json
{
  "conversationId": "550e8400-e29b-41d4-a716-446655440000",
  "callId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "targetUserId": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "senderUserId": "6ba7b811-9dad-11d1-80b4-00c04fd430c8",
  "audioOnly": false,
  "sdp": {
    "type": "offer",
    "sdp": "v=0\r\no=- 4611731 2 IN IP4 127.0.0.1\r\n..."
  }
}
```

### group.disbanded

```json
{
  "conversationId": "550e8400-e29b-41d4-a716-446655440000",
  "disbandedAt": "2026-04-22T09:45:00.000Z"
}
```

---

## Evidence

- backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
- backend/node-services/apps/realtime-gateway/src/gateway/realtime.gateway.ts
- frontend/mobile/lib/services/socket_service.dart
- frontend/mobile/lib/features/call/services/webrtc_call_service.dart
- docs/sdd/layer-0/DECISION_LOG.md D-003, D-004, D-007, D-008, D-014
- docs/sdd/layer-2/MODULE_SPEC_REALTIME_SYNC.md
