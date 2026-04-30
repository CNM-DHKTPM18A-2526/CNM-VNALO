# REMEDIATION BLUEPRINT

> **Authority:** This blueprint is the **implementation roadmap** derived from all hardened VNALO specifications. It lists every code change required to meet the new RFC 2119 standards. Items marked `[SPEC_ONLY]` are not yet implemented and MUST be prioritized.

> **Generated from:** MODULE_SPEC_CHAT.md, architecture.md, MODULE_SPEC_POLL.md, MODULE_SPEC_AI_ASSISTANT.md, MODULE_SPEC_MEDIA_PROXY.md
> **Version:** 1.0
> **Date:** 2026-04-29

---

## HOW TO USE THIS DOCUMENT

Each item follows this format:

```
[P-<priority>] <service> — <title>
  Specification: <spec section>
  Required Change: <concrete code change>
  Files: <file paths>
  Test: <verification criteria>
```

Priority:
- **P0** = Immediate production risk, must fix before next deploy
- **P1** = Security/functional gap, must fix within sprint
- **P2** = Technical debt, schedule within 2 sprints
- **P3** = Future improvement, backlog

---

## PART I — SECURITY & AUTHZ (SG-1, SG-2)

### [P0] message-service — Enforce SG-1 on ALL Socket.IO event handlers

**Specification:** MODULE_SPEC_CHAT.md §SG-1

Every Socket.IO event handler **MUST** verify active membership in real-time. Currently, `message.typing` silently drops without membership check.

**Required Change:**
```typescript
// Every handler must follow this exact pattern:
@SubscribeMessage('message.typing')
async handleTyping(@ConnectedSocket() client: Socket, @MessageBody() payload: any) {
  const userId = client.data.userId;

  // MUST: Real-time DB check (NOT in-memory cache)
  const membership = await this.conversationService.findActiveMember(
    payload.conversationId,
    userId,
  );

  // MUST: Reject if not active member
  if (!membership) {
    return; // Silently drop, per spec
  }

  // Proceed with typing indicator emission
}
```

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`

**Test:**
- Emit `message.typing` from a user who has `leftAt` set → event silently dropped, no error to client
- Emit `message.typing` from a non-member → event silently dropped
- Emit `message.typing` from active member → event broadcast to room

---

### [P0] message-service — Implement SG-1 on `group.*` events

**Specification:** MODULE_SPEC_CHAT.md §SG-1

`group.addMembers`, `group.removeMember`, `group.updateSettings`, `group.transferAdmin`, `group.disband`, `conversation.join` must all enforce role membership in real-time.

**Required Change:** Add real-time `findActiveMember()` call at the start of every privileged event handler. Do NOT trust cached membership.

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`
- `backend/node-services/apps/message-service/src/conversation/conversation.service.ts`

**Test:**
- Non-admin calls `group.disband` → 403 `FORBIDDEN` emitted
- User who left calls `message.send` → `AUTH_DENIED` emitted
- Non-member calls `conversation.join` → `NOT_MEMBER` emitted

---

### [P0] message-service — Fix `restrictedWebMode` enforcement

**Specification:** MODULE_SPEC_CHAT.md §SG-2

Currently `restrictedWebMode` is forced to `false` at gateway layer. This overrides JWT content.

