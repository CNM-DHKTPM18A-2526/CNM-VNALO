# VNALO Security, Convention, and Zalo Gap Review (2026-03-17)

> Document status (2026-03-20): Đây là tài liệu reconcile chính cho security/convention ở message-service. Các mục "Evidence/Current behavior" bên dưới được giữ lại để truy vết lịch sử; trạng thái áp dụng hiện tại ưu tiên theo dòng `Reconcile status` của từng mục.

## 1) Scope and Method

This report consolidates:
- Current security and design issues found in the VNALO backend runtime/code.
- Convention consistency check for "max 100 participants".
- Product/design gap analysis versus publicly available, latest Zalo information.
- Impact assessment for introducing a paid upgrade model from normal group to community (max 1000).

System state used for this review:
- Java core-service + Node message-service running via Docker.
- Functional suites passed (smoke/enterprise/deep audit), but passing tests do not remove architectural/security flaws listed below.

### Reconcile Update (2026-03-19)

Status after remediation pass:
- Fixed: WS room join now enforces membership before joining a room.
- Fixed: `GET /conversations/:id/members` now verifies requester membership.
- Fixed: Pin/unpin now enforces role/setting policy (`allowMemberPin`).
- Fixed: Recall broadcast now emits using the recalled message's actual `conversationId`.
- Fixed: `DELETE /messages/:id/for-me` now verifies message conversation membership.
- Fixed: CORS in both message-service and core-service is now configurable by explicit origin list (`CORS_ALLOWED_ORIGINS`), not wildcard.
- Improved: Group join flow supports `APPROVAL` mode with pending queue (`conversation_join_request`) and admin/owner approve/reject endpoints.
- Updated policy: default `join_mode` changed to `OPEN` for Zalo-like default behavior, while `APPROVAL` remains configurable per group.

Residual risks still recommended:
- Apply websocket event throttling/rate limiting for flood protection.
- Add websocket integration tests for abuse and authorization edge cases.

---

## 2) Detailed Vulnerabilities and Defects

Read order recommendation:
- Mục có `Reconcile status: Fixed` chỉ còn giá trị lịch sử (để audit trail).
- Mục có `Reconcile status: Open` là rủi ro còn tồn tại cần xử lý.

### 2.1 Critical: WebSocket room join without membership authorization

Reconcile status (2026-03-19): Fixed.

Evidence:
- backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
  - handleJoinConversation() joins room directly from client-provided conversationId.

Current behavior:
- Any authenticated socket can request conversation.join with arbitrary conversationId.
- No assertMember(conversationId, userId) before room join.

Attack scenario:
1. Attacker has any valid account/token.
2. Guesses/leaks a conversation UUID.
3. Calls conversation.join.
4. Receives room broadcasts (message.received, typing, read, recall, etc.).

Impact:
- Confidentiality breach (conversation metadata leakage).
- Event stream exposure and possible social engineering/fraud leverage.

Severity: Critical

---

### 2.2 High: Member list endpoint leaks conversation participants

Reconcile status (2026-03-19): Fixed.

Evidence:
- backend/node-services/apps/message-service/src/conversation/conversation.controller.ts
  - GET :id/members calls service.getMembers(id)
- backend/node-services/apps/message-service/src/conversation/conversation.service.ts
  - getMembers(conversationId) returns active members without checking requester membership.

Current behavior:
- Endpoint is JWT-protected, but not conversation-authorized.

Impact:
- User enumeration and group membership disclosure.

Severity: High

---

### 2.3 High: Pin/unpin authorization mismatch (comment says restricted, code allows member)

Reconcile status (2026-03-19): Fixed.

Evidence:
- backend/node-services/apps/message-service/src/message/message.service.ts
  - pinMessage(): comment says "Requires admin/owner or allowMemberPin"
  - actual code only verifies assertMember(), then allows pin.
  - unpinMessage() has same pattern.

Current behavior:
- Any member can pin/unpin regardless of group setting/role.

Impact:
- Integrity and governance violation in group content moderation.

Severity: High

---

### 2.4 High: Recall broadcast uses client-supplied conversationId

Reconcile status (2026-03-19): Fixed.

Evidence:
- backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
  - handleRecallMessage() recalls by messageId,
  - then emits to room built from client payload conversationId.

Current behavior:
- Conversation for broadcast is not derived from the recalled message entity.

