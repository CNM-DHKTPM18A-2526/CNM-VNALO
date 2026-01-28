# 📊 SUMMARY - Hệ Thống CNM Zalo Clone

> **Tổng quan chi tiết về kiến trúc, công nghệ và phân công cho dự án**

---

## 🎯 Tổng Quan Dự Án

### Thông Tin Cơ Bản
- **Tên dự án**: CNM Zalo Clone - Enterprise Messaging Platform
- **Loại hình**: OTT (Over-The-Top) Real-time Messaging System
- **Kiến trúc**: Microservices Architecture
- **Quy mô**: 16 Backend Services + 1 Realtime Gateway
- **Team size**: 4 thành viên
- **Timeline**: 8 tuần
- **Tech stack**: Java 21, Spring Boot 3, React Native 0.76+

### Mục Tiêu Hệ Thống
✅ Xây dựng ứng dụng nhắn tin thời gian thực giống Zalo  
✅ Hỗ trợ 1-1 chat, group chat, voice/video call  
✅ Tích hợp AI assistant (Gemini + Ollama)  
✅ Scalable architecture (100K+ concurrent connections)  
✅ Enterprise-grade security & performance  
✅ Production-ready deployment trên AWS/K8s  

---

## 🏗️ Kiến Trúc Hệ Thống

### Kiến Trúc Tổng Thể

