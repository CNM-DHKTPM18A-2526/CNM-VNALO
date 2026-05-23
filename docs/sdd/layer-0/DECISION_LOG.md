# DECISION LOG

> [!IMPORTANT]
> Every architecture-affecting choice is recorded here with status and evidence.

## Index

| ID | Title | Status | Effective Date |
| --- | --- | --- | --- |
| D-001 | Code-First Reconcile Governance | Accepted | 2026-04-19 |
| D-002 | Shared HS512 JWT Across Core and Node Services | Accepted | 2026-04-19 |
| D-003 | Dual WebSocket Gateways | Accepted | 2026-04-19 |
| D-004 | Active Mobile Real-Time Path Uses message-service chat namespace | Accepted | 2026-04-19 |
| D-005 | Media Service Uses Dedicated Database | Accepted | 2026-04-19 |
| D-006 | Notification User Identity from X-User-Id Header | Accepted with Risk | 2026-04-19 |
| D-007 | Call Signaling Offline Fallback via Redis CALL_OFFLINE Publish | Accepted | 2026-04-19 |
| D-008 | restrictedWebMode Runtime Override in chat.gateway | Accepted with Risk | 2026-04-19 |
| D-009 | Content Service Mutating Identity via X-User-Id with permitAll Security | Accepted with Risk | 2026-04-20 |
| D-010 | Runtime Status in Blueprint Follows Default Compose Activation | Accepted | 2026-04-20 |
| D-011 | MemberRole Enum Rename: OWNER→ADMIN, ADMIN→DEPUTY | Accepted | 2026-04-22 |
| D-012 | Group Disband Performs Immediate Hard Delete of Messages and S3 Media | Accepted | 2026-04-22 |
| D-013 | Block Applies to Group Messages Cross-Conversation | Accepted | 2026-04-22 |
| D-014 | group.disbanded is a New First-Class WS Event | Accepted | 2026-04-22 |
| D-015 | Face Auth: ONNX ArcFace + MiniFASNetV2 in core-service, no separate microservice | Accepted | 2026-05-23 |

---

## D-001 Code-First Reconcile Governance

- Context: Legacy docs and feedback reports have partial drift across services.
- Decision: Code is authoritative for current behavior; specs are revised from code scan.
- Consequence:
  - Faster drift correction.
  - Requires explicit Layer 4 tracking when code is wrong by design intent.
- Evidence:
  - docs/sdd/README.md
  - docs/sdd/layer-4/SYSTEM_RECONCILE_REPORT.md

## D-002 Shared HS512 JWT Across Core and Node Services

- Context: core-service issues tokens and Node services validate without synchronous auth call.
- Decision: Maintain shared secret and issuer contract for core-service, message-service, realtime-gateway, and Java JWT filters.
- Consequence:
  - Low-latency auth checks.
  - Secret rotation must be coordinated across services.
- Evidence:
  - backend/java-services/services/core-service/src/main/resources/application.yml
  - backend/node-services/apps/message-service/src/auth/jwt.strategy.ts
  - backend/node-services/apps/realtime-gateway/src/app.module.ts

## D-003 Dual WebSocket Gateways

- Context: message-service already provides chat signaling; realtime-gateway provides additional presence and room federation path.
- Decision: Keep both gateways but document explicit responsibilities.
- Consequence:
  - Requires strict namespace and event contract governance.
  - Avoid duplicate event semantics without versioning.
- Evidence:
  - backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
  - backend/node-services/apps/realtime-gateway/src/gateway/realtime.gateway.ts

## D-004 Active Mobile Real-Time Path Uses message-service chat namespace

- Context: Mobile socket client currently connects to socketUrl/chat.
- Decision: Treat message-service gateway as the active production path for chat and call signaling.
- Consequence:
  - Hardening priority remains on message-service for mobile user flows.
  - realtime-gateway migration requires an explicit cutover plan.
- Evidence:
  - frontend/mobile/lib/services/socket_service.dart
  - frontend/mobile/lib/config/app_config.dart

## D-005 Media Service Uses Dedicated Database

- Context: Media service configuration points to vnalo_media while other core domains use vnalo_core.
- Decision: Keep media persistence isolated in separate DB.
- Consequence:
  - Clearer storage boundary for binaries and metadata lifecycle.
  - Cross-service joins must remain API/event based, not SQL joins.
- Evidence:
  - docker/docker-compose.yml
  - backend/java-services/services/media-service/src/main/resources/application.yml

## D-006 Notification User Identity from X-User-Id Header

- Context: Notification controller methods require X-User-Id header and there is no service-local Spring Security chain in code.
- Decision: Keep current pattern for now and classify as risk.
- Consequence:
  - Simpler service integration.
  - Trust boundary is weak until JWT-based authn is enforced.
- Evidence:
  - backend/java-services/services/notification-service/src/main/java/iuh/cnm/vnalo/notification_service/controller/NotificationController.java

## D-007 Call Signaling Offline Fallback via Redis CALL_OFFLINE Publish

- Context: call.offer to offline targets would otherwise be dropped.
- Decision: Publish CALL_OFFLINE events when target user has no active socket.
- Consequence:
  - Enables deferred push handling by downstream consumers.
  - Requires consumer implementation to complete end-to-end delivery.
- Evidence:
  - backend/node-services/apps/message-service/src/gateway/chat.gateway.ts

## D-008 restrictedWebMode Runtime Override in chat.gateway

- Context: Gateway connection currently forces restrictedWebMode effective false even if token carries the claim.
- Decision: Preserve behavior for current compatibility, document as explicit risk.
- Consequence:
  - Reduced policy enforcement at gateway layer.
  - Security policy enforcement must be reintroduced intentionally with test coverage.
