# Changelog

All notable changes to the VNALO project.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

---

## [Unreleased]

_No unreleased changes._

---

## [2026-03-15] — V10 Migration, Mobile Fixes, Docs Cleanup

### Added
- **V10 migration**: Schema hardening — idempotent guards for V9 column renames, uniqueness constraints (`uq_msg_conv_seq`, `uq_msg_sender_client_id`), FK integrity for inbox/member → user_profile, performance indexes
- **Mobile implementation guides**: Parts 1–4 now fully self-contained (~3,730 lines total). Restored 5 placeholder sections with complete code (services, providers, screens, navigation, testing)

### Fixed
- **Mobile `main.dart`**: Added `ChangeNotifierProvider<ThemeProvider>` wrapper; removed leftover counter template code
- **Mobile `theme_provider.dart`**: Fixed swapped dark/light labels
- **Mobile `app_typography.dart`**: Removed references to non-existent `AppColors.textPrimary/textSecondary`

### Removed
- **Mobile `app_color_light.dart`**: Deleted empty 0-byte duplicate file
- **Docs cleanup**: Removed `VNALO_Complete_Database_Schema.md` (duplicate), `VNALO_Project_Docs.md` (superseded), `SYSTEM_TEST_REPORT.md` (superseded by newer reports), empty `architecture/` directory

### Changed
- **`docs/system/architecture.md`**: Updated migration ref V1–V9 → V1–V10
- **`docs/project/status.md`**: Added V10 migration, mobile frontend section, updated test counts
- **`docs/README.md`**: Updated structure table to match actual files

---

## [2026-02-16] — Documentation Audit & Corrections

### Fixed
- **README.md**: Complete rewrite — fixed 30+ discrepancies between documentation and actual project
  - messaging-service: "Spring Boot" → NestJS 11 (TypeScript)
  - Frontend: "React Native 0.76+" → Flutter 3.x / Dart 3.x
  - WebSocket: "Netty 4.1" → Socket.IO via NestJS
  - Database: Removed non-existent Cassandra/ScyllaDB references → PostgreSQL only
  - Removed non-existent services: AI, Spring Cloud Gateway, Elasticsearch
  - Kafka: "Core event streaming" → optional Docker profile only
  - Version badges: Spring Boot 3.2→3.4, NestJS 10→11, PostgreSQL 15→16
  - Status: messaging-service "🚧 Next" → ✅ Complete
  - Environment variables: Removed non-existent KAFKA/S3/GEMINI/OLLAMA vars
  - Database name: "cnm_zalo" → "vnalo_core"
  - Documentation links: Updated from deleted files to new `docs/` structure
  - Architecture diagrams: Replaced incorrect Netty/Kafka/Cassandra flow with accurate Socket.IO/PostgreSQL flow
- **api-reference.md**: Corrected WebSocket events to match actual ChatGateway implementation
  - `send_message` → `message.send`, `new_message` → `message.received`, etc.
  - Added connection flow documentation and namespace info (`/chat`)
- **status.md**: Fixed core-service test count from "~20" to 44 (5 suites)
- **README.md**: Added missing content-service, moderation-service, analytics-service to service tables
- **README.md**: Fixed team member responsibilities to match team-assignment.md

---

## [2026-02-15] — QR Module, Contact Sync, Message Search

### Added
- **QR Module** (core-service): `GET /qr/generate`, `POST /qr/scan`, `POST /qr/scan/add-friend` — stateless token generation with SHA-256 + nonce
- **Contact Sync API** (core-service): `POST /contacts/sync`, `GET /contacts/matched`, `GET /contacts`, `DELETE /contacts` — batch phone sync with +84 normalization
- **Message Search** (message-service): `GET /conversations/:id/messages/search` — ILIKE keyword search + messageType filter
- `ContactSyncRepository`, `ContactSyncService`, `ContactSyncController`
- `QrService`, `QrController`
- `SearchMessagesDto`

---

## [2026-02-14] — Critical Bug Fixes + Schema Alignment

### Fixed
- **BUG-1**: Login failed-attempt counter not incrementing
- **BUG-2**: Account locking not triggering after 5 failed attempts
- **BUG-3**: Login `identifier` only supported phone
- **BUG-4**: Token refresh not validating device context
- **BUG-5**: OTP logging exposed codes in production logs
- **BUG-6**: User enumeration via auth error messages
- **BUG-7**: Refresh token not hashed before storage
- **BUG-8**: Missing password validation on register

### Added
- V9 migration: `message_reaction`, `pinned_message`, `message_receipt` tables aligned with TypeORM entities
- message-service unit tests (18 tests across 2 suites)

---

## [2026-02-13] — Complete Message Service

### Added
- Full message-service implementation (NestJS 11 + TypeORM + Socket.IO)
- Conversation module: create direct/group, member management
- Message module: send, edit, recall, reactions, pins, read receipts
- Inbox module: CQRS denormalized inbox with unread counts
- WebSocket gateway: real-time messaging, typing indicators, presence
- V8 migration: conversation, conversation_member, conversation_direct_map, message, conversation_inbox tables

---

## [2026-02-12] — Node Services Restructure

### Changed
- Restructured `node-services` from multi-app workspace to flat NestJS monorepo
- Simplified build and test configuration

---

## [2026-02-05] — Core Service v2.2

### Added
- FCM test controller for push notification testing
- FCM notification service integration
- OTP test mode (skip OTP in development)

### Changed
- Simplified to dev/prod profiles only (Docker required)
- Firebase Admin SDK 9.7.0 dependency

---

## [2026-01-29] — Core Service Foundation

### Added
- Auth module: Register, Login, JWT (HS512), OTP with rate limiting
- User module: Profile CRUD, avatar, privacy settings
- Social module: Friends (request/accept/decline), Block (granular options)
- Security: Spring Security 6, JWT filter chain
- Database: V1–V7 Flyway migrations (auth, user, social tables)
- OpenAPI/Swagger documentation
- Unit tests for AuthService, UserService, FriendService, BlockService