```
┌────────────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                                    │
├────────────────────────────────────────────────────────────────────┤
│  📱 iOS App          📱 Android App          🌐 Web (Future)       │
│         React Native 0.76+ / TypeScript / NativeWind               │
└──────────────────┬─────────────────────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────────────────┐
│                     LOAD BALANCER LAYER                             │
├────────────────────────────────────────────────────────────────────┤
│  ⚖️ Application Load Balancer (REST)                               │
│  ⚖️ Network Load Balancer (WebSocket)                              │
└──────────────────┬─────────────────────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────────────────────┐
│                   KUBERNETES CLUSTER (EKS)                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐          │
│  │         🚪 API Gateway (Spring Cloud Gateway)         │          │
│  │              Rate Limiting, Auth, Routing             │          │
│  └────────────────────┬─────────────────────────────────┘          │
│                       │                                             │
│         ┌─────────────┼─────────────────────────┐                  │
│         ▼             ▼                         ▼                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Team 1   │  │ Team 2   │  │ Team 3   │  │ Team 4   │          │
│  │ Services │  │ Services │  │ Services │  │ Services │          │
│  │ (4)      │  │ (4)      │  │ (4)      │  │ (5)      │          │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │
│                                                                     │
│  ┌──────────────────────────────────────────────────────┐          │
│  │      ⚡ Realtime Gateway (Netty WebSocket)            │          │
│  │      100K+ Concurrent Connections                     │          │
│  └──────────────────────────────────────────────────────┘          │
│                                                                     │
└───────────────────┬─────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                     │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │ PostgreSQL  │  │  Cassandra  │  │   Redis     │  │  Kafka   │ │
│  │   (RDS)     │  │ (Keyspaces) │  │(ElastiCache)│  │  (MSK)   │ │
│  │             │  │             │  │             │  │          │ │
│  │ • Auth      │  │ • Messages  │  │ • Sessions  │  │• Events  │ │
│  │ • Users     │  │ • History   │  │ • Presence  │  │• Async   │ │
│  │ • Social    │  │ • Idempot.  │  │ • Cache     │  │• Notif.  │ │
│  │ • Metadata  │  │             │  │ • RateLimit │  │          │ │
│  │             │  │             │  │ • SeqGen    │  │          │ │
│  │ 68 tables   │  │  3 tables   │  │             │  │          │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └──────────┘ │
│                                                                     │
│  ┌─────────────────────┐                                           │
│  │   AWS S3 + CloudFront                                           │
│  │   (Media Storage)                                               │
│  └─────────────────────┘                                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Polyglot Persistence Strategy

| Data Type | Database | Reason |
|-----------|----------|--------|
| **User accounts, profiles, social graph** | PostgreSQL | ACID transactions, complex queries |
| **Message history** | Cassandra | High write throughput, horizontal scaling |
| **Session, presence, cache** | Redis | In-memory, sub-ms latency |
| **Async events** | Kafka | Event sourcing, reliable delivery |
| **Media files** | S3 + CloudFront | Scalable storage, global CDN |

---

## 📦 16 Backend Services

### Core Services (Team 1 + 3)

#### 🔐 1. Auth Service (Team 1) - **CRITICAL**
**Responsibility**: Authentication & Authorization
- Firebase phone OTP verification
- JWT token generation & validation
- Refresh token lifecycle
- Multi-device session management
- Remote logout functionality

**Tech**: Spring Security, Firebase Admin SDK, JWT  
**Database**: PostgreSQL (3 tables)  
**Port**: 8081

---

#### 👤 2. User Profile Service (Team 1) - **HIGH**
**Responsibility**: User identity & preferences
- User profile CRUD (name, avatar, bio, DOB)
- Privacy settings management
- User preferences (theme, language, notifications)
- QR code integration
- Profile search

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (3 tables)  
**Port**: 8082

---

#### 👥 3. Social Graph Service (Team 2) - **HIGH**
**Responsibility**: Friend relationships
- Friend requests (send, accept, reject, cancel)
- Friendship management (bidirectional)
- Block/unblock users
- Contact sync from phone
- Friend suggestions algorithm

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (4 tables)  
**Port**: 8083

---

#### 💬 4. Conversation Service (Team 3) - **CRITICAL**
**Responsibility**: Chat room management
- Create conversations (1-1 & group)
- Member management (add, remove, roles)
- Group settings (title, avatar, permissions)
- Mute/Pin/Archive/Hide
- Join modes (open, approval, invite-only)
- Invite link generation

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (6 tables)  
**Port**: 8084

---

#### 📨 5. Message Service (Team 3) - **CRITICAL** 🔴
**Responsibility**: Message persistence & history
- Message storage in Cassandra
- Conversation metadata ownership (last_message, unread_count)
- Message pagination & search
- Receipts (delivered/seen at user-level)
- Message reactions
- Idempotency (clientMessageId)
- ServerSeq ordering

**Tech**: Spring Boot, Cassandra/ScyllaDB  
**Database**: Cassandra (3 tables), PostgreSQL (6 tables)  
**Port**: 8085  
**Complexity**: 🔴 Very High

---

### Communication Services (Team 3 + 4)

#### 📎 6. Media Service (Team 4) - **HIGH**
**Responsibility**: File storage & delivery
- Presigned URL generation (S3)
- File metadata management
- Image thumbnail generation
- Video transcoding queue
- File type validation
- Storage quota tracking

**Tech**: Spring Boot, AWS S3, ImageMagick, FFmpeg  
**Database**: PostgreSQL (5 tables)  
**Port**: 8086

---

#### 🔔 7. Notification Service (Team 3) - **HIGH**
**Responsibility**: Push notifications
- FCM/APNs integration
- In-app notifications
- Badge count management
- Notification preferences
- Respect mute settings
- Notification templates

**Tech**: Spring Boot, Firebase Cloud Messaging  
**Database**: PostgreSQL (2 tables)  
**Port**: 8087

---

#### 📞 8. Call Service (Team 3) - **HIGH** 🔴
**Responsibility**: Voice & Video calls
- Voice call (1:1 & group)
- Video call (1:1 & group)
- WebRTC signaling server
- Call history tracking
- Call quality metrics
- Missed call notifications
- Screen sharing support

**Tech**: Spring Boot, WebRTC, Janus/Kurento  
**Database**: PostgreSQL (call history)  
**Port**: 8091  
**Complexity**: 🔴 High

---

### Community Features (Team 2)

#### 📸 9. Story Service (Team 2) - **MEDIUM**
**Responsibility**: 24-hour stories (Zalo Nhật ký)
- Story CRUD (photo, video, text)
- 24-hour auto-expiration
- View tracking & analytics
- Story reactions & replies
- Close friends visibility
- Story highlights

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (8 tables)  
**Port**: 8092

---

#### 📰 10. Timeline Service (Team 2) - **MEDIUM**
**Responsibility**: Social feed (Zalo Newsfeed)
- Timeline posts (text, images, videos)
- Like/React (6 emoji types)
- Comments & nested replies
- Tag friends in posts
- Share posts functionality
- Privacy per post

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (7 tables)  
**Port**: 8093

---

#### 🎨 11. Sticker Service (Team 2) - **LOW**
**Responsibility**: Sticker management
- Sticker pack CRUD
- User sticker downloads
- Usage tracking
- zSticker AI generation
- Animated stickers (Lottie)

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (5 tables)  
**Port**: 8094

---

### Extended Services (Team 1 + 4)

#### 🔗 12. QR & Link Service (Team 1) - **MEDIUM**
**Responsibility**: QR codes & short links
- Personal QR code generation
- Group invite QR codes
- Short link generation
- Deep linking support
- QR scan tracking

**Tech**: Spring Boot, QR library  
**Database**: PostgreSQL (2 tables)  
**Port**: 8095

---

#### 🤖 13. AI Service (Team 4) - **MEDIUM**
**Responsibility**: AI assistant
- Hybrid routing (Gemini → Ollama fallback)
- Quick reply suggestions
- Message summarization
- Smart translation
- zSticker AI generation
- Rate limiting & quota

**Tech**: Spring Boot, Gemini API, Ollama  
**Database**: None (stateless)  
**Port**: 8089

---

#### 📊 14. Analytics Service (Team 4) - **MEDIUM**
**Responsibility**: Metrics & tracking
- DAU/WAU/MAU calculation
- Usage metrics aggregation
- Event tracking (Kafka consumer)
- Admin dashboard APIs
- Performance monitoring

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (3 tables)  
**Port**: 8088

---

#### 💾 15. Backup Service (Team 4) - **LOW**
**Responsibility**: Data backup & restore
- Chat history export (JSON/encrypted)
- Import/restore from backup
- Selective backup per conversation
- Manual backup trigger
- Optional media backup

**Tech**: Spring Boot, File I/O  
**Database**: PostgreSQL (2 tables)  
**Port**: 8096

---

#### 🛡️ 16. Moderation Service (Team 4) - **MEDIUM**
**Responsibility**: Content moderation
- User reports (spam, harassment)
- Admin review workflow
- User warnings & actions (lock, ban)
- Content moderation policies
- Admin audit logs

**Tech**: Spring Boot, PostgreSQL  
**Database**: PostgreSQL (4 tables)  
**Port**: 8097

---

### Realtime Gateway (Team 1) - **CRITICAL** 🔴

#### ⚡ 17. Realtime Gateway
**Responsibility**: WebSocket connections
- Netty WebSocket server
- 100K+ concurrent connections
- Message routing & delivery
- ACK/Receipt handling
- Presence management (online/offline)
- Call signaling relay
- Session state in Redis

**Tech**: Netty 4.1, Redis  
**Port**: 8090  
**Complexity**: 🔴 Very High

---

## 💾 Database Schema

### PostgreSQL Tables (68 tables)

#### Auth Service (3 tables)
1. `auth_account` - User accounts
2. `auth_refresh_token` - Refresh tokens
3. `auth_otp` - OTP verification

#### User Profile Service (3 tables)
4. `user_profile` - User profiles
5. `user_privacy_setting` - Privacy settings
6. `user_setting` - User preferences

#### Social Graph Service (4 tables)
7. `friend_request` - Friend requests
8. `friendship` - Friend relationships
9. `block_list` - Blocked users
10. `contact_sync` - Synced contacts

#### Conversation Service (6 tables)
11. `conversation` - Conversations
12. `conversation_member` - Members
13. `conversation_setting` - Settings
14. `group_role` - Roles
15. `group_join_request` - Join requests
16. `group_invitation` - Invitations

#### Message Metadata (6 tables)
17. `message_metadata` - Message metadata
18. `message_reaction` - Reactions
19. `message_mention` - Mentions
20. `message_link_preview` - Link previews
21. `conversation_last_message` - Last message cache
22. `user_conversation_state` - Unread counts

#### Media Service (5 tables)
23. `media_file` - File metadata
24. `media_upload_session` - Upload sessions
25. `media_thumbnail` - Thumbnails
26. `media_processing_job` - Processing queue
27. `media_quota` - Storage quotas

#### Sticker Service (5 tables)
28. `sticker_pack` - Sticker packs
29. `sticker` - Individual stickers
30. `user_sticker_pack` - User downloads
31. `sticker_usage` - Usage tracking
32. `sticker_category` - Categories

#### Moderation Service (4 tables)
33. `user_report` - Reports
34. `admin_action` - Admin actions
35. `user_warning` - Warnings
36. `moderation_policy` - Policies

#### Story Service (8 tables)
37. `story` - Stories
38. `story_view` - Views
39. `story_reaction` - Reactions
40. `story_reply` - Replies
41. `story_highlight` - Highlights
42. `story_highlight_item` - Highlight items
43. `close_friend_list` - Close friends
44. `story_privacy_setting` - Privacy

#### Timeline Service (7 tables)
45. `timeline_post` - Posts
46. `timeline_post_media` - Post media
47. `timeline_reaction` - Reactions
48. `timeline_comment` - Comments
49. `timeline_comment_reply` - Replies
50. `timeline_tag` - Tags
51. `timeline_share` - Shares

#### Notification Service (2 tables)
52. `notification` - Notifications
53. `device_token` - Device tokens

#### Analytics Service (3 tables)
54. `user_activity_log` - Activity logs
55. `daily_metrics` - Daily stats
56. `feature_usage` - Feature usage

#### QR & Link Service (2 tables)
57. `qr_code` - QR codes
58. `short_link` - Short links

#### Call Service (1 table)
59. `call_history` - Call records

#### Event Outbox (1 table)
60. `event_outbox` - Outgoing events

#### Backup Service (2 tables)
61. `backup_job` - Backup jobs
62. `backup_file` - Backup files

**Total: 68 tables in PostgreSQL**

---

### Cassandra Tables (3 tables)

1. **messages_by_conversation**
   - Partition key: `conversation_id`
   - Clustering key: `server_seq DESC`
   - Use case: Message history pagination

2. **message_idempotency**
   - Partition key: `client_message_id`
   - TTL: 7 days
   - Use case: Prevent duplicate messages

3. **messages_by_user**
   - Partition key: `user_id`
   - Clustering key: `sent_at DESC`
   - Use case: User message search

**Total: 3 tables in Cassandra**

---

### Redis Data Structures

1. **Sessions**: `session:{userId}:{deviceId}`
2. **Presence**: `presence:{userId}` (HASH)
3. **Rate Limiting**: `rate:{service}:{userId}` (INCR + EXPIRE)
4. **Sequence Generator**: `seq:{conversationId}` (INCR)
5. **Cache**: Various caches with TTL
6. **WebSocket Routing**: `ws:{userId}` → server mapping

---

## 🔄 Kafka Topics

### Event-Driven Architecture

| Topic | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `message.sent` | Realtime Gateway | Message Service | Persist messages |
| `message.delivered` | Realtime Gateway | Message Service | Update delivery status |
| `message.seen` | Realtime Gateway | Message Service | Update seen status |
| `notification.push` | Multiple | Notification Service | Send push notifications |
| `media.uploaded` | Media Service | Message Service | Process media |
| `user.registered` | Auth Service | Multiple | New user events |
| `friend.added` | Social Service | Analytics | Friend graph updates |
| `call.started` | Call Service | Analytics | Call metrics |
| `story.created` | Story Service | Analytics | Story analytics |
| `analytics.event` | All Services | Analytics Service | General events |

---

## 🛠️ Tech Stack Chi Tiết

### Backend
```yaml
Language: Java 21 (LTS)
Framework: Spring Boot 3.x
  - Spring Web (REST APIs)
  - Spring Security (Auth)
  - Spring Data JPA (PostgreSQL)
  - Spring Data Cassandra
  - Spring Kafka
  - Spring Cloud Gateway

