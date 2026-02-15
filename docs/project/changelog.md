# Changelog

All notable changes to the VNALO project.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

---

## [Unreleased]

_No unreleased changes._

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