Attack scenario:
1. User recalls own message in conversation A.
2. Sends forged payload with conversationId of B.
3. Server emits message.recalled in B room.

Impact:
- Real-time data integrity corruption across conversations.

Severity: High

---

### 2.5 Medium: Overly permissive CORS in both services

Reconcile status (2026-03-19): Fixed by explicit configurable allow-list.

Evidence:
- backend/node-services/apps/message-service/src/main.ts
  - app.enableCors({ origin: '*', credentials: true, ... })
- backend/node-services/apps/message-service/src/gateway/chat.gateway.ts
  - WebSocketGateway cors: { origin: '*' }
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/config/CorsConfig.java
  - setAllowedOriginPatterns(List.of("*")) with allowCredentials(true)

Impact:
- Expanded cross-origin attack surface, hard to enforce trusted clients in production.

Severity: Medium

---

### 2.6 Medium: WS auth guard exists but is not applied to gateway handlers

Reconcile status (2026-03-19): Fixed.

Evidence:
- backend/node-services/apps/message-service/src/auth/ws-jwt.guard.ts exists.
- chat.gateway.ts does not use @UseGuards(WsJwtGuard).

Impact:
- Security logic remains manual and fragmented; future drift risk.

Severity: Medium

---

### 2.7 Medium: Missing anti-abuse throttling for high-volume realtime events

Reconcile status (2026-03-19): Open.

Evidence:
- No throttler/rate-limit enforcement found in message-service websocket event flow.

Impact:
- Event flooding risk (message.send/typing/read), especially under public tunnel or larger communities.

Severity: Medium

---

## 3) Convention Audit: "Max 100 participants"

Conclusion: Convention is currently inconsistent and not enforced end-to-end.

### 3.1 Backend schema/entity defaults are 1000, not 100 (historical, fixed)

Evidence:
- backend/node-services/apps/message-service/src/entities/conversation.entity.ts
  - memberLimit default: 1000
- backend/java-services/services/core-service/src/main/resources/db/migration/V8__messaging_tables.sql
  - member_limit INT DEFAULT 1000

Reconcile note (2026-03-19):
- Current runtime defaults are `memberLimit = 100`.
- V11 migration already normalized legacy defaults and existing rows from 1000 to 100.

### 3.2 Create-group DTO allows very large initial member list

Evidence:
- backend/node-services/apps/message-service/src/dto/create-group-conversation.dto.ts
  - @ArrayMaxSize(99)

Reconcile note (2026-03-19): fixed to align with 100-member default (99 invitees + creator).

Implication:
- Group can be created near 1000 members immediately.

### 3.3 Add-members logic enforces conversation.memberLimit only

Evidence:
- backend/node-services/apps/message-service/src/conversation/conversation.service.ts
  - check uses currentMemberCount + newMembers.length > conversation.memberLimit

Implication:
- If default/memberLimit is 1000, business convention 100 is bypassed.

Reconcile note (2026-03-19):
- Current default member limit is 100.
- `createGroup` now validates initial member list against effective member limit.

### 3.4 Frontend contract drift (defaults 100)

Evidence:
- frontend/mobile/lib/models/conversation_model.dart
  - memberLimit defaults to 100

Implication:
- UI expectation and backend policy are inconsistent.

### 3.5 No DB-level CHECK range for member_limit

Evidence:
- V8 migration sets default but no explicit CHECK for allowed range/tier policy.

Implication:
- Out-of-policy values may enter via non-service write paths.

---

## 4) If Introducing Paid Upgrade to Community 1000: Required Design Changes

This section assumes product requirement:
- Free/basic group: max 100 members.
- Paid community tier: max 1000 members.

### 4.1 Domain model and entitlement

Need to add:
- Subscription/plan/entitlement model (owner-level or conversation-level).
- Policy resolver: effectiveMemberLimit = f(plan, status, product rules).
- Lifecycle states: active, grace, expired, suspended.

Why:
- memberLimit cannot remain a static default if plan-driven.

### 4.2 Data model

Recommended additions:
- conversation_plan or owner_subscription tables.
- plan history/audit table.
- optional quota ledger for member slots and paid add-ons.

Also required:
- migration to normalize existing conversation.member_limit values to policy.

### 4.3 Service-layer rule engine

Must update flows:
- createGroup(): decide default limit by entitlement.
- addMembers(): enforce limit by computed policy, not hardcoded/default column.
- downgrade handling: block new adds, preserve existing members, grace strategy.

