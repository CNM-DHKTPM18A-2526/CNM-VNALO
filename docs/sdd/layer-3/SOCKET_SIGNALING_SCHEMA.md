# SOCKET SIGNALING SCHEMA

> [!IMPORTANT]
> This schema covers both active and auxiliary WS channels in repository runtime.

## Namespaces

| Namespace | Service | Purpose |
| --- | --- | --- |
| /chat | message-service | Chat, call signaling, read and pin events |
| /realtime | realtime-gateway | Presence and typing federation |

## /chat Event Contract

### Client -> Server

| Event | Required Fields | Optional Fields | Ack or Return Event |
| --- | --- | --- | --- |
| call.offer | conversationId, callId, targetUserId | senderUserId, sdp, audioOnly | call.offer.sent or call.error |
| call.answer | conversationId, callId, targetUserId | senderUserId, sdp | call.answer.sent or call.error |
| call.ice-candidate | conversationId, callId, targetUserId | senderUserId, candidate | call.ice-candidate.sent or call.error |
| call.end | conversationId, callId, targetUserId | senderUserId, reason | call.end.sent or call.error |
| conversation.join | conversationId | none | conversation.joined or conversation.error |
| conversation.leave | conversationId | none | none |
| message.send | conversationId, content | messageType, clientMessageId, media*, reply* | message.sent or message.error |
| message.recall | messageId, conversationId | none | message.recalled or message.error |
| message.typing | conversationId, isTyping | none | none |
| message.read | conversationId, lastReadSeq | none | none |
| message.pin | messageId, conversationId | none | message.pinned or message.error |
| message.unpin | messageId, conversationId | none | message.unpinned or message.error |

### Server -> Client

| Event | Payload Contract | Source |
| --- | --- | --- |
| presence.changed | userId, status online or offline | connection lifecycle |
| call.offer | type, conversationId, callId, senderUserId, targetUserId, sdp, audioOnly | forwardCallSignal |
| call.answer | type, conversationId, callId, senderUserId, targetUserId, sdp | forwardCallSignal |
| call.ice-candidate | type, conversationId, callId, senderUserId, targetUserId, candidate | forwardCallSignal |
| call.end | type, conversationId, callId, senderUserId, targetUserId, reason | forwardCallSignal |
| call.error | error message payload | return event path from call handlers |
| message.received | message object | room broadcast and per-user emit |
| message.sent | message object | sender confirmation |
| message.recalled | messageId, conversationId, recalledBy | recall broadcast |
| message.typing | userId, conversationId, isTyping | typing broadcast excluding sender |
| message.read | userId, conversationId, lastReadSeq | read receipt broadcast excluding sender |
| message.pinned | pin object and pinnedBy | pin broadcast |
| message.unpinned | messageId, conversationId, unpinnedBy | unpin broadcast |

### Offline Call Fallback

When target user has no active sockets and event is call.offer:

- gateway publishes Redis channel CALL_OFFLINE with payload:
  - channel
  - targetUserId
  - event
  - payload
  - createdAt

> [!NOTE]
> Repository currently does not include a CALL_OFFLINE consumer that routes to push delivery.

## /realtime Event Contract

### Client -> Server

| Event | Required Fields | Return Event |
| --- | --- | --- |
| conversation.join | conversationId | conversation.joined or error |
| conversation.leave | conversationId | conversation.left |
| presence.get | userIds array | presence.list |
| heartbeat | none | heartbeat.ack |
| typing.start | conversationId | typing.changed broadcast |
| typing.stop | conversationId | typing.changed broadcast |

### Server -> Client

| Event | Payload Contract |
| --- | --- |
| presence.changed | userId, status, lastSeen |
| presence.list | list of user presence objects |
| typing.changed | userId, conversationId, isTyping |
| heartbeat.ack | empty ack |
| conversation.joined | conversationId |
| conversation.left | conversationId |

## Flutter SocketService Listener Contract

| Listener Stream | Consumed Event Names |
| --- | --- |
| onMessage | message.received, message.sent |
| onTyping | message.typing |
| onPresence | presence.changed |
| onRead | message.read |
| onDelivered | message.delivered |
| onRecalled | message.recalled |
| onPinned | message.pinned |
| onUnpinned | message.unpinned |
| onCallSignal | call.offer, call.answer, call.ice-candidate, call.end, call.signal |
| onCallError | call.error |
| onReactionAdded | message.reaction.added |
| onReactionRemoved | message.reaction.removed |

> [!WARNING]
> message.delivered, message.reaction.added, and message.reaction.removed are listened in mobile SocketService but are not emitted by current chat.gateway implementation.

## Wire Examples

### call.offer

```json
{
  "conversationId": "uuid",
  "callId": "uuid-or-derived-id",
  "targetUserId": "uuid",
  "senderUserId": "uuid",
  "audioOnly": true,
  "sdp": {
    "type": "offer",
    "sdp": "v=0..."
  }
}
```

### message.send

```json
{
  "conversationId": "uuid",
  "content": "hello",
  "messageType": "TEXT",
  "clientMessageId": "uuid"
}
```

## Evidence

- backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
- backend/node-services/apps/realtime-gateway/src/gateway/realtime.gateway.ts
- frontend/mobile/lib/services/socket_service.dart
- frontend/mobile/lib/features/call/services/webrtc_call_service.dart
