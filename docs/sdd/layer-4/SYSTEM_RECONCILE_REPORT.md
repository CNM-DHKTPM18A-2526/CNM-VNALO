# SYSTEM RECONCILE REPORT

> [!IMPORTANT]
> Reconcile cycle: SCAN -> DIFF -> REVISE for VNALO SDD Digital Twin generation.

## Reconcile Metadata

| Field | Value |
|---|---|
| Cycle ID | `SDD-RECONCILE-2026-04-22` |
| Previous Cycle | `SDD-RECONCILE-2026-04-20` |
| Method | Code-first scan with spec synchronization |
| Scope | Flutter mobile, React web, Node services, Java services, docker runtime contracts |
| Output | Layer 0 to Layer 4 document refresh under `docs/sdd` |

## 1) SCAN Summary

### Source sets scanned

- Mobile runtime and navigation contracts (`frontend/mobile/lib`), including socket and call lifecycle.
- Node API and socket gateways (`backend/node-services/apps/message-service`, `backend/node-services/apps/realtime-gateway`).
- Java controllers, security configs, entities, exception handlers across core/content/media/moderation/notification/analytics/ai services.
- Infrastructure and runtime topology (`docker/docker-compose.yml`, service `application.yml` files).

### Extracted artifacts

- REST endpoint inventory and auth constraints.
- Socket signaling contracts for chat, typing, presence, and call events.
- Cross-domain entity model and logical foreign key graph.
- Error and exception handling matrices for each service stack.

## 2) DIFF Findings

### F-001 Notification identity trust boundary

| Item | Detail |
|---|---|
| Severity | High |
| Observation | Notification controller trusts `X-User-Id` header as user identity. |
| Expected target | JWT-validated principal or signed gateway identity propagation. |
| Risk | Header spoofing and unauthorized read/write of user notification feed. |
| Disposition | Accepted risk in current cycle, documented in decision log and error matrix. |

### F-002 restrictedWebMode policy override at chat gateway

| Item | Detail |
|---|---|
| Severity | High |
| Observation | Gateway sets effective `restrictedWebMode=false` even when token contains claim. |
| Expected target | Claim-driven restriction preserved end to end. |
| Risk | Policy bypass for web sessions unless downstream checks enforce constraints. |
| Disposition | Accepted with risk, captured in decision log and module constraints. |

### F-003 Dual WebSocket gateway contract overlap

| Item | Detail |
|---|---|
| Severity | Medium |
| Observation | `/chat` and `/realtime` both handle presence and room-based activity with partially overlapping semantics. |
| Expected target | Explicit ownership and migration strategy to avoid contract drift. |
| Risk | Client integration ambiguity and duplicate event semantics. |
| Disposition | Architecture blueprint and socket schema now define boundaries. |

### F-004 Error contract fragmentation

| Item | Detail |
|---|---|
| Severity | Medium |
| Observation | Mixed error envelopes and code systems across Java and Node services. |
| Expected target | Consistent envelope (`code`, `message`, optional `details/traceId`) across services. |
| Risk | Client-side parser complexity and weak cross-service observability. |
| Disposition | Documented in Layer 3 error matrix with normalization target. |

### F-005 Notification service error enums are underused

| Item | Detail |
|---|---|
| Severity | Medium |
| Observation | Notification service defines `ErrorCode` and `ApiException` but runtime paths mostly throw generic exceptions. |
| Expected target | Deterministic exception handling via service-level advice. |
| Risk | Inconsistent status/body and unstable client error handling. |
| Disposition | Marked for follow-up implementation task. |

### F-006 Content service mutating identity trust boundary

| Item | Detail |
|---|---|
| Severity | High |
| Observation | content-service security config permits all requests while mutating endpoints trust `X-User-Id` header. |
| Expected target | JWT-authenticated principal at service boundary for write operations. |
| Risk | Header spoofing allows unauthorized write operations on post, story, comment, and like paths. |
| Disposition | Accepted with risk in current cycle, documented in decision log and API catalog. |

### F-007 Runtime status drift between code presence and default compose activation

| Item | Detail |
|---|---|
| Severity | Medium |
| Observation | moderation-service is implemented but commented out in default compose; analytics-service runs only in planned profile. |
| Expected target | Layer 0 runtime status should reflect default compose activation behavior. |
| Risk | Incorrect operational assumptions during local integration and deployment checks. |
| Disposition | Corrected in architecture blueprint for this cycle. |

## 3) REVISE Actions Completed

