# Final Project Report Context - VNALO

> Purpose: This file is the clean source-of-truth brief for generating the final course project report. Use it together with `docs/project/final-report-outline.md` and the referenced technical documents. Avoid relying on older legacy docs that contain mojibake or outdated schema notes unless this context explicitly points to them.

## 1. Project Identity

- Project name: VNALO - real-time OTT messaging and collaboration system.
- Project type: course project / graduation-style software engineering report.
- Main goal: design, implement, and deploy a modern messaging platform inspired by OTT chat systems, with web, mobile, realtime communication, AI assistant, admin monitoring, privacy/legal pages, and production-style deployment.
- Target users:
  - end users who chat, call, create groups, manage contacts, and use social/story features;
  - administrators who monitor system behavior and manage monitoring access;
  - operators/developers who deploy and maintain services on Docker/EC2.
- Current main report branch: `nguyenvu` for web/backend/docs/admin/security/AI web changes.
- Mobile AI feature branch: `ai-mobile-assistant` for mobile assistant-specific improvements.

## 2. Recommended Reading Order for Report Generation

1. `README.md` and `README.vi.md` for project overview.
2. `docs/README.md` for documentation index.
3. `docs/project/final-report-outline.md` for report structure.
4. `docs/system/architecture.md` for system architecture.
5. `docs/sdd/layer-0/ARCHITECTURE_BLUEPRINT.md` for high-level architecture decisions.
6. `docs/sdd/layer-2/MODULE_SPEC_CHAT.md` and `docs/sdd/layer-2/MODULE_SPEC_REALTIME_SYNC.md` for chat/realtime modules.
7. `docs/sdd/layer-2/MODULE_SPEC_AI_ASSISTANT.md` and `docs/ai-agent/*` for AI assistant and agent runtime.
8. `docs/sdd/layer-3/GLOBAL_DATABASE_ERD.md` for database/ERD reference.
9. `docs/admin-monitoring/README.md` and `docs/privacy/data-collection-map.md` for admin monitoring and data policy.
10. `docker/README-deploy.md`, `docs/deploy/EC2_SETUP.md`, and `docs/ai-agent/deployment-runbook.md` for deployment.

## 3. Problem Context

Real-time OTT messaging systems require more than basic request-response APIs. The platform must handle realtime delivery, presence, multi-device synchronization, media exchange, group management, notification delivery, access control, and operational monitoring. VNALO addresses this as a distributed system with multiple services and clients.

The project demonstrates practical application of:

- realtime communication with WebSocket/Socket.IO;
- REST APIs for account, profile, social graph, media, notification, and administration;
- PostgreSQL for durable domain data;
- Redis for cache, session-related state, presence, and rate limit support;
- Kafka/RabbitMQ-style asynchronous pipelines where applicable;
- Docker Compose deployment on EC2;
- AI assistant integration using Gemini/Ollama/fallback strategies;
- role-based access control for admin monitoring;
- privacy/legal documentation and data collection boundaries.

## 4. Functional Scope

### 4.1 Authentication and Account

- Register and login with phone/password flows.
- QR login flow for web sign-in approval.
- Configurable web QR restriction policy through environment configuration.
- Password change and session handling.
- Legal consent tracking for Terms and Privacy acceptance.
- Face authentication exists as an integration scope; biometric data must be treated as sensitive and never sent to RAG or analytics.

### 4.2 Contacts and Social Graph

- User profile management.
- Contact search and friend request lifecycle.
- Friendship management.
- Block list to prevent unwanted interaction.
- Contact sync metadata for matching contacts.

### 4.3 Messaging

- Direct 1:1 conversations.
- Group conversations with roles and group permissions.
- Text, media, file, sticker, emoji, and system messages where supported.
- Message status, receipts, seen state, reactions, reply, recall, pin/unpin.
- Conversation inbox metadata: unread count, pin/mute/favorite, last message sequence, wallpaper/call notification settings.
- Group creation requires at least two selected members besides the creator, so an initial group has at least three users.

### 4.4 Realtime and Calling

- Socket.IO realtime gateway for message/event delivery.
- Presence, typing, inbox update, call signaling, and group events.
- WebRTC-based voice/video call support with ringing/connecting/ended/missed states.
- Incoming call banner should be available globally while the app tab is open, not only inside a chat screen.

### 4.5 Media and Content

- Media upload/download metadata.
- Image/video/file/sticker categories.
- Social feed/story/content modules are represented by content-service domain entities and migrations.

### 4.6 AI Assistant and Agent Runtime