- Evidence:
  - backend/node-services/apps/message-service/src/gateway/chat.gateway.ts

## D-009 Content Service Mutating Identity via X-User-Id with permitAll Security

- Context: content-service security config permits all requests while mutating endpoints rely on X-User-Id header.
- Decision: Keep current pattern documented as explicit risk until JWT-backed service boundary is introduced.
- Consequence:
  - Simpler interim integration with existing clients.
  - Weak trust boundary for identity-sensitive write operations.
- Evidence:
  - backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/config/SecurityConfig.java
  - backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/controller/PostController.java
  - backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/controller/StoryController.java

## D-010 Runtime Status in Blueprint Follows Default Compose Activation

- Context: some services exist in code but are not active by default in docker-compose runtime.
- Decision: Runtime status in Layer 0 blueprint must reflect default compose activation, not only code presence.
- Consequence:
  - More accurate operational expectations for local and CI environments.
  - Clear distinction between implemented services and default active services.
- Evidence:
  - docker/docker-compose.yml
  - docs/sdd/layer-0/ARCHITECTURE_BLUEPRINT.md

## D-011 MemberRole Enum Rename: OWNER→ADMIN, ADMIN→DEPUTY

- Context: Domain audit 2026-04-22 confirmed that business terminology for group roles does not match code enum names. OWNER in code represents the active group leader (Trưởng nhóm), not just the creator. ADMIN in code represents deputies (Phó nhóm).
- Decision: Rename `MemberRole.OWNER → ADMIN` and `MemberRole.ADMIN → DEPUTY` across all message-service entities, services, gateways, and Flutter models. The `createdBy` field in Conversation is preserved as an audit reference only and confers no runtime privilege.
- Consequence:
  - DB migration required: ALTER TYPE member_role RENAME VALUE.
  - All role checks in conversation.service, message.service, and chat.gateway must use new names.
  - Flutter MemberRole enum must be updated in sync.
- Evidence:
  - docs/sdd/layer-2/MODULE_SPEC_CHAT.md §1
  - backend/node-services/apps/message-service/src/entities/conversation-member.entity.ts

## D-012 Group Disband Performs Immediate Hard Delete of Messages and S3 Media

- Context: When the last remaining member (ADMIN) leaves a group or explicitly calls disband, there is no reversibility requirement. Data should not persist.
- Decision: Disband triggers immediate, atomic hard delete of all Message, ConversationMember, ConversationInbox, and Conversation rows. Media files referenced by deleted messages must also be deleted from S3 via media-service.
- Consequence:
  - Disband is irreversible. No grace period.
  - Requires cross-service call from message-service to media-service for S3 cleanup.
  - Frontend must clear local SQLite cache immediately on receiving `group.disbanded` event.
- Evidence:
  - docs/sdd/layer-2/MODULE_SPEC_CHAT.md §2.4

## D-013 Block Applies to Group Messages Cross-Conversation

- Context: Standard platform expectation (aligned with major messaging apps) is that a block relationship silences both parties everywhere, not only in direct messages.
- Decision: When user A blocks user B, message queries (`getMessages`) for any conversation where both A and B are members must exclude messages from the blocked party. This applies to both 1:1 and group conversations.
- Consequence:
  - `getMessages` in message-service requires awareness of core-service block_list.
  - Recommended implementation: Redis-cached block set per user, refreshed on block/unblock events.
  - Cross-service coordination required between message-service (Node) and core-service (Java).
- Evidence:
  - docs/sdd/layer-2/MODULE_SPEC_SOCIAL.md §2.3
  - backend/node-services/apps/message-service/src/message/message.service.ts getMessages

## D-014 group.disbanded is a New First-Class WS Event

- Context: No WS event currently signals group disbandment to connected clients, leaving clients with stale local caches.
- Decision: Add `group.disbanded` as a new Socket.IO event emitted by chat.gateway to the conversation room immediately after the disband cascade completes. Payload: `{ conversationId: string, disbandedAt: ISO8601 }`.
- Consequence:
  - chat.gateway must emit this event after successful `disbandGroup()` call.
  - SOCKET_SIGNALING_SCHEMA.md (Layer 3) must document this event.
  - Flutter ChatProvider must subscribe and trigger immediate local SQLite cache purge.
- Evidence:
  - docs/sdd/layer-2/MODULE_SPEC_CHAT.md §2.4
  - docs/sdd/layer-3/SOCKET_SIGNALING_SCHEMA.md (update required)

## D-015 Face Auth: ONNX ArcFace + MiniFASNetV2 in core-service, no separate microservice

- Context: Face authentication requires embedding extraction (ArcFace) and liveness detection (MiniFASNetV2). Initial analysis considered separate microservice, GPU inference, and pgvector storage.
- Decision: Embed face auth as a feature module within core-service using ONNX Runtime (CPU-only) for inference and AES-256-GCM encrypted Postgres TEXT storage for embeddings. No GPU, no pgvector, no separate service.
- Consequence:
  - CPU inference limits throughput (~15-45ms per request, suitable for login-scale load).
  - Embedding storage is encrypted at rest with application-level AES-256-GCM.
  - ONNX models must be bundled in the container image or mounted as a volume.
  - Feature is disabled by default; must be explicitly enabled via `FACE_AUTH_ENABLED=true` and `FACE_ENCRYPTION_KEY` must be set.
- Evidence:
  - docs/sdd/layer-2/MODULE_SPEC_FACE_AUTH.md
  - backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/FaceAuthController.java
  - backend/java-services/services/core-service/src/main/resources/db/migration/V27__add_face_auth.sql