Concurrency requirement:
- Ensure limit checks are race-safe under concurrent add operations.

### 4.4 API contract and error semantics

Need new APIs:
- upgrade/downgrade plan endpoints.
- entitlement/quota read endpoints.

Need stable error codes:
- PAYMENT_REQUIRED
- PLAN_EXPIRED
- MEMBER_LIMIT_EXCEEDED
- ENTITLEMENT_MISSING

### 4.5 Security prerequisites before scaling to 1000

Must fix first:
- WS join authorization.
- members endpoint authorization.
- recall room integrity.
- pin/unpin role enforcement.

Reason:
- Scaling vulnerable flows multiplies blast radius.

### 4.6 Performance and realtime architecture

For 1000-member communities:
- Optimize membership checks in bulk (avoid per-user query loops).
- Consider fanout strategy tuning (segmented rooms/event filtering for noisy events).
- Add event rate limits and abuse controls.
- Add load tests for 100/300/500/1000 members (REST + WS + DB + Redis hot keys).

### 4.7 Product moderation and operations

Community tier should include:
- stronger role model (owner/admin/moderator).
- anti-spam/mute/ban/report tooling.
- operational observability (abuse, flood, delivery anomaly, queue lag).

---

## 5) VNALO vs Zalo (Latest Public Info) - Practical Comparison

Important note:
- Comparison below is based on public pages fetched on 2026-03-17.
- Public consumer-app internals (exact algorithmic/infra details) are not fully disclosed; only officially published information is used.

### 5.1 Public scale and maturity signals

Zalo public statements indicate:
- 79M+ monthly users and about 2B+ messages/day (from zalo.me product pages, 2025 figures shown publicly).
- Dedicated security reporting program and Hall of Fame (zalo.me/security.html).
- Mature developer/business ecosystems (developers.zalo.me, zalo.solutions).

VNALO current state:
- Test suites pass locally with strong functional coverage.
- Security controls still have several high-impact authz and realtime integrity gaps.
- Product and policy layer (plan/quota) not yet modeled.

### 5.2 Security posture comparison

Zalo public posture:
- Formal vulnerability disclosure channel (security@zalo.me), defined scope/out-of-scope, recognition program.

VNALO current posture:
- No formal VDP workflow found in-system.
- Key access control defects remain in realtime and membership flows.

Gap summary:
- VNALO should establish both technical controls and governance controls (process/security policy).

### 5.3 Monetization and group-tier capability comparison

Zalo official business pricing pages publicly expose:
- OA service tiers and quota-based capabilities.
- Group management feature (GMF) with packages including GMF-10, GMF-50, GMF-100, GMF-1000 and corresponding monthly maintenance pricing.

VNALO current state:
- Has member_limit field and basic invite controls.
- Lacks subscription/entitlement engine to support paid tier transitions safely.
- Lacks clear billing-linked error model and downgrade behavior.

Gap summary:
- Data model foundation exists, but monetization architecture is incomplete.

### 5.4 Developer ecosystem comparison

Zalo:
- Public developer portal, docs/changelog/community, OA APIs and business messaging APIs.

VNALO:
- Internal service APIs available, but no mature external developer program footprint yet.

Gap summary:
- To emulate Zalo-like extensibility, VNALO needs API governance, versioning, docs lifecycle, rate policies, partner onboarding.

---

## 6) Priority Risk List (Action-Ordered)

1. Block unauthorized WS room joins (Critical).
2. Enforce membership check on GET conversation members (High).
3. Fix pin/unpin permission enforcement (High).
4. Emit recall events using message-owned conversation ID only (High).
5. Tighten CORS for production origins and protocols (Medium).
6. Add WS/REST abuse throttling and protection policies (Medium).
7. Unify participant-limit policy (100 baseline) across DB/entity/DTO/service/frontend.
8. Design and implement entitlement-driven paid community model before enabling 1000-member product tier.

---

## 7) Source References (Public, fetched 2026-03-17)

- https://zalo.me/
- https://zalo.me/vi/product/zalo/
- https://zalo.me/security.html
- https://zalo.me/legal.html
- https://developers.zalo.me/
- https://oa.zalo.me/home
- https://zalo.solutions/oa/pricing
- https://zalo.solutions/business-message

(When policy or pricing may change over time, always re-check these pages before final product/business decisions.)