- VNALO AI Assistant is implemented as a guarded assistant, not an autonomous actor.
- On web, AI is embedded as a synthetic 1:1 conversation: `vnalo-ai-assistant`.
- Synthetic AI user id: `__vnalo_ai__`; normal user APIs must not fetch this pseudo user.
- The AI service may return an `actionCommand`, but clients must validate schema, resolve entities, check preconditions, request confirmation, execute through safe APIs, and report success/failure only after execution.
- Important action families:
  - open profile/chat;
  - compose message;
  - start call;
  - send friend request;
  - create group;
  - pin/unpin/recall message;
  - group admin actions such as add/remove member, transfer owner, leave/disband group.
- RAG is planned/defined as a knowledge layer for product help and rules. It must not grant permissions or execute actions.
- Raw prompts, private messages, face embeddings, tokens, and secrets must not be indexed into RAG.

### 4.7 Admin Monitoring and Privacy

- Admin dashboard is protected by RBAC.
- Admin entry in settings is visible only to users with monitoring access.
- Admin monitoring focuses on aggregate/product-operation metrics such as active users, sessions, top features, errors, AI success rate, face-auth lifecycle metadata, and export audit.
- Normal users must not see or access admin dashboard navigation.
- Privacy documentation must state which data categories are collected and which sensitive data is excluded.

## 5. Architecture Summary

VNALO follows a microservices-style architecture with a mixed Java/Node backend and separate web/mobile clients.

### 5.1 Client Layer

- Web frontend: React/TypeScript/Vite.
- Mobile frontend: Flutter/Dart.
- Both clients call REST APIs and subscribe to realtime events.
- Web has an embedded assistant conversation and admin monitoring dashboard.

### 5.2 Backend Services

- Core service: Java/Spring Boot; owns account, auth, user profile, social graph, privacy/legal consent, admin RBAC, AI settings/history linkage.
- Message service: Node.js/NestJS; owns conversation, membership, inbox, messages, receipts, reactions, pinned messages.
- Realtime gateway: Node.js/Socket.IO; owns realtime event fan-out and call/chat event delivery.
- Media service: Java/Spring Boot; owns media metadata and media-related lifecycle.
- Notification service: Java/Spring Boot; owns notification and notification device state.
- AI service: Java/Spring Boot; owns assistant chat, Gemini/Ollama provider flow, action command parsing/sanitization, and AI provider health.
- Content service: Java/Spring Boot; owns posts, comments, likes, stories, story views/reactions.
- Analytics service: Java/Spring Boot; owns analytics event/daily metric/backfill data model and can be used for monitoring dashboards.
- Moderation service: Java/Spring Boot; owns reports, moderation cases, actions, appeals, and audit logs.

### 5.3 Infrastructure

- PostgreSQL: primary durable relational database.
- Redis: cache/session/presence/rate limit style state.
- Kafka/RabbitMQ/Zookeeper: asynchronous/event-driven infrastructure where enabled by Docker deployment.
- Nginx/frontend container: public routing/proxy for web and API paths.
- Docker Compose: local/EC2 orchestration.
- EC2: deployment target for integration testing and production-like demo.

## 6. Database and Data Service Context

### 6.1 Database Strategy

The current runtime uses PostgreSQL as the primary durable datastore. Redis is used as a fast in-memory supporting store for cache, realtime/presence/session/rate-limit style data. Database schema evolution for Java services is generally managed with Flyway migrations. The Node message service uses TypeORM entities for conversation and message data.

Use `docs/sdd/layer-3/GLOBAL_DATABASE_ERD.md` as the most useful ERD/report reference. Treat `docs/system/database-schema.md` as a legacy artifact because it explicitly warns that parts may be stale and contains mojibake.

### 6.2 Main Database Domains

#### Core/Auth/User/Social Domain

Representative entities:

- `AuthAccount`: account identity, phone/email/password/session-related account status.
- `AuthRefreshToken`: refresh token lifecycle and device binding.
- `AuthOtp`: OTP verification state.
- `AuthQrLoginSession`: QR login approval session.
- `AuthSessionAudit`: login/session audit events.
- `AuthLegalConsent`: accepted Terms/Privacy version and consent timestamp.
- `UserProfile`: display name, avatar, and public profile metadata.
- `UserSetting`: language, theme, sync policy, web restriction mode.
- `UserPrivacySetting`: search, messaging, calling, and friend request privacy options.
- `FriendRequest`: friend request lifecycle.
- `Friendship`: accepted friend relation.
- `BlockList`: blocked relation and interaction restrictions.
- `ContactSync`: uploaded/matched contact metadata.
- `UserMascotSettings` and `AiChatHistory`: assistant personalization/history linkage.