**Required Change:** Remove the hardcoded override. Allow JWT claim to control `restrictedWebMode`.

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`

**Test:**
- JWT with `restrictedWebMode: true` → certain operations blocked per spec
- JWT without `restrictedWebMode` claim → defaults to `false` (permissive)

---

### [P1] content-service — Replace `permitAll` with JWT validation

**Specification:** architecture.md §2.2, D-009

`content-service` currently uses `permitAll` security config and trusts `X-User-Id` header for mutating operations.

**Required Change:**
```java
// SecurityConfig.java — REQUIRED
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            // ALL mutating endpoints require authentication
            .requestMatchers(HttpMethod.POST, "/api/v1/posts/**").authenticated()
            .requestMatchers(HttpMethod.PUT, "/api/v1/posts/**").authenticated()
            .requestMatchers(HttpMethod.DELETE, "/api/v1/posts/**").authenticated()
            .requestMatchers(HttpMethod.POST, "/api/v1/stories/**").authenticated()
            // Read endpoints may be public
            .anyRequest().permitAll()
        )
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
}
```

**Files:**
- `backend/java-services/services/content-service/src/main/java/.../config/SecurityConfig.java`
- `backend/java-services/services/content-service/src/main/java/.../controller/PostController.java`

**Test:**
- Request to POST /api/v1/posts without JWT → HTTP 401
- Request to POST /api/v1/posts with valid JWT → HTTP 200 or appropriate response

---

### [P1] notification-service — Replace `X-User-Id` header trust with JWT validation

**Specification:** architecture.md §2.2, D-006

`notification-service` trusts `X-User-Id` header for identity instead of validating JWT.

**Required Change:**
```java
// Add JWT filter to notification-service
// Remove X-User-Id header usage from controllers
// Validate JWT on every request
```

**Files:**
- `backend/java-services/services/notification-service/src/main/java/.../config/SecurityConfig.java`
- `backend/java-services/services/notification-service/src/main/java/.../controller/NotificationController.java`

**Test:**
- Request without JWT → HTTP 401
- Request with valid JWT → proceed to controller
- Request with `X-User-Id` header but no JWT → HTTP 401

---

### [P1] ai-service — Enforce JWT on all endpoints

**Specification:** MODULE_SPEC_AI_ASSISTANT.md §SR-1

`ai-service` MUST validate JWT on every request. Anonymous access is prohibited.

**Required Change:**
```java
// SecurityConfig.java — REQUIRED
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .anyRequest().authenticated()  // ALL endpoints require JWT
        )
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
}
```

**Files:**
- `backend/java-services/services/ai-service/src/main/java/.../config/SecurityConfig.java`

**Test:**
- Request to `/api/v1/ai/chat` without JWT → HTTP 401
- Request with valid JWT → proceed to controller

---

## PART II — DATA INTEGRITY & TRANSACTIONS (TI-1, TI-2, TI-3)

### [P0] message-service — Wrap all group mutations in DB transactions

**Specification:** MODULE_SPEC_CHAT.md §TI-1

Group ownership transfer, member removal, and disbanding MUST be atomic. Currently, some operations may not be fully transactional.

**Required Change — Transfer Admin:**
```typescript
// conversation.service.ts — REQUIRED
async transferAdmin(conversationId: string, currentAdminId: string, targetUserId: string) {
  return this.dataSource.transaction(async (manager) => {
    // Step 1: Lock current admin
    const currentAdmin = await manager.findOne(ConversationMember, {
      where: { conversationId, role: 'ADMIN', leftAt: IsNull() },
      lock: { mode: 'pessimistic_write' }
    });
    if (!currentAdmin) throw new ForbiddenException('No ADMIN found');

    // Step 2: Lock target
    const target = await manager.findOne(ConversationMember, {
      where: { conversationId, userId: targetUserId, leftAt: IsNull() }
    });
    if (!target) throw new ForbiddenException('Target is not an active member');

    // Step 3: Verify target is not already ADMIN
    if (target.role === 'ADMIN') throw new BadRequestException('Target is already ADMIN');

    // Step 4: Update roles
    await manager.update(ConversationMember, currentAdmin.id, { role: 'MEMBER' });
    await manager.update(ConversationMember, target.id, { role: 'ADMIN' });

    // Step 5: Insert system message
    await manager.save(Message, { ...systemMessagePayload });

    return { success: true };
  });
}
```

**Required Change — Remove Member:**
```typescript
async removeMember(conversationId: string, callerId: string, targetId: string) {
  return this.dataSource.transaction(async (manager) => {
    // Lock conversation to prevent concurrent modifications
    await manager.findOne(Conversation, {
      where: { id: conversationId },
      lock: { mode: 'pessimistic_write' }
    });

    // Verify caller role
    const caller = await manager.findOne(ConversationMember, {
      where: { conversationId, userId: callerId, leftAt: IsNull() }
    });
    if (!['ADMIN', 'DEPUTY'].includes(caller.role)) {
      throw new ForbiddenException('Insufficient role');
    }

    // Verify target role
    const target = await manager.findOne(ConversationMember, {
      where: { conversationId, userId: targetId, leftAt: IsNull() }
    });
    if (!target) throw new NotFoundException('Member not found');
    if (target.role === 'ADMIN') {
      throw new ForbiddenException('Cannot remove ADMIN');
    }

    // Soft-delete member
    await manager.update(ConversationMember, target.id, {
      leftAt: new Date(),
      removedBy: callerId
    });

    // Delete orphaned inbox
    await manager.delete(ConversationInbox, {
      conversationId, userId: targetId
    });

    // Insert system message
    await manager.save(Message, { ...systemMessagePayload });

    return { success: true };
  });
}
```

**Files:**
- `backend/node-services/apps/message-service/src/conversation/conversation.service.ts`

**Test:**
- Concurrent `transferAdmin` calls → only one succeeds, DB invariant maintained
- ADMIN removed mid-transaction → DB rolls back, conversation unchanged
- Member removal → inbox orphaned row deleted within same transaction

---

### [P0] message-service — Implement block filtering in `getMessages`

**Specification:** MODULE_SPEC_CHAT.md §TI-3

Messages from blocked users MUST be excluded from all message queries. Currently, block filtering is not implemented.

**Required Change:**
```typescript
async getMessages(conversationId: string, userId: string, options?: GetMessagesOptions) {
  // Step 1: Build block set (Redis cache → fallback to PostgreSQL)
  const blockSet = await this.blockCache.getBlockSet(userId);
  // blockSet = blocked users + users who blocked me (bidirectional)

  // Step 2: Query messages excluding blocked senders
  const query = this.messageRepo.createQueryBuilder('m')
    .where('m.conversationId = :conversationId', { conversationId })
    .andWhere('m.senderId NOT IN (:...blockedIds)', {
      blockedIds: blockSet.length > 0 ? blockSet : [null]
    })
    .andWhere('m.status != :recalled', { recalled: MessageStatus.RECALLED });

  // Step 3: Execute with pagination
  const messages = await query
    .orderBy('m.serverSeq', 'DESC')
    .skip(offset)
    .take(limit)
    .getMany();
}
```

**Files:**
- `backend/node-services/apps/message-service/src/message/message.service.ts`
- `backend/node-services/apps/message-service/src/cache/block.cache.ts` (new)

**Test:**
- User A blocks User B → User A's `getMessages` returns no messages from User B
- Block is bidirectional: User B also cannot see User A's messages
- Block applies in 1:1 AND group conversations

---

### [P1] message-service — Implement Redis block set cache

**Specification:** MODULE_SPEC_CHAT.md §TI-3

Block set MUST be cached in Redis for performance. Cache invalidation on block/unblock events.

**Required Change:**
```typescript
// Redis key: block_set:{userId}
// Value: Set of blocked user UUIDs (bidirectional)
// TTL: 1 hour
// Invalidation: on POST /blocks/{userId} and DELETE /blocks/{userId}