Build Tool: Maven / Gradle
WebSocket: Netty 4.1
API Docs: Swagger/OpenAPI 3.0
Testing: JUnit 5, Mockito, Testcontainers
```

### Databases
```yaml
RDBMS: PostgreSQL 16
  - ACID transactions
  - Complex queries
  - 68 tables

NoSQL: Apache Cassandra / ScyllaDB
  - High write throughput
  - Message history
  - 3 tables

Cache: Redis 7
  - In-memory data store
  - Session management
  - Presence tracking

Message Queue: Apache Kafka
  - Event streaming
  - Async processing
  - 10+ topics
```

### Storage & CDN
```yaml
Object Storage: AWS S3
  - Media files
  - Backups
  - Presigned URLs

CDN: CloudFront
  - Global distribution
  - Low latency delivery

Local Development: MinIO
```

### Frontend
```yaml
Framework: React Native 0.76+
Language: TypeScript
State Management: Zustand + React Query
Styling: NativeWind (TailwindCSS for RN)
Navigation: React Navigation 6
WebSocket: Socket.IO Client
```

### Infrastructure
```yaml
Container: Docker + Docker Compose
Orchestration: Kubernetes (AWS EKS)
Load Balancer:
  - ALB (REST APIs)
  - NLB (WebSocket)
  
