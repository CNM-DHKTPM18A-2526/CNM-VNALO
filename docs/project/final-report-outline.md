# Final Project Report Outline - VNALO

> Purpose: This outline is the recommended structure for generating the final submitted report. Use `docs/project/final-report-context.md` as the clean factual source.

## Cover Page

- University / faculty / department.
- Course name.
- Project title: Xây dựng hệ thống OTT nhắn tin thời gian thực VNALO.
- Team members and student IDs.
- Instructor.
- Semester and year.

## Acknowledgement

Briefly thank instructor, team members, and supporting resources.

## Abstract

Summarize in 200-300 words:

- problem context;
- project goal;
- architecture;
- core features;
- AI assistant/admin monitoring/privacy highlights;
- deployment and results.

## Table of Contents

Generate automatically if using Word/Markdown tooling.

## List of Figures and Tables

Recommended figures:

- Overall system architecture.
- Backend microservices diagram.
- Database ERD.
- Message service class diagram.
- AI assistant runtime pipeline.
- Deployment architecture on EC2/Docker.
- Key UI screenshots.

Recommended tables:

- Functional requirement table.
- Non-functional requirement table.
- Service responsibility table.
- Database entity/domain table.
- API/module table.
- Test result table.

# CHAPTER 1. INTRODUCTION

## 1.1 Project Background

Discuss:

- OTT communication platforms and realtime messaging demand.
- Need for realtime delivery, presence, multi-device sync, media, calling, and privacy/security.
- Why a VNALO-like system is technically meaningful for a course project.

Avoid copying the current pasted chapter directly because it has mojibake. Rewrite it in clean Vietnamese.

## 1.2 Motivation

Explain:

- modern chat systems require distributed architecture, realtime gateway, durable storage, and async processing;
- AI assistant and admin monitoring are increasingly important for user support and operations;
- the project is an opportunity to apply Java/Spring Boot, Node/NestJS, React, Flutter, PostgreSQL, Redis, Docker, and AI integration.

## 1.3 Project Objectives

### 1.3.1 General Objective

Build a realtime OTT messaging platform with web/mobile clients, backend services, database persistence, realtime events, AI assistant, and production-style deployment.

### 1.3.2 Specific Objectives

- Implement authentication, account, profile, contacts, friend requests, and block list.
- Implement direct chat, group chat, messages, receipts, reactions, pinned messages, and inbox state.
- Implement realtime synchronization through Socket.IO/WebSocket gateway.
- Support media/calling-related functionality.
- Integrate AI assistant with guarded action runtime.
- Provide admin monitoring with RBAC.
- Provide terms/privacy data documentation.
- Deploy with Docker Compose on EC2.

## 1.4 Scope

### 1.4.1 Functional Scope

Summarize functions only. Move detailed requirement tables to Chapter 2.

- Authentication and account management.
- Contacts and social graph.
- Messaging and group chat.
- Media and calling.
- AI assistant.
- Admin monitoring.
- Privacy/legal pages.

### 1.4.2 Technical Scope

- Web frontend: React/TypeScript/Vite.
- Mobile frontend: Flutter/Dart.
- Backend: Java/Spring Boot and Node.js/NestJS.
- Database: PostgreSQL and Redis.
- Realtime: Socket.IO/WebSocket.
- Deployment: Docker Compose and EC2.
- AI: Gemini/Ollama/fallback flow where configured.

### 1.4.3 Out of Scope or Limited Scope

- Desktop client if not implemented.
- Full production-grade RAG if only policy/docs are implemented.
- Full enterprise analytics if ingestion is not fully deployed.
- Unlimited scale production operation.

## 1.5 Methodology

- Requirement analysis.
- Modular service design.
- Database and API design.
- Iterative frontend/backend implementation.
- Integration testing.
- Deployment verification.
- Documentation and audit.

## 1.6 Main Contributions

- End-to-end realtime messaging platform.
- Hybrid Java/Node microservice architecture.
- Guarded AI assistant runtime with action preconditions.
- RBAC-protected admin monitoring.
- Privacy/data collection documentation.
- Docker/EC2 deployable system.

## 1.7 Report Structure

Briefly describe each chapter.

# CHAPTER 2. THEORETICAL BACKGROUND AND TECHNOLOGY STACK

## 2.1 OTT Messaging Systems

Explain direct chat, group chat, realtime synchronization, presence, receipts, and media/calling.

## 2.2 Microservices Architecture

Discuss service separation, scalability, deployment, and trade-offs.

## 2.3 Realtime Communication

Discuss WebSocket/Socket.IO and WebRTC calling concept.

## 2.4 Database and Caching

Discuss PostgreSQL as durable relational storage and Redis as cache/ephemeral state.

## 2.5 AI Assistant and Agent Runtime

Explain LLM integration, action command, guardrails, confirmation, and RAG policy.

## 2.6 Security, Privacy, and RBAC

Explain JWT/session, permissions, admin RBAC, privacy/data collection.

# CHAPTER 3. REQUIREMENT ANALYSIS

## 3.1 Stakeholders

- End user.
- Group admin/member.
- System administrator.
- Operator/developer.

## 3.2 Functional Requirements

Recommended table columns:

- ID.
- Feature.
- Description.
- Actor.
- Priority.
- Current status.

Feature groups:

- Authentication/account.
- Contacts/friendship/blocking.
- Direct messaging.
- Group messaging.
- Media and calling.
- Social/content.
- Notification.
- AI assistant.
- Admin monitoring.
- Privacy/legal.

## 3.3 Non-functional Requirements