async getBlockSet(userId: string): Promise<string[]> {
  const cached = await this.redis.smembers(`block_set:${userId}`);
  if (cached.length > 0) return cached;

  // Cache miss: rebuild from PostgreSQL
  const blocked = await this.blockRepo.find({ where: { blockerId: userId }, select: ['blockedId'] });
  const blockers = await this.blockRepo.find({ where: { blockedId: userId }, select: ['blockerId'] });
  const blockSet = [...blocked.map(b => b.blockedId), ...blockers.map(b => b.blockerId)];

  if (blockSet.length > 0) {
    await this.redis.sadd(`block_set:${userId}`, ...blockSet);
    await this.redis.expire(`block_set:${userId}`, 3600); // 1 hour TTL
  }

  return blockSet;
}
```

**Files:**
- `backend/node-services/apps/message-service/src/cache/block.cache.ts` (new)
- `backend/node-services/apps/message-service/src/message/message.service.ts`

**Test:**
- After block: Redis cache populated, subsequent `getMessages` excludes blocked user
- After unblock: Redis cache invalidated, `getMessages` includes user again
- Cache TTL expires: next `getMessages` rebuilds cache from DB

---

### [P2] message-service — Implement Kafka block event consumer

**Specification:** MODULE_SPEC_CHAT.md §TI-3

When `core-service` publishes block/unblock events to Kafka, `message-service` MUST consume and invalidate Redis block cache.

**Required Change:**
```typescript
// Kafka consumer in message-service
@EventPattern('user.blocked')
async handleUserBlocked(@Payload() payload: { blockerId: string, blockedId: string }) {
  // Invalidate both users' block cache
  await this.blockCache.invalidate(payload.blockerId);
  await this.blockCache.invalidate(payload.blockedId);
}
```

**Files:**
- `backend/node-services/apps/message-service/src/events/block.event-consumer.ts` (new)

---

## PART III — REAL-TIME OPTIMIZATION (LZ-1, LZ-2)

### [P0] message-service — Replace per-user loops with room-based emission

**Specification:** MODULE_SPEC_CHAT.md §LZ-1

`message.send` currently uses a per-user loop to deliver to all members. This MUST be replaced with room-based emission.

**Current (PROHIBITED):**
```typescript
// ❌ PROHIBITED — remove this
for (const member of members) {
  this.server.to(member.userId).emit('message.received', message);
}
```

**Required Change:**
```typescript
// ✅ REQUIRED
// 1. Persist message to DB
// 2. Assign serverSeq via Redis INCR
// 3. Emit to room — ALL sockets in room receive the event
this.server.to(`conversation:${conversationId}`).emit('message.received', message);