IaC: Terraform
CI/CD: GitHub Actions + ArgoCD

Monitoring:
  - Prometheus (Metrics)
  - Grafana (Dashboards)
  - ELK Stack (Logs)
  - Jaeger (Distributed Tracing)
```

### AI & ML
```yaml
Primary: Google Gemini API
  - High quality responses
  - Smart suggestions
  
Fallback: Ollama (Local LLM)
  - High availability
  - Privacy-focused
  
Image Processing: ImageMagick, Thumbnailator
Video Processing: FFmpeg
```

---

## 👥 Team Structure & Workload

### Thành Viên 1: Core Auth & Infrastructure Lead
**Services**: 3 + Realtime Gateway + Infra  
**Workload**: 280-300 hours  
**Complexity**: 🔴🔴🔴

- Auth Service (Critical)
- User Profile Service
- QR & Link Service
- **Realtime Gateway (Netty)** 🔴
- Infrastructure (Docker, K8s, CI/CD)

---

### Thành Viên 2: Social & Community Features
**Services**: 4  
**Workload**: 270-290 hours  
**Complexity**: 🟡🟡

- Social Graph Service
- Story Service
- Timeline Service
- Sticker Service

---

### Thành Viên 3: Messaging Core
**Services**: 4  
**Workload**: 310-330 hours  
**Complexity**: 🔴🔴

- Conversation Service (Critical)
- **Message Service (Cassandra)** 🔴
- **Call Service (WebRTC)** 🔴
- Notification Service

---

### Thành Viên 4: Extended Features
**Services**: 5  
**Workload**: 260-280 hours  
**Complexity**: 🟡

- Media Service
- AI Service
- Analytics Service
- Backup Service
- Moderation Service

---

## 📅 Lộ Trình 8 Tuần

### Phase 1: Foundation (Tuần 1-2)
**Mục tiêu**: Infrastructure + Core Auth

**Deliverables**:
- ✅ Docker & K8s setup
- ✅ Auth Service (Firebase + JWT)
- ✅ User Profile Service
- ✅ Conversation Service
- ✅ Media Service (upload/download)

**Milestone 1**: Users can register, login, create conversations

---

### Phase 2: Core Features (Tuần 3-4)
**Mục tiêu**: Messaging + Realtime

**Deliverables**:
- ✅ Realtime Gateway (Netty WebSocket)
- ✅ Message Service (Cassandra)
- ✅ Notification Service (FCM)
- ✅ Social Graph Service
- ✅ Story Service
- ✅ AI Service

**Milestone 2**: Real-time messaging working, Stories functional

---

### Phase 3: Extended Features (Tuần 5-6)
**Mục tiêu**: Enhanced Communication

**Deliverables**:
- ✅ Call Service (WebRTC voice/video)
- ✅ Timeline Service (posts, comments)
- ✅ Sticker Service
- ✅ QR Service
- ✅ Backup Service
- ✅ Moderation Service
- ✅ Analytics Service

**Milestone 3**: All features complete, full integration

---

### Phase 4: Polish & Production (Tuần 7-8)
**Mục tiêu**: Optimization & Deployment

**Deliverables**:
- ✅ Bug fixes & optimization
- ✅ Performance tuning
- ✅ 80%+ test coverage
- ✅ Security hardening
- ✅ Complete documentation
- ✅ Production deployment

**Milestone 4**: Production-ready system on AWS

---

## 🔒 Security & Best Practices

### Authentication & Authorization
- ✅ Firebase phone OTP verification
- ✅ JWT tokens (15-30 min expiry)
- ✅ Refresh tokens (7 days, httpOnly cookies)
- ✅ Multi-device session tracking
- ✅ Remote logout capability

### Data Protection
- ✅ Password hashing (BCrypt/Argon2)
- ✅ Sensitive data encryption at rest
- ✅ TLS/HTTPS only
- ✅ SQL injection prevention (parameterized queries)
- ✅ XSS prevention (input sanitization)

### API Security
- ✅ Rate limiting (Redis + Bucket4j)
- ✅ CORS configuration (specific origins)
- ✅ Input validation (javax.validation)
- ✅ API versioning (/api/v1)
- ✅ Request/Response logging (audit trail)

### Infrastructure Security
- ✅ Secrets in environment variables (never hardcode)
- ✅ Container scanning (Trivy)
- ✅ Dependency scanning (OWASP, Dependabot)
- ✅ Network policies (K8s)
- ✅ IAM roles (AWS)

---

## 📈 Performance & Scalability

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| **API Response Time** | < 200ms (p95) | Prometheus |
| **WebSocket Latency** | < 50ms | Custom metrics |
| **Message Delivery** | < 500ms | End-to-end tracking |
| **Database Query** | < 100ms | Query analyzer |
| **Throughput** | 10K req/s per service | Load testing |
| **Error Rate** | < 1% | Grafana alerts |

### Scalability Strategy

#### Horizontal Scaling
- **Stateless services**: Scale to N pods
- **Realtime Gateway**: Sticky sessions + Redis pub/sub
- **Cassandra**: Add nodes for write throughput
- **PostgreSQL**: Read replicas for queries

#### Caching Strategy
```
L1 Cache: Application memory (Caffeine)
L2 Cache: Redis (distributed)
L3 Cache: CloudFront CDN (static assets)
```

#### Database Optimization
- **Indexes**: All foreign keys, search fields
- **Partitioning**: Messages by month
- **Connection Pooling**: HikariCP
- **Query Optimization**: EXPLAIN ANALYZE

---

## 📊 Monitoring & Observability

### Metrics (Prometheus)
- **Service metrics**: Request rate, latency, errors
- **Business metrics**: DAU, MAU, messages/day
- **Infrastructure**: CPU, memory, disk, network
- **Custom metrics**: Connection count, queue depth

### Logging (ELK Stack)
- **Structured logging**: JSON format
- **Log levels**: ERROR → WARN → INFO → DEBUG
- **Correlation IDs**: Track requests across services
- **Sensitive data**: Masked in logs

### Tracing (Jaeger)
- **Distributed tracing**: Follow request flow
- **Performance profiling**: Identify bottlenecks
- **Dependency mapping**: Service interactions

### Alerting (Prometheus Alertmanager)
- **Critical**: Service down, high error rate
- **Warning**: High latency, resource usage
- **Info**: Deployment events, scaling

---

## 🎓 Code Quality Standards

### Test Coverage
- **Unit tests**: 80%+ coverage
- **Integration tests**: Critical paths
- **E2E tests**: User workflows
- **Load tests**: Performance benchmarks

### Code Review
- **Every PR**: 1 approval minimum
- **Max 500 lines**: Easier to review
- **CI/CD pass**: Required
- **Squash merge**: Clean history

### Documentation
- **README**: Every service
- **API docs**: Swagger/OpenAPI
- **Architecture**: Diagrams + explanations
- **Runbooks**: Operations guide

---

## 🚀 Deployment

### Local Development
```bash
# Start all services
docker-compose up -d