| Action ID | Description | Status |
|---|---|---|
| R-0201 | Verified default docker-compose activation and service runtime status mapping | Completed |
| R-0202 | Updated Layer 0 topology and runtime matrix for moderation disabled-default and analytics planned profile | Completed |
| R-0203 | Updated Layer 3 API auth catalog for content-service header trust and core test utility endpoints | Completed |
| R-0204 | Added explicit chat.gateway restrictedWebMode runtime note in socket schema | Completed |
| R-0205 | Expanded Layer 3 global ERD with missing core/moderation/media entities and relations | Completed |
| R-0206 | Added new architectural decisions D-009 and D-010 for trust/runtime governance | Completed |
| R-0207 | Rewrote MODULE_SPEC_CHAT with group lifecycle, role taxonomy (ADMIN/DEPUTY/MEMBER), disbandment cascade | Completed |
| R-0208 | Rewrote MODULE_SPEC_CALL with 1:1 voice/video, multi-device ring, cross-platform matrix, ICE queuing | Completed |
| R-0209 | Rewrote MODULE_SPEC_SOCIAL with block semantics, friend state machine, privacy rules | Completed |
| R-0210 | Created MODULE_SPEC_REALTIME_SYNC with dual-delivery, multi-device sync, presence, known gaps | Completed |
| R-0211 | Created MODULE_SPEC_WEB_APP with React/Vite stack, route map, ChatPage feature set, restrictedWebMode | Completed |
| R-0212 | Created MODULE_SPEC_AI_ASSISTANT with state machine, mascot, STT/TTS, system actions | Completed |
| R-0213 | Rewrote SOCKET_SIGNALING_SCHEMA with all events, payload contracts, Flutter listener status | Completed |
| R-0214 | Updated GLOBAL_DATABASE_ERD: added only_admin_can_post, allow_member_* to CONVERSATION; block_and_hide_logs to BLOCK_LIST; Pending Schema Changes section | Completed |
| R-0215 | Updated NAVIGATION_MASTER_GRAPH with group sub-navigation, AI flows, profile tree, web routing | Completed |
| R-0216 | Added D-011 to D-014 to DECISION_LOG: role rename, hard-delete disbandment, group-wide block, group.disbanded event | Completed |
| R-0217 | Hardened `content-service` and `notification-service` with JWT auth (Closed Trust Boundary gaps F-001, F-006) | Completed |
| R-0218 | Enforced `restrictedWebMode` in `WsJwtGuard` and `MessageService` (Closed gap F-002) | Completed |
| R-0219 | Implemented `disbandGroup()` and `MemberRole` (ADMIN/DEPUTY/MEMBER) taxonomy in backend | Completed |
| R-0220 | Enforced `onlyAdminCanPost` logic and optimized membership checks in `MessageService` | Completed |

## 4) Traceability Matrix

| Runtime concern | SDD target |
|---|---|
| Service topology and trust boundaries | `layer-0/ARCHITECTURE_BLUEPRINT.md` |
| Governance and source-of-truth rules | `layer-0/CLAUDE.md` |
| Decision rationale and accepted risks | `layer-0/DECISION_LOG.md` |
| Mobile navigation and screen contracts | `layer-1/NAVIGATION_MASTER_GRAPH.md` and `SCREEN_SPEC_*` |
| Chat/group behavior | `layer-2/MODULE_SPEC_CHAT.md` |
| Call behavior (voice/video) | `layer-2/MODULE_SPEC_CALL.md` |
| Social/friend/block behavior | `layer-2/MODULE_SPEC_SOCIAL.md` |
| Real-time sync rules | `layer-2/MODULE_SPEC_REALTIME_SYNC.md` |
| Web app platform spec | `layer-2/MODULE_SPEC_WEB_APP.md` |
| AI assistant behavior | `layer-2/MODULE_SPEC_AI_ASSISTANT.md` |
| Endpoint and event contracts | `layer-3/API_REFERENCE_CATALOG.md`, `SOCKET_SIGNALING_SCHEMA.md` |
| Persistence and referential model | `layer-3/GLOBAL_DATABASE_ERD.md` |
| Error behavior and drift | `layer-3/ERROR_CODE_MATRIX.md` |

## 5) Open Risks and Owners

| Risk | Owner | Target window |
|---|---|---|
| Define single canonical realtime contract between `/chat` and `/realtime` | Architecture guild | Before multi-client gateway expansion |
| Normalize error envelope across services | API governance | Progressive rollout across next two releases |
| Implement S3 bulk deletion for disbanded groups | Messaging team | Phase 3 optimization |

## 6) Reconcile Verdict

> [!NOTE]
> Spec coverage for the VNALO Digital Twin is significantly expanded in this cycle.

- 10 new module spec sections added or rewritten across Layer 1, 2, 3.
- Web app (React/Vite) documented for the first time.
- AI Assistant formally documented for the first time.
- Navigation graph expanded from 12 to 50+ nodes.
- All major business rules (group lifecycle, role taxonomy, block semantics) are now in spec.
- ERD updated with pending schema changes for upcoming code sprint.
- **P0 Code Implementation**: `MemberRole` rename and `disbandGroup()` are now fully implemented and verified.
- **Security**: Major trust boundary and policy bypass gaps (F-001, F-002, F-006) are resolved.
- Next cycle should prioritize: Phase 3 optimizations (S3 cleanup, error normalization).

## Evidence

- `docs/sdd/layer-0`
- `docs/sdd/layer-1`
- `docs/sdd/layer-2`
- `docs/sdd/layer-3`
- `backend/java-services/services/**`
- `backend/node-services/apps/**`
- `frontend/mobile/lib/**`
- `docker/docker-compose.yml`
