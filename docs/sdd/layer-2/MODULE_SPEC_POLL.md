# MODULE SPEC: POLL SYSTEM

> **Authority:** This document is the **Source of Truth** for Poll behavior in VNALO. All statements using MUST, SHALL, and REQUIRED conform to RFC 2119.

> **Module Owner:** message-service (NestJS/Node.js) + Flutter ChatProvider + Web ChatClient.
> **Status:** PRODUCTION-READY TARGET — 2026-04-29

---

## 1. OVERVIEW

The Poll System allows users to create polls within group conversations and vote on options. Polls are embedded in messages as structured JSON within the `content` field.

**Key Design Decisions:**
- Polls are message-attached: each poll is a message with `type = 'poll'`
- Voting is message-scoped: each user may vote once per poll
- Anonymous voting is configurable per poll
- Results update in real-time via WebSocket
- Poll data is embedded inline (not a separate entity) to maintain transactional simplicity

---

## 2. SCOPE

### In Scope
- Create poll via `message.send` with poll metadata
- Vote / change vote via `poll.vote` event
- Real-time result propagation via `poll.updated` event
- Close poll (creator only)
- Anonymous vs visible vote counts
- Single-choice and multi-choice polls

### Out of Scope
- Poll editing after creation
- Poll deletion (recall is separate from poll lifecycle)
- Poll templates / reusable polls
- Poll results analytics

---

## 3. DATA MODEL

### 3.1 Poll Metadata (Embedded in Message Content)

```json
{
  "type": "poll",
  "id": "uuid",
  "question": "string (max 500 chars)",
  "options": [
    { "id": "uuid", "text": "string (max 200 chars)", "votes": ["userId", ...] },
    { "id": "uuid", "text": "string (max 200 chars)", "votes": ["userId", ...] }
  ],
  "allowMultipleChoices": false,
  "isAnonymous": false,
  "isOpen": true,
  "totalVotes": 0,
  "maxOptions": 1,
  "createdBy": "userId",
  "createdAt": "ISO8601",
  "closedAt": null | "ISO8601",
  "createdByName": "string"
}
```

### 3.2 Message Entity Extension

```typescript
interface PollMessage {
  id: string;                    // message.id
  conversationId: string;
  senderId: string;
  messageType: 'poll';
  content: string;                // JSON.stringify(pollMetadata)
  pollData: PollMetadata;        // parsed content
  status: MessageStatus;          // NORMAL | RECALLED | DELETED
}
```

### 3.3 Constraints

```
- Maximum options per poll: 10
- Maximum characters per question: 500
- Maximum characters per option text: 200
- Poll votes are stored as array of userId per option (denormalized for fast read)
- totalVotes = sum of all option.votes.length
```

---

## 4. SECURITY RULES (RFC 2119)

### SR-1: Poll Creation Authorization

```
REQUIRED: Only active ADMIN, DEPUTY, or MEMBER with allowMemberCreatePoll=true
         may create a poll in a group conversation.

REQUIRED: Caller MUST be an active member (leftAt IS NULL) at creation time.

REQUIRED: poll.createdBy MUST be set to the authenticated userId from JWT.

REQUIRED: For direct (1:1) conversations, both members MAY create polls.
```

### SR-2: Poll Voting Authorization

```
REQUIRED: Only active members of the conversation may vote.

REQUIRED: A user MUST NOT vote more than once per option (idempotent).

REQUIRED: Users who have already voted MAY change their vote (remove from previous
         option, add to new option) until the poll is closed.

REQUIRED: Closed polls MUST NOT accept new votes; emit poll.error with code POLL_CLOSED.
```

### SR-3: Poll Closing Authorization

```
REQUIRED: Only poll.createdBy (the original creator) may close a poll.

REQUIRED: Once closed, isOpen = false, votes are frozen, closedAt is set.

REQUIRED: Closed polls MUST NOT be reopened.
```

### SR-4: Poll Visibility

```
REQUIRED: Poll results MUST always show totalVotes count to all members.
REQUIRED: If isAnonymous = true: individual voter identities MUST NOT be exposed.
         Option vote counts are visible but not which users voted for which option.
REQUIRED: If isAnonymous = false: voter userIds are visible per option to all members.
```

---

## 5. STATE MACHINE

```
                    [Poll Created]
                          │
                          ▼
                     ┌─────────┐
                     │  OPEN   │ ◄─────────────┐
                     └────┬────┘               │
             [Creator calls close]              │
                          │                   │
                          ▼                   │
                     ┌─────────┐              │
                     │ CLOSED │───────────────┘
                     └─────────┘  (No reopening)
```

**State Transitions:**

| Current State | Event | Next State | Pre-condition |
|---|---|---|---|
| OPEN | `poll.vote` | OPEN | Caller is active member, not already voted on that option |
| OPEN | `poll.vote` (remove) | OPEN | Caller is removing own vote from option |
| OPEN | `poll.close` | CLOSED | Caller is poll.createdBy |
| CLOSED | `poll.vote` | — | Reject: POLL_CLOSED |
| CLOSED | `poll.close` | — | Reject: Already closed |

---

## 6. WEBSOCKET EVENTS

### 6.1 Client → Server

| Event | Payload | Auth Required | Description |
|---|---|---|---|
| `poll.create` | `{ conversationId, pollData }` | YES | Create poll (via message.send) |
| `poll.vote` | `{ conversationId, messageId, optionId, remove? }` | YES | Cast or change vote |
| `poll.close` | `{ conversationId, messageId }` | YES | Close poll (creator only) |