# Run specific service
cd backend/services/auth-service
mvn spring-boot:run

# Run frontend
cd frontend/mobile
npm start
```

### Production (AWS EKS)
```bash
# Deploy with Terraform
cd terraform
terraform apply

# Deploy services with ArgoCD
kubectl apply -f k8s/argocd/

# Monitor deployment
kubectl get pods -n cnm-zalo
kubectl logs -f deployment/auth-service
```

---

## 📞 Support & Resources

### Documentation
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Coding standards
- [OTT_AI_Agent_Project_Docs.md](OTT_AI_Agent_Project_Docs.md) - Full architecture
- [TEAM_WORKLOAD_DISTRIBUTION.md](TEAM_WORKLOAD_DISTRIBUTION.md) - Work assignment
- [Database Schema](OTT_Zalo_Complete_Database_Schema.md) - All tables

### Communication
- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: Q&A, proposals
- **Slack/Discord**: Daily communication
- **Weekly Sync**: Demo & planning

### Learning Resources
- Spring Boot Official Docs
- Netty User Guide
- Cassandra Documentation
- WebRTC Handbook
- Clean Code - Robert C. Martin

---

## ✅ Success Criteria

### MVP (End of Week 6)
- ✅ User registration & login working
- ✅ 1-1 real-time messaging
- ✅ Group conversations
- ✅ Media sharing (images, videos)
- ✅ Push notifications
- ✅ Friend system
- ✅ User profiles

### Full Product (End of Week 8)
- ✅ All 16 services deployed
- ✅ Voice/Video calls functional
- ✅ Stories & Timeline active
- ✅ AI assistant working
- ✅ 80%+ test coverage
- ✅ Performance < 200ms p95
- ✅ Complete documentation
- ✅ Production deployment on K8s

---

## 📊 Key Metrics Summary

```
┌────────────────────────────────────────────────────────────┐
│                    PROJECT METRICS                          │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Services:          16 backend + 1 gateway                 │
│  Database Tables:   71 total (68 PostgreSQL + 3 Cassandra) │
│  Kafka Topics:      10+ event streams                      │
│  Tech Stack:        Java 21, Spring Boot 3, React Native   │
│  Team Size:         4 members                              │
│  Timeline:          8 weeks                                │
│  Total Effort:      1,120-1,200 hours                      │
│  Avg per Person:    280-300 hours                          │
│                                                             │
│  Target Scale:      100K+ concurrent users                 │
│  Message Capacity:  2B messages/day                        │
│  API Latency:       < 200ms (p95)                          │
│  WS Latency:        < 50ms                                 │
│  Availability:      99.9% uptime                           │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

**Version**: 1.0  
**Last Updated**: January 20, 2026  
**Status**: ✅ Committed & Pushed to GitHub  
**Next Steps**: Start Phase 1 implementation

---

<div align="center">

**[🏠 README](../README.md)** • **[📖 Full Docs](OTT_AI_Agent_Project_Docs.md)** • **[👥 Team](TEAM_WORKLOAD_DISTRIBUTION.md)** • **[💻 Contributing](../CONTRIBUTING.md)**

Made with ❤️ by CNM Zalo Clone Team

</div>