// For inbox update on clients NOT in the room:
// Use conversation.inbox update (not per-user socket emission)
await this.inboxService.refreshInbox(conversationId, message);
```

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`
- `backend/node-services/apps/message-service/src/message/message.service.ts`

**Test:**
- Message sent in conversation with 10 members → exactly ONE WebSocket event emitted (not 10)
- Performance: measure latency with 100+ members in group

---

### [P1] message-service — Scope `presence.changed` to mutual contacts

**Specification:** MODULE_SPEC_CHAT.md §LZ-2

`presence.changed` currently uses `server.emit()` (global broadcast). This MUST be scoped to mutual contacts.

**Required Change:**
```typescript
// Instead of:
this.server.emit('presence.changed', { userId, status }); // ❌ Global broadcast

// Implement:
async broadcastPresenceChange(userId: string, status: 'online' | 'offline') {
  const mutualContacts = await this.contactCache.getMutualContacts(userId);

  // Batch emit to each mutual contact's sockets
  for (const contactId of mutualContacts) {
    this.emitToUser(contactId, 'presence.changed', { userId, status });
  }
}
```

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`
- `backend/node-services/apps/message-service/src/cache/contact.cache.ts` (new)

**Test:**
- User comes online → only mutual contacts receive `presence.changed`
- Non-contacts do NOT receive the event

---

## PART IV — ERROR RESILIENCE (ER-1)

### [P0] All frontends — Implement global 401/403 logout flow

**Specification:** MODULE_SPEC_CHAT.md §ER-1

All Axios interceptors (Web) and Dio interceptors (Mobile) MUST handle 401/403 by triggering global logout and clearing local cache.

**Web (Required):**
```typescript
// frontend/web/src/api.client.ts — ADD
const globalLogoutHandler = () => {
  window.dispatchEvent(new CustomEvent('vnalo:auth:revoked', {
    detail: { reason: 'token_expired' }
  }));
};

[mediaApi, messageApi, api].forEach(client => {
  client.interceptors.response.use(
    res => res,
    err => {
      if (err.response?.status === 401 || err.response?.status === 403) {
        globalLogoutHandler();
      }
      return Promise.reject(err);
    }
  );
});
```

**Files:**
- `frontend/web/src/api.client.ts`
- `frontend/web/src/main.tsx` (listen to `vnalo:auth:revoked` event, call `logout()`)

**Mobile (Required):**
```dart
// Flutter interceptor — REQUIRED
class AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 || err.response?.statusCode == 403) {
      AuthProvider.of(context).globalLogout(
        reason: 'UNAUTHORIZED',
        clearCache: true,
        clearTokens: true,
      );
    }
    handler.next(err);
  }
}
```

**Files:**
- `frontend/mobile/lib/core/dio_client.dart` (add AuthInterceptor)
- `frontend/mobile/lib/providers/auth_provider.dart` (implement globalLogout)

**Test:**
- Backend returns 401 → all pending requests fail, user redirected to login
- Token expires during session → next API call triggers logout flow
- Web: `vnalo:auth:revoked` event fires, AuthContext clears state

---

### [P0] All frontends — Handle structured Socket.IO error events

**Specification:** MODULE_SPEC_CHAT.md §ER-1

Socket.IO error events from gateway MUST be handled with specific actions. Silent failures are prohibited.

**Required Change:**
```typescript
// Web socket service
socket.on('message.error', (payload) => {
  switch (payload.code) {
    case 'AUTH_DENIED':
      // Remove optimistic message from UI
      dispatch(removeOptimisticMessage(payload.clientMessageId));
      toast.error('Bạn không có quyền gửi tin nhắn này.');
      break;
    case 'NOT_MEMBER':
      // Navigate away from conversation
      navigate('/chat');
      dispatch(evictConversation(payload.conversationId));
      toast.error('Bạn không còn là thành viên của cuộc trò chuyện.');
      break;
    default:
      toast.error(payload.message || 'Lỗi gửi tin nhắn.');
  }
});

