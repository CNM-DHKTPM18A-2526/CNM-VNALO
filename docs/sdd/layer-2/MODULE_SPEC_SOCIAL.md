# MODULE SPEC SOCIAL

> [!IMPORTANT]
> Module owner: core-service social domain and Flutter contacts layer.
> Last audited: 2026-04-22. All business rules below are owner-confirmed unless marked `[SPEC_ONLY]`.

---

## Outcomes

- Maintain stable friend, block, contact sync, and QR-assisted social onboarding flows.
- Enforce relationship constraints and privacy policy surfaces.
- Provide low-friction mobile contacts and friend request UX.
- Guarantee block semantics across all communication surfaces (1:1 and group chat).

---

## Scope

### In Scope

- core-service endpoints under /friends, /blocks, /contacts, /qr, and user lookup paths.
- Entities: friendship, friend_request, block_list, contact_sync, user_profile, user_privacy_setting.
- Flutter FriendService and ContactProvider usage.

### Out of Scope

- Moderation action policy.
- Timeline social feed ranking.
- External recommendation algorithms.

---

## Constraints

- JWT auth required for all social endpoints.
- Relationship updates must preserve anti-self and duplicate-request checks.
- Block state must be considered before friend creation and before message delivery.
- Contact sync and phone search must align with privacy settings.

---

## 1. Friend Request State Machine

```
NONE → PENDING (sendFriendRequest)
PENDING → ACCEPTED (acceptFriendRequest)  → creates Friendship row
PENDING → DECLINED (declineFriendRequest)
PENDING → CANCELLED (cancelFriendRequest) — sender only
```

### 1.1 Send Friend Request Rules

| Rule | Behaviour |
|---|---|
| Self-request | `400 SOCIAL_CANNOT_ADD_SELF` |
| Target not found | `404 USER_NOT_FOUND` |
| Already friends | `409 SOCIAL_ALREADY_FRIENDS` |
| Pending exists (either direction) | `409 SOCIAL_REQUEST_ALREADY_SENT` |
| Block exists (either direction) | `403 SOCIAL_USER_BLOCKED` |
| Privacy restriction (`source` not allowed) | `403 SOCIAL_PRIVACY_RESTRICTION` |
| No request cooldown | After decline, sender can re-send immediately |

### 1.2 Privacy Sources

| Source | Gated by privacy setting |
|---|---|
| `CONTACT_IMPORT` | `allowFriendRequestByPhone` |
| `QR` | `allowFriendRequestByQrCode` |
| `GROUP` | `allowFriendRequestBySharedGroup` |
| `SUGGESTION` | `allowFriendRequestBySuggestion` |
| `SEARCH` | Always allowed |

### 1.3 Accept / Decline / Cancel

- Only the **recipient** (`userIdTo`) can accept or decline.
- Only the **sender** (`userIdFrom`) can cancel.
- Both actions require `status = PENDING`; non-pending requests return `404`.

### 1.4 Unfriend

- Deletes the `Friendship` row (hard delete bidirectional via `deleteFriendship`).
- Does not affect existing conversation history.
- Either party can unfriend.

---

## 2. Block Rules

### 2.1 Block Behaviour

```
blockUser(blockerId, blockedId, blockMessages?, blockCalls?, blockAndHideLogs?)
```

| Flag | Default | Effect |
|---|---|---|
| `blockMessages` | `true` | Blocks message sending/receiving between the two users |
| `blockCalls` | `true` | Blocks call initiation between the two users |
| `blockAndHideLogs` | `false` | Hides the conversation from both sides' inbox |

**Side effects on block**:
- If `areFriends(blockerId, blockedId)` → `deleteFriendship` immediately.
- Any pending friend request between the pair is invalidated (cannot send while block exists).

### 2.2 Conversation Visibility After Block

- The 1:1 `Conversation` DB record is **not deleted**; it remains in the database.
- Frontend: the conversation is **removed from the main inbox** and effectively hidden from both parties.
- Neither party can send new messages (backend enforces via block check on `sendMessage`).
- Neither party can initiate calls.

