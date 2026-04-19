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