socket.on('conversation.error', (payload) => {
  switch (payload.code) {
    case 'FORBIDDEN':
      // Refresh conversation state
      dispatch(refreshConversation(payload.conversationId));
      toast.error('Bạn không có quyền thực hiện hành động này.');
      break;
    default:
      toast.error(payload.message || 'Lỗi cuộc trò chuyện.');
  }
});
```

**Files:**
- `frontend/web/src/services/socket.service.ts`
- `frontend/mobile/lib/services/socket_service.dart`

**Test:**
- Non-member sends message → optimistic message removed, toast shown
- User removed while viewing → navigate away from conversation

---

## PART V — MEDIA (MC-1, MC-2)

### [P0] media-service — Implement magic byte file validation

**Specification:** MODULE_SPEC_MEDIA_PROXY.md §SR-2

Upload MUST validate MIME type using magic bytes, not client-reported Content-Type.

**Required Change:**
```java
// MediaValidationService.java — REQUIRED
public String detectMimeType(byte[] bytes) {
    if (bytes.length < 4) throw new BadRequestException("File too small");

    // PNG: 89 50 4E 47
    if (bytes[0] == (byte)0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47)
        return "image/png";

    // JPEG: FF D8 FF
    if (bytes[0] == (byte)0xFF && bytes[1] == (byte)0xD8 && bytes[2] == (byte)0xFF)
        return "image/jpeg";

    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38)
        return "image/gif";

    // PDF: 25 50 44 46
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46)
        return "application/pdf";

    // MP4: 00 00 00 XX 66 74 79 70 (ftyp box)
    // WEBM: 1A 45 DF A3
    // etc.

    throw new BadRequestException("Unsupported file type");
}
```

**Files:**
- `backend/java-services/services/media-service/src/.../service/MediaValidationService.java` (new)
- `backend/java-services/services/media-service/src/.../service/MediaUploadService.java`

**Test:**
- Upload file with fake MIME type → detected magic bytes used → correct type
- Upload executable disguised as image → rejected
- Upload with `image/jpeg` header but PNG magic bytes → rejected as PNG

---

### [P0] media-service — Implement per-category size limits

**Specification:** MODULE_SPEC_MEDIA_PROXY.md §SR-3

**Required Change:**
```java
// MediaValidationService.java — REQUIRED
private static final Map<MediaCategory, Long> SIZE_LIMITS = Map.of(
    MediaCategory.CHAT_IMAGE, 20L * 1024 * 1024,   // 20 MB
    MediaCategory.CHAT_VIDEO, 100L * 1024 * 1024,   // 100 MB
    MediaCategory.CHAT_FILE, 100L * 1024 * 1024,     // 100 MB
    MediaCategory.AVATAR, 5L * 1024 * 1024,         // 5 MB
    MediaCategory.CHAT_VOICE, 30L * 1024 * 1024,   // 30 MB
    MediaCategory.COVER, 10L * 1024 * 1024          // 10 MB
);

public void validateSize(MediaCategory category, long size) {
    Long limit = SIZE_LIMITS.get(category);
    if (limit == null) limit = 100L * 1024 * 1024; // Default 100MB
    if (size > limit) {
        throw new PayloadTooLargeException(
            String.format("File size %d exceeds limit %d for category %s", size, limit, category)
        );
    }
}
```

**Test:**
- Upload 21MB image → HTTP 413
- Upload 99MB video → HTTP 200
- Upload 101MB video → HTTP 413

---

### [P1] media-service — Enforce JWT on all media GET endpoints

**Specification:** MODULE_SPEC_MEDIA_PROXY.md §SR-4

**Required Change:**
```java
// SecurityConfig.java
.authorizeHttpRequests(auth -> auth
    .requestMatchers(HttpMethod.GET, "/api/v1/media/public/**").permitAll()  // Stickers, emojis
    .requestMatchers(HttpMethod.GET, "/api/v1/media/storage/**").authenticated()  // Private media
    .requestMatchers(HttpMethod.GET, "/api/v1/media/**").authenticated()
    .anyRequest().authenticated()
)
```

**Test:**
- GET /api/v1/media/{id} without JWT → HTTP 401
- GET /api/v1/media/public/{id} (sticker) without JWT → HTTP 200

---

## PART VI — POLL SYSTEM (SPEC ONLY)

### [P0] message-service — Implement `poll.vote` with SG-1 and transaction

**Specification:** MODULE_SPEC_POLL.md

Poll voting MUST verify active membership and use DB transaction.

**Required Change:** See MODULE_SPEC_POLL.md §7.1 for full transaction specification.

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`
- `backend/node-services/apps/message-service/src/message/message.service.ts`