> [!IMPORTANT]
> **Code gap**: `sendMessage` in message-service does not currently check `core-service` block_list before allowing sends. Backend enforcement must be added.

### 2.3 Block in Group Chat

- Block applies **across all shared conversations**, including group chats.
- If user A blocks user B:
  - A's `getMessages` query must **exclude** B's messages in any shared group.
  - B's `getMessages` query must **exclude** A's messages in any shared group.
- They remain technical members of the group; only message visibility is filtered.

> [!IMPORTANT]
> **Code gap**: `getMessages` query in message-service has no block-aware filter. Must add exclusion logic referencing block_list (via Redis cache or synchronous cross-service call).

### 2.4 Unblock Behaviour

- Deletes the `BlockList` row.
- The 1:1 conversation **reappears** in both users' inboxes with full chat history.
- Friend request can be re-sent after unblock.

### 2.5 Mutual Block

- `blockAndHideLogs = true` hides the conversation from **both** sides (blocker and blocked).
- This is a per-block-record setting; each user blocking the other independently sets their own flag.

---

## 3. Block State in Friend Request Flow

```
sequenceDiagram:
  sendFriendRequest(A, B)
    → blockListRepository.existsBlockBetween(A, B)
    → if true: throw SOCIAL_USER_BLOCKED (403)
```

This is symmetric: A blocking B OR B blocking A prevents either from sending to the other.

---

## 4. Decisions

1. Keep friend_request and friendship as separate domain lifecycle tables.
2. Keep bidirectional block model in block_list.
3. Keep QR flow integrated with social add-friend operation.
4. Keep pending badge count surfaced through /friends/stats with fallback list count in mobile.
5. No friend request cooldown: sender can re-send immediately after a decline or cancel.
6. Block hides conversation from both parties; DB record is preserved for unblock restoration.
7. Block applies to group messages: blocked users' messages are invisible to blocker in any shared group.

---

## 5. Task Breakdown

| Task | Status | Priority | Notes |
|---|---|---|---|
| Enforce block check in `sendMessage` (message-service) | Open | P0 | Cross-service call to core-service or Redis cache needed |
| Filter blocked-user messages in `getMessages` | Open | P1 | Core-service block_list integration |
| Hide conversation from inbox on block | Open | P1 | Frontend + inbox API update |
| Normalize mobile friend request APIs to core-service contracts | Done | — | FriendService maps paginated and field variants |
| Keep pending request badge in MainShell | Done | — | ContactProvider fetches and updates |
| Enforce privacy field allow_search_by_phone end-to-end | Open | P2 | Migration and runtime mapping drift noted |
| Harden contact sync privacy policy checks | Open | P2 | Gap documented in canonical feedback |
| Consolidate user phone lookup endpoint usage in mobile | Open | P2 | Both /users/phone/{phone} and /users/search-by-phone used |

---

## 6. Verification

### Functional

- Send, accept, decline, and cancel friend request flows complete without manual DB edits.
- Block flow: friendship deleted, conversation hidden from both inboxes.
- Unblock flow: conversation re-appears, chat history intact.
- Block check gates `sendFriendRequest`; blocked pair cannot add each other.
- Blocked user's messages not returned in `getMessages` for any shared conversation.
- Re-send friend request succeeds immediately after decline (no cooldown).
- QR scan add friend flow returns expected social action result.

### Contract

- Mobile service adapters can parse both list and page wrapper response forms.
- Social endpoint auth failures return consistent unauthorized or forbidden payloads.
- `blockAndHideLogs` behaviour consistent across mobile and API layer.

### Data

- friendship uniqueness holds for user pair.
- block_list uniqueness holds for blocker and blocked pair (no duplicate block rows).
- friend_request status transition path is one-way and timestamped.
- No friendship row exists when a block row exists between the same pair.

---

## 7. Evidence

- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/FriendController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/BlockController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/ContactSyncController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/QrController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/service/FriendService.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/service/BlockService.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/Friendship.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/FriendRequest.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/BlockList.java
- frontend/mobile/lib/services/friend_service.dart
- frontend/mobile/lib/features/contacts/providers/contact_provider.dart