- Realtime responsiveness.
- Reliability.
- Security.
- Privacy.
- Maintainability.
- Deployability.
- Observability.

## 3.4 Use Cases

Recommended diagrams/use cases:

- Register/login.
- Send direct message.
- Create group.
- Start call.
- Use AI assistant action.
- View admin monitoring dashboard.

# CHAPTER 4. SYSTEM DESIGN

## 4.1 Overall Architecture

Include architecture diagram and service responsibility table.

## 4.2 Service Design

### 4.2.1 Core Service

Account, auth, profile, social graph, privacy/legal consent, admin RBAC, AI settings/history linkage.

### 4.2.2 Message Service

Conversation, members, inbox, messages, receipts, reactions, pinned messages.

### 4.2.3 Realtime Gateway

Socket.IO event fan-out, chat events, presence, call signaling.

### 4.2.4 AI Service

Gemini/Ollama provider flow, key rotation, action command sanitization, safe replies, health endpoint.

### 4.2.5 Media/Notification/Content/Analytics/Moderation Services

Summarize responsibilities from `final-report-context.md`.

## 4.3 Database Design

Use content from `final-report-context.md` section 6.

### 4.3.1 Database Technology

- PostgreSQL for durable relational data.
- Redis for cache/ephemeral state.
- Flyway migrations for Java services.
- TypeORM entities for Node message service.

### 4.3.2 Main Entity Groups

- Auth/account/user/social.
- Conversation/message.
- Media.
- Content/story.
- Notification.
- Analytics/admin monitoring.
- Moderation.

### 4.3.3 Key Relationships

- Account to profile/settings/privacy.
- Account to friendships/friend requests/block list.
- Conversation to members/messages/inbox.
- Message to receipts/reactions/pins.
- Analytics events to aggregate metrics.

### 4.3.4 Diagrams

Include:

- ERD from `docs/sdd/layer-3/GLOBAL_DATABASE_ERD.md`.
- Class diagram for core Java entities if needed.
- Class diagram for message-service TypeORM entities.

## 4.4 API Design

Summarize REST APIs and Socket.IO events. Reference `docs/system/api-reference.md` and `docs/sdd/layer-3/API_REFERENCE_CATALOG.md`.

## 4.5 AI Assistant Runtime Design

Use:

- `docs/ai-agent/runtime-policy.md`.
- `docs/ai-agent/action-contract.md`.
- `docs/ai-agent/precondition-matrix.md`.

Pipeline:

```text
User prompt -> AI response/action proposal -> schema validation -> entity resolution -> precondition check -> confirmation -> executor -> feedback/audit
```

## 4.6 Security and Privacy Design

Discuss:

- JWT/session.
- Web QR policy.
- RBAC admin monitoring.
- Terms/privacy consent.
- Sensitive data exclusions for analytics/RAG.

# CHAPTER 5. IMPLEMENTATION

## 5.1 Development Environment

List languages/frameworks/tools.

## 5.2 Backend Implementation

Explain service implementation by domain.

## 5.3 Frontend Web Implementation

Explain React layout, chat UI, AI assistant embedded conversation, admin dashboard, settings modal guard.

## 5.4 Mobile Implementation

Explain Flutter screens/providers and AI mobile parity if included.

## 5.5 Database Implementation

Explain migrations, entities, and key tables.

## 5.6 AI Assistant Implementation

Explain AI service, Gemini key rotation, action command validation, web/mobile runtime guard.

## 5.7 Deployment Implementation

Explain Docker Compose, Nginx, EC2, service healthcheck.

# CHAPTER 6. TESTING AND EVALUATION

## 6.1 Testing Strategy

- Unit tests.
- Integration tests.
- Build checks.
- Security audit.
- Manual UI/UX tests.
- EC2 health checks.

## 6.2 Test Results

Include table:

| Area | Command/Test | Result | Note |
| --- | --- | --- | --- |
| Web build | `npm run build` | Pass | large chunk warning only |
| Web audit | `npm audit --audit-level=low` | 0 vulnerabilities | local branch |
| Node build | `npm run build` | Pass | message/realtime workspace |
| Node audit | `npm audit --audit-level=low` | 0 vulnerabilities | local branch |
| AI service CI | `./mvnw -B test` | CI should pass after latest fix | Maven not available locally |
| EC2 health | `./deploy.sh --health` | fill after deploy | production-like check |

## 6.3 Evaluation

Evaluate:

- feature completeness;
- realtime behavior;
- AI assistant safety;
- admin monitoring access control;
- privacy/security posture;
- deployment readiness.

## 6.4 Known Issues and Limitations

Use context file section 9.

# CHAPTER 7. CONCLUSION AND FUTURE WORK

## 7.1 Conclusion

Summarize achieved system and learning outcomes.

## 7.2 Future Work

- Full RAG indexing pipeline.
- More AI action executors.
- Deeper analytics ingestion and dashboards.
- CI/CD automated EC2 deployment.
- Performance and load testing.
- More security hardening.
- Expanded face-auth production readiness.

# APPENDICES

## Appendix A. Deployment Commands

Use `docs/ai-agent/deployment-runbook.md` and `docker/README-deploy.md`.

## Appendix B. API References

Link to API docs.

## Appendix C. Database/Class Diagram Commands

Copy commands from `docs/project/final-report-context.md` section 7.

## Appendix D. Screenshots

Add screenshots for:

- login/register;
- chat list;
- direct chat;
- group chat;
- AI assistant chat;
- admin dashboard;
- settings modal;
- mobile screens if included.