---

### [P0] message-service — Implement `poll.close` with authorization

**Specification:** MODULE_SPEC_POLL.md §SR-3

Only poll creator may close. Non-creator attempts return `POLL_NOT_CREATOR`.

**Files:**
- `backend/node-services/apps/message-service/src/gateway/chat.gateway.ts`

---

### [P1] message-service — Emit `poll.updated` via room-based emission

**Specification:** MODULE_SPEC_POLL.md §8

Room emission only. No per-user loops.

---

### [P2] Web frontend — Implement PollBubble component

**Specification:** MODULE_SPEC_POLL.md §9

Web currently has no PollBubble. Mobile has it. Web must implement equivalent.

**Files:**
- `frontend/web/src/features/chat/components/PollBubble.tsx` (new)

---

## PART VII — AI ASSISTANT (SPEC ONLY)

### [P0] ai-service — Implement rate limiting (20 req/min/user)

**Specification:** MODULE_SPEC_AI_ASSISTANT.md §SR-4

**Required Change:**
```java
// AiRateLimitService.java — REQUIRED
public boolean isRateLimited(String userId) {
    String key = "ai_rate:" + userId;
    Long count = redisTemplate.opsForValue().increment(key);
    if (count == 1) {
        redisTemplate.expire(key, Duration.ofMinutes(1));
    }
    return count > 20;
}
```

**Files:**
- `backend/java-services/services/ai-service/src/.../service/AiRateLimitService.java` (new)
- `backend/java-services/services/ai-service/src/.../controller/AiController.java`

---

### [P1] ai-service — Implement Ollama fallback

**Specification:** MODULE_SPEC_AI_ASSISTANT.md §5.2

When Gemini returns 5xx or 429, attempt Ollama.

**Files:**
- `backend/java-services/services/ai-service/src/.../service/AiService.java`

---

### [P1] ai-service — Implement response content sanitization

**Specification:** MODULE_SPEC_AI_ASSISTANT.md §SR-3

Filter PII, malicious URLs, inappropriate content from AI responses.

---

## PART VIII — ADMIN INACTIVITY TRANSFER

### [P2] message-service — Implement admin inactivity cron job

**Specification:** MODULE_SPEC_CHAT.md §2.5

14-day inactivity auto-transfer.

**Files:**
- `backend/node-services/apps/message-service/src/scheduler/AdminInactivityScheduler.ts` (new)

---

## SUMMARY TABLE

| Priority | Count | Items |
|---|---|---|
| P0 (Immediate) | 11 | SG-1 enforcement, transaction wrapping, block filtering, logout flow, socket error handling, magic byte validation, size limits |
| P1 (Sprint) | 8 | JWT enforcement (content/notification/ai), Redis block cache, Kafka consumer, room emission, presence scoping, rate limiting, Ollama fallback, sanitization |
| P2 (2 sprints) | 5 | Kafka block consumer, PollBubble web, inactivity cron, presence contact scoping |
| P3 (Backlog) | 4 | CDN integration, CloudFront, signed URLs, WebP conversion |

**Total: 28 remediation items across 7 service boundaries.**

---

## PRIORITY ORDERING FOR NEXT SPRINT

```
Week 1 (P0):
  1. SG-1: membership check on all Socket.IO events
  2. Global 401/403 logout flow (Web + Mobile)
  3. Socket error event handlers
  4. Magic byte file validation
  5. Per-category size limits

Week 2 (P0 + P1):
  6. DB transaction wrapping for group mutations
  7. Block filtering in getMessages
  8. Room-based message emission (remove per-user loops)
  9. JWT enforcement on ai-service
  10. JWT enforcement on content-service
```