Source examples:

- `backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/auth/`
- `backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/user/`
- `backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/`
- `backend/java-services/services/core-service/src/main/resources/db/migration/`

#### Message/Conversation Domain

Representative entities:

- `Conversation`: direct/group conversation aggregate and group-level settings.
- `ConversationMember`: user membership, role, nickname, last read sequence.
- `ConversationDirectMap`: unique direct-conversation lookup for two users.
- `ConversationJoinRequest`: request-to-join group state.
- `ConversationInbox`: per-user inbox metadata, unread count, mute/pin/favorite settings.
- `Message`: message aggregate with type/status/server sequence/reply relation.
- `MessageReceipt`: delivered/seen/read state per user/message.
- `MessageReaction`: emoji reaction by user/message.
- `PinnedMessage`: pinned message in a conversation.

Source examples:

- `backend/node-services/apps/message-service/src/entities/`
- `backend/node-services/apps/message-service/src/conversation/`
- `backend/node-services/apps/message-service/src/message/`

#### Content/Social Feed Domain

Representative entities:

- `Post`, `Comment`, `PostLike`.
- `Story`, `StoryView`, `StoryReaction`.

Source examples:

- `backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/model/entity/`
- `backend/java-services/services/content-service/src/main/resources/db/migration/`

#### Media Domain

Media service migrations define media schema for upload metadata, file category, and media lifecycle. Use this domain to describe image/video/file/sticker storage metadata rather than raw object storage internals.

Source examples:

- `backend/java-services/services/media-service/src/main/resources/db/migration/`

#### Notification Domain

Representative entities:

- `Notification`: notification content/state/event metadata.
- `NotificationDevice`: device token and delivery target metadata.

Source examples:

- `backend/java-services/services/notification-service/src/main/java/iuh/cnm/vnalo/notification_service/model/entity/`

#### Analytics/Admin Monitoring Domain

Representative entities:

- `AnalyticsEvent`: raw/structured behavior event metadata.
- `AnalyticsDailyMetric`: daily aggregate metrics.
- `BackfillJob`: analytics aggregation/backfill job state.

Source examples:

- `backend/java-services/services/analytics-service/src/main/java/iuh/cnm/vnalo/analytics_service/model/entity/`
- `docs/admin-monitoring/README.md`
- `docs/privacy/data-collection-map.md`

#### Moderation Domain

Representative entities:

- `ModerationReport`, `ModerationCase`, `ModerationAction`, `ModerationAppeal`, `ModerationAuditLog`, `ModerationReportEvidence`, `ModerationAdminUser`.

Source examples:

- `backend/java-services/services/moderation-service/src/main/java/iuh/cnm/vnalo/moderation_service/model/entity/`

### 6.3 Key Relationship Summary for Report

- One account owns one primary user profile and user settings/privacy settings.
- Accounts participate in friendships, friend requests, blocks, and contact sync records.
- Conversations have many members and many messages.
- Direct conversations are constrained by `ConversationDirectMap` for O(1) lookup and duplicate prevention.
- Group conversations use `ConversationMember.role` and group settings for administration and permissions.
- Messages have receipts, reactions, optional reply links, and optional pinned-message records.
- Conversation inbox rows are per-user/per-conversation denormalized views for unread count, last message sequence, and UI preferences.
- AI assistant history/settings are linked to users but must not bypass privacy or action runtime guardrails.
- Analytics/admin monitoring data should be metadata/aggregate-first and must not store raw sensitive content.

## 7. Class Diagram and ERD Generation Commands

> These commands are intended for generating diagrams to include in the report. Run from repository root unless stated otherwise.

### 7.1 Generate Java Entity Class Diagram Skeleton

This command creates a Mermaid class diagram skeleton from Java entity class names. It is intentionally conservative: it produces class boxes from the actual entity files, then the report writer can add attributes/relationships from `GLOBAL_DATABASE_ERD.md`.

```powershell
New-Item -ItemType Directory -Force -Path docs/generated | Out-Null
@('classDiagram') | Set-Content docs/generated/java-entities-class-diagram.mmd
Get-ChildItem backend/java-services/services/*/src/main/java -Recurse -Filter *.java |
  Where-Object { $_.FullName -match "model\\entity" } |
  ForEach-Object {
    $className = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    "class $className" | Add-Content docs/generated/java-entities-class-diagram.mmd
  }
```

Render the Mermaid output to SVG:

```powershell
npx -y @mermaid-js/mermaid-cli -i docs/generated/java-entities-class-diagram.mmd -o docs/generated/java-entities-class-diagram.svg
```