### 6.2 Server → Client

| Event | Payload | Broadcast Target | Description |
|---|---|---|---|
| `poll.created` | Full message with pollData | `server.to(room)` | New poll broadcast |
| `poll.updated` | `{ messageId, pollData, updatedBy }` | `server.to(room)` | Vote or close update |
| `poll.error` | `{ code, message, messageId? }` | Emitter socket only | Error response |

### 6.3 Error Codes

| Code | Condition | Client Action |
|---|---|---|
| `POLL_CLOSED` | Voting on closed poll | Remove optimistic vote, show toast |
| `POLL_ALREADY_VOTED` | Voting same option twice | No-op, already voted |
| `POLL_NOT_MEMBER` | Caller not in conversation | Navigate away |
| `POLL_NOT_CREATOR` | Non-creator calls close | Show toast |
| `POLL_OPTION_INVALID` | optionId not found | Remove optimistic vote |
| `POLL_MAX_OPTIONS_EXCEEDED` | Multi-choice exceeds maxOptions | Remove optimistic vote |

---

## 7. TRANSACTIONAL RULES

### 7.1 Vote Transaction

```
REQUIRED TRANSACTION (within message send transaction):
BEGIN
  1. Parse pollData from message content
  2. Verify poll.isOpen === true
  3. Verify caller is active member of conversationId
  4. IF remove === true:
       - Remove userId from option.votes array
  5. ELSE:
       - Verify userId not already in option.votes (idempotent guard)
       - Verify total selected options < maxOptions (multi-choice guard)
       - Add userId to option.votes array
  6. Recalculate totalVotes
  7. UPDATE message.content = JSON.stringify(updatedPollData)
  8. Emit 'poll.updated' to conversation room
COMMIT
```

### 7.2 Poll Creation Transaction

```
REQUIRED TRANSACTION:
BEGIN
  1. Verify caller is active member of conversationId
  2. Verify conversation type supports polls (1:1 or GROUP)
  3. Validate poll metadata (max options, max chars)
  4. INSERT message (type='poll', content=JSON.stringify(pollData))
  5. Assign serverSeq via Redis INCR
  6. Emit 'message.received' with full poll data to room
COMMIT
```

---

## 8. REAL-TIME DELIVERY

```
Poll creation:
  → server.to('conversation:{id}').emit('poll.created', message)
  → server.to('conversation:{id}').emit('message.received', message)

Poll vote:
  → server.to('conversation:{id}').emit('poll.updated', {
       messageId: string,
       pollData: PollMetadata,
       updatedBy: userId
     })

Poll close:
  → server.to('conversation:{id}').emit('poll.updated', {
       messageId: string,
       pollData: PollMetadata,
       closedBy: userId,
       closedAt: ISO8601
     })
```

**Note:** No per-user loops. Room emission only.

---

## 9. UI BEHAVIOR

### 9.1 Poll Message Bubble

- Shows question text prominently
- Each option rendered as a selectable row
- Progress bar showing percentage of votes per option (visible to all)
- Vote count: always visible (`X votes`)
- Voter names: visible only if `isAnonymous === false`
- Your vote indicator: visible if your userId is in the option votes array
- Close button: visible only to `createdBy`

### 9.2 Voting Flow

```
1. User taps option → optimistic UI update (immediate visual feedback)
2. Emit 'poll.vote' via Socket.IO
3. On 'poll.updated': reconcile optimistic state with server state
4. On 'poll.error': revert optimistic update, show toast
```

### 9.3 Real-Time Updates

```
On receiving 'poll.updated':
  1. Find poll message in local state by messageId
  2. Replace pollData with server pollData
  3. Re-render poll bubble with new vote counts
  4. If poll is now closed: replace voting UI with results-only view
```

---

## 10. REST ENDPOINTS

| Method | Path | Description |
|---|---|---|
| GET | `/conversations/{id}/messages?type=poll` | Get all poll messages in conversation |
| GET | `/messages/{id}` | Get single poll message with full pollData |
| POST | `/messages` | Create poll (message.send with type='poll') |

---

## 11. EVIDENCE

| Component | File |
|---|---|
| Poll message bubble | `frontend/web/src/features/chat/components/PollBubble.tsx` |
| Poll API integration | `frontend/web/src/features/chat/chat.api.ts` |
| Poll message state | `frontend/web/src/features/chat/chat.types.ts` |
| Backend poll entity | `backend/node-services/apps/message-service/src/entities/message.entity.ts` |
| Chat gateway | `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts` |

---

## 12. REMEDIATION CHECKLIST

| Item | Priority | Status |
|---|---|---|
| Enforce SG-1 membership check on `poll.vote` event | CRITICAL | `[SPEC_ONLY]` |
| Enforce SG-1 membership check on `poll.close` event | CRITICAL | `[SPEC_ONLY]` |
| Transaction wrapping for vote updates | CRITICAL | `[SPEC_ONLY]` |
| Emit `poll.error` with structured code | HIGH | `[SPEC_ONLY]` |
| Room-based emission for `poll.updated` | HIGH | `[SPEC_ONLY]` |
| PollBubble component for Web | HIGH | `[SPEC_ONLY]` |
| Anonymous vote hiding (isAnonymous) | MEDIUM | `[SPEC_ONLY]` |
| Multi-choice support (maxOptions > 1) | MEDIUM | `[SPEC_ONLY]` |
