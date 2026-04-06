# Team Assignment

> 4 backend developers, ownership map aligned with current repository services

---

## Team Overview

| Member | Role | Services | Complexity |
|--------|------|----------|-----------|
| **Dev 1** (Leader) | Tech Lead, Critical Path | core-service, message-service | 🔴 Very High |
| **Dev 2** | Real-time & Infrastructure | realtime-gateway, media-service | 🔴 High |
| **Dev 3** | User Features | content-service, notification-service | 🟡 Medium |
| **Dev 4** | Admin & Support | moderation-service, analytics-service, ai-service | 🔴 High |

---

## Dev 1 — Core & Messaging (Critical Path)

### core-service (Port 8081 — Spring Boot)
- Auth Module: Register, Login, JWT, OTP
- User Module: Profile CRUD, Avatar, Settings
- Social Module: Friends, Block, Contact Sync
- QR Module: Generate/Scan QR

### message-service (Port 3000 default — NestJS)
- Conversation: Create 1:1/Group, Member Management
- Message: Send/Receive, History, Search, Edit/Delete
- Metadata: Reactions, Read Receipts, Pins
- WebSocket: Real-time messaging, Typing, Presence

---

## Dev 2 — Realtime & Media

### realtime-gateway (Port 8085 — Node.js)
- WebSocket connection management, JWT auth
- Presence: online/offline, last seen, typing
- Broadcasting: RabbitMQ consumer, room management

### media-service (Port 8083 — Spring Boot)
- Upload: presigned URL, Cloudinary integration
- Processing: thumbnails, compression, variants
- Stickers: packs, install/uninstall

---

## Dev 3 — Content & Notifications

### content-service (Spring Boot)
- Story: CRUD, views, reactions, privacy
- Timeline: posts, comments, likes, sharing

### notification-service (Spring Boot)
- Push: FCM integration, device tokens
- Events: message, friend request, mentions

---

## Dev 4 — Admin Tools

### moderation-service (Spring Boot)
- Reports: submit, review, actions
- Decision: remove content, block users

### analytics-service (Spring Boot)
- Logging: activity, API requests, errors
- Stats: DAU, message count, storage

### ai-service (Spring Boot, Java 21)
- Chatbots: Answer user queries, provide support, guide usage
- Knowledge bounds: Limit answers to permitted scope (FAQs, System rules)

---

## Critical Path

```
Week 1-2: core-service (Auth + User + Social)
     ↓
Week 3:   message-service (Conversations + Messages)
     ↓
Week 4:   realtime-gateway (WebSocket scaling)
```

## Timeline

| Week | Dev 1 | Dev 2 | Dev 3 | Dev 4 |
|------|-------|-------|-------|-------|
| 1 | Setup + Auth | Docker/Redis | DB Schema | CI/CD |
| 2 | User + Social | Media Upload | Story | Analytics |
| 3 | Messaging | Realtime GW | Timeline | Moderation |
| 4 | Search, QR | Stickers | Notifications | AI Chatbot |
| 5 | Testing | Load Testing | API Docs | Monitoring |
| 6 | Deployment | Infrastructure | Mobile Test | Documentation |