Optional: also produce a source file list for agents/tools that enrich diagrams manually.

```powershell
Get-ChildItem backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity -Recurse -Filter *.java |
  Select-Object -ExpandProperty FullName > docs/generated/core-entities.txt

Get-ChildItem backend/java-services/services/*/src/main/java -Recurse -Filter *.java |
  Where-Object { $_.FullName -match "model\\entity" } |
  Select-Object -ExpandProperty FullName > docs/generated/java-service-entities.txt
```

### 7.2 Generate TypeScript Entity Listing for Message Service

```powershell
New-Item -ItemType Directory -Force -Path docs/generated | Out-Null
Get-ChildItem backend/node-services/apps/message-service/src/entities -Filter *.ts |
  Select-Object -ExpandProperty FullName > docs/generated/message-service-entities.txt
```

### 7.3 Generate Mermaid Class Diagram Skeleton from Entity File Names

PowerShell helper:

```powershell
New-Item -ItemType Directory -Force -Path docs/generated | Out-Null
@('classDiagram') | Set-Content docs/generated/message-service-class-diagram.mmd
Get-ChildItem backend/node-services/apps/message-service/src/entities -Filter *.ts |
  ForEach-Object {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $className = ($name -split '-') | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) } | Join-String -Separator ''
    "class $className" | Add-Content docs/generated/message-service-class-diagram.mmd
  }
```

Then render with Mermaid CLI:

```powershell
npx -y @mermaid-js/mermaid-cli -i docs/generated/message-service-class-diagram.mmd -o docs/generated/message-service-class-diagram.svg
```

### 7.4 Generate ERD from Existing Mermaid ERD

If `docs/sdd/layer-3/GLOBAL_DATABASE_ERD.md` contains Mermaid `erDiagram` blocks, extract or copy the block into `docs/generated/global-erd.mmd`, then render:

```powershell
New-Item -ItemType Directory -Force -Path docs/generated | Out-Null
npx -y @mermaid-js/mermaid-cli -i docs/generated/global-erd.mmd -o docs/generated/global-erd.svg
```

### 7.5 Generate PlantUML from PostgreSQL Schema with SchemaSpy

This is useful after services are deployed and PostgreSQL is accessible.

```powershell
New-Item -ItemType Directory -Force -Path docs/generated/schemaspy | Out-Null
java -jar schemaspy.jar `
  -t pgsql `
  -host localhost `
  -port 5432 `
  -db vnalo_core `
  -u postgres `
  -p postgres `
  -s public `
  -o docs/generated/schemaspy
```

Adjust database name/user/password to match `.env`. Do not commit generated diagrams containing sensitive connection details.

## 8. Suggested Report Claims

Use safe wording:

- The system applies a microservices-oriented architecture with separate services for core identity/social features, messaging, realtime gateway, media, notification, AI, content, analytics, and moderation.
- PostgreSQL is the main durable database; Redis supports fast ephemeral state.
- Message and conversation data are modeled separately to support direct chat, group chat, per-user inbox metadata, receipts, reactions, and pinned messages.
- AI assistant actions are guarded by schema validation, entity resolution, preconditions, confirmation, and backend validation.
- Admin monitoring is RBAC-protected and should focus on aggregate metadata rather than raw private content.

Avoid unsafe or unverified claims:

- Do not claim desktop app support unless a desktop client is actually present.
- Do not claim full RAG implementation unless the RAG index/retrieval pipeline is implemented and deployed.
- Do not claim raw behavioral analytics captures every user action unless ingestion is verified end-to-end.
- Do not claim face embeddings are used in analytics or RAG.
- Do not claim all admin monitoring metrics are live if some are summary/proxy values.

## 9. Known Limitations for Report

- Some legacy docs contain mojibake and should not be copied directly.
- Java Maven tests may depend on CI/local Maven availability.
- AI action runtime is guarded, but not every possible action has a full automatic executor on every surface.
- RAG is documented as a policy/architecture layer; verify implementation status before writing it as fully deployed.
- Analytics/admin monitoring should be described according to current service readiness and deployment state.

## 10. Suggested Conclusion Points

- VNALO demonstrates a practical full-stack realtime messaging platform.
- The project integrates web, mobile, realtime backend, durable database design, AI assistant, and admin/privacy concerns.
- The system is suitable for demonstrating modern distributed application architecture and software engineering practices.
- Future work should focus on deeper analytics ingestion, full RAG indexing, expanded AI action executors, CI/CD automation, performance optimization, and security hardening.

