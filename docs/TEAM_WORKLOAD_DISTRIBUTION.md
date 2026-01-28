# 👥 Phân Chia Công Việc Backend - Nhóm 4 Thành Viên

> **Dự án**: CNM Zalo Clone - Enterprise Messaging Platform  
> **Kiến trúc**: Microservices với 16 services + Realtime Gateway  
> **Thời gian**: 8 tuần  
> **Mục tiêu**: Xây dựng hệ thống nhắn tin thời gian thực quy mô lớn

---

## 📊 Tổng Quan Hệ Thống

### Kiến Trúc Tổng Thể
```
┌─────────────────────────────────────────────────────────────────────┐
│                    CNM ZALO CLONE ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Frontend (React Native)                                             │
│        ↓                                                             │
│  API Gateway (Spring Cloud Gateway)                                  │
│        ↓                                                             │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐     │
│  │   Team 1     │   Team 2     │   Team 3     │   Team 4     │     │
│  │  (Core Auth) │ (Social)     │ (Messaging)  │ (Extended)   │     │
│  └──────────────┴──────────────┴──────────────┴──────────────┘     │
│        ↓                ↓                ↓               ↓           │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │              Realtime Gateway (Netty WebSocket)           │      │
│  └──────────────────────────────────────────────────────────┘      │
│        ↓                                                             │
│  ┌──────────────┬──────────────┬──────────────────────┐            │
│  │  PostgreSQL  │  Cassandra   │  Redis  │  Kafka     │            │
│  └──────────────┴──────────────┴──────────────────────┘            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Danh Sách 16 Backend Services

| # | Service | Complexity | Database | Port |
|---|---------|-----------|----------|------|
| 1 | Auth Service | 🟢 Medium | PostgreSQL | 8081 |
| 2 | User Profile Service | 🟢 Medium | PostgreSQL | 8082 |
| 3 | Social Graph Service | 🟡 Medium-High | PostgreSQL | 8083 |
| 4 | Conversation Service | 🟡 Medium-High | PostgreSQL | 8084 |
| 5 | Message Service | 🔴 High | Cassandra | 8085 |
| 6 | Media Service | 🟢 Medium | PostgreSQL + S3 | 8086 |
| 7 | Notification Service | 🟢 Medium | PostgreSQL | 8087 |
| 8 | Analytics Service | 🟢 Medium | PostgreSQL | 8088 |
| 9 | AI Service | 🟡 Medium-High | - | 8089 |
| 10 | Call Service | 🔴 High | PostgreSQL | 8091 |
| 11 | Story Service | 🟡 Medium-High | PostgreSQL | 8092 |
| 12 | Timeline Service | 🟡 Medium-High | PostgreSQL | 8093 |
| 13 | Sticker Service | 🟢 Medium | PostgreSQL | 8094 |
| 14 | QR & Link Service | 🟢 Low | PostgreSQL | 8095 |
| 15 | Backup Service | 🟡 Medium-High | PostgreSQL | 8096 |
| 16 | Moderation Service | 🟢 Medium | PostgreSQL | 8097 |
| 17 | Realtime Gateway | 🔴 Very High | Redis | 8090 |

---

## 🎯 Phân Chia Theo Nhóm (Load-Balanced)

### 👤 **Thành Viên 1: Core Authentication & Infrastructure Lead**

**Vai trò**: Backend Lead, DevOps, Realtime Gateway

#### Services (3 + Realtime Gateway)
1. **Auth Service** 🔐 - **Priority: Critical**
   - Firebase phone authentication integration
   - JWT token generation & validation
   - Refresh token management
   - Device session tracking
   - Multi-device support
   - OTP verification
   
2. **User Profile Service** 👤 - **Priority: High**
   - User profile CRUD (name, avatar, bio)
   - Privacy settings management
   - User preferences & settings
   - QR code generation integration
   - Profile search functionality
   
3. **QR & Link Service** 🔗 - **Priority: Medium**
   - Personal QR code generation
   - Group invite QR codes
   - Short link generation & tracking
   - Deep linking support

4. **Realtime Gateway** ⚡ - **Priority: Critical** 🔴
   - Netty WebSocket server
   - Connection management (100K+ concurrent)
   - Message routing & delivery
   - ACK/Receipt handling
   - Presence management
   - Call signaling relay
   - Session state in Redis

#### Shared Responsibilities
- **API Gateway** setup (Spring Cloud Gateway)
- **Docker & Kubernetes** configuration
- **CI/CD Pipeline** (GitHub Actions)
- **Infrastructure as Code** (Terraform)
- **Monitoring & Logging** setup (Prometheus, Grafana)

**Estimated Workload**: 280-300 hours
- Auth Service: 60h
- User Service: 50h
- QR Service: 30h
- Realtime Gateway: 100h 🔴
- Infrastructure: 60h

---

### 👥 **Thành Viên 2: Social & Community Features**

**Vai trò**: Social Graph Specialist, Community Features

#### Services (4)
1. **Social Graph Service** 👥 - **Priority: High**
   - Friend requests (send, accept, reject)
   - Friendship management
   - Block/unblock functionality
   - Contact sync from phone
   - Friend suggestions
   - Bidirectional relationship handling

2. **Story Service** 📸 - **Priority: Medium**
   - Story CRUD (photo, video, text with background)
   - 24-hour auto-expiration
   - View tracking & analytics
   - Story reactions & replies
   - Close friends visibility
   - Story highlights

3. **Timeline Service** 📰 - **Priority: Medium**
   - Timeline posts (text, images, videos)
   - Like/React with 6 emoji types
   - Comments & nested replies
   - Tag friends in posts
   - Share posts functionality
   - Privacy settings per post

4. **Sticker Service** 🎨 - **Priority: Low**
   - Sticker pack management
   - User sticker downloads
   - Sticker usage tracking
   - zSticker AI generation integration
   - Animated stickers (Lottie support)

**Estimated Workload**: 270-290 hours
- Social Graph: 90h
- Story Service: 70h
- Timeline Service: 80h
- Sticker Service: 40h

---

### 💬 **Thành Viên 3: Messaging Core & Real-time Communication**

**Vai trò**: Messaging Expert, Real-time Communication

#### Services (4)
1. **Conversation Service** 💬 - **Priority: Critical**
   - Conversation CRUD (1-1 & group)
   - Member management (add, remove, roles)
   - Group settings (title, avatar, permissions)
   - Conversation metadata
   - Mute/Pin/Archive functionality
   - Join modes (open, approval, invite-only)

2. **Message Service** 📨 - **Priority: Critical** 🔴
   - Message persistence (Cassandra)
   - Message history & pagination
   - Conversation metadata ownership
   - Unread count management
   - Message receipts (delivered/seen)
   - Message reactions
   - Message idempotency (dedupe)
   - ServerSeq ordering
   - Message search functionality

3. **Call Service** 📞 - **Priority: High** 🔴
   - Voice call (1:1 & group)
   - Video call (1:1 & group)
   - WebRTC signaling server
   - Call history tracking
   - Call quality metrics
   - Missed call notifications
   - Screen sharing support
   - TURN/STUN server integration

4. **Notification Service** 🔔 - **Priority: High**
   - Push notification (FCM/APNs)
   - In-app notifications
   - Notification preferences
   - Mute settings respect
   - Badge count management
   - Notification templates

**Estimated Workload**: 310-330 hours
- Conversation: 70h
- Message Service: 110h 🔴
- Call Service: 90h 🔴
- Notification: 50h

---

### 🛠️ **Thành Viên 4: Extended Features & Support Services**

**Vai trò**: Extended Features, AI Integration, Moderation

#### Services (5)
1. **Media Service** 📎 - **Priority: High**
   - Presigned URL generation (upload/download)
   - File metadata management
   - S3 integration
   - Image thumbnail generation
   - Video transcoding queue
   - File type validation
   - Storage quota management

2. **AI Service** 🤖 - **Priority: Medium**
   - Hybrid routing (Gemini → Ollama fallback)
   - Quick reply suggestions
   - Message summarization
   - Smart translation
   - zSticker AI generation
   - Rate limiting & quota
   - Privacy policy enforcement

3. **Analytics Service** 📊 - **Priority: Medium**
   - DAU/WAU/MAU tracking
   - Usage metrics aggregation
   - Event tracking (Kafka consumer)
   - Admin dashboard APIs
   - Performance metrics
   - User behavior analytics

4. **Backup Service** 💾 - **Priority: Low**
   - Chat history export (JSON/encrypted)
   - Import/restore from backup
   - Selective backup (per conversation)
   - Manual backup trigger
   - Media backup (optional)

5. **Moderation Service** 🛡️ - **Priority: Medium**
   - User reports (spam, harassment)
   - Admin review workflow
   - User warnings & actions
   - Content moderation policies
   - Admin audit logs

**Estimated Workload**: 260-280 hours
- Media Service: 80h
- AI Service: 70h
- Analytics: 50h
- Backup Service: 30h
- Moderation: 40h

---

## 📋 Lộ Trình Phát Triển (8 Tuần)

### Phase 1: Foundation (Tuần 1-2) - **Critical Path**
**Mục tiêu**: Setup infrastructure + Core authentication

| Thành viên | Tasks | Deliverables |
|-----------|-------|--------------|
| **TM1** | Infrastructure setup, Auth Service | Docker, K8s, Auth API |
| **TM2** | Social Graph foundation | Friend request API |
| **TM3** | Conversation Service | Conversation CRUD API |
| **TM4** | Media Service | Upload/download API |

**Milestone 1**: ✅ Users can register, login, create conversations

---

### Phase 2: Core Features (Tuần 3-4) - **Main Development**
**Mục tiêu**: Messaging + Realtime + Social features

| Thành viên | Tasks | Deliverables |
|-----------|-------|--------------|
| **TM1** | Realtime Gateway (Netty), User Profile | WebSocket server, Profile API |
| **TM2** | Story Service, Timeline foundation | Story CRUD, Timeline API |
| **TM3** | Message Service (Cassandra), Notification | Message persistence, Push |
| **TM4** | AI Service (hybrid), Analytics | AI chat endpoint, Metrics API |

**Milestone 2**: ✅ Real-time messaging working, Stories functional

---

### Phase 3: Extended Features (Tuần 5-6)
**Mục tiêu**: Enhanced communication + Community features

| Thành viên | Tasks | Deliverables |
|-----------|-------|--------------|
| **TM1** | QR Service, Gateway optimization | QR codes, Performance tuning |
| **TM2** | Timeline Service completion, Stickers | Posts, Comments, Sticker packs |
| **TM3** | Call Service (WebRTC) | Voice/Video calls |
| **TM4** | Backup Service, Moderation | Export/Import, Reports |

**Milestone 3**: ✅ Calls working, Timeline active, Full feature set

---

### Phase 4: Polish & Optimization (Tuần 7-8)
**Mục tiêu**: Bug fixes, Performance, Testing, Documentation

| All Members | Tasks |
|------------|-------|
| **Bug Fixes** | Fix issues from integration testing |
| **Performance** | Optimize slow queries, reduce latency |
| **Testing** | Unit tests (80%), Integration tests |
| **Documentation** | API docs, Deployment guide |
| **Security** | Penetration testing, vulnerability scan |

**Milestone 4**: ✅ Production-ready system

---

## 🔧 Công Nghệ & Tools Theo Team

### Common Stack (All Members)
```yaml
Framework: Spring Boot 3.x (Java 21)
Build: Maven / Gradle
Database: PostgreSQL 16
Cache: Redis 7
Message Queue: Apache Kafka
API Gateway: Spring Cloud Gateway
Security: Spring Security + JWT
Testing: JUnit 5, Mockito, Testcontainers
```

### Team-Specific Technologies

#### Thành Viên 1 (Core Auth + Infra)
```yaml
Auth: Firebase Admin SDK
WebSocket: Netty 4.1
Container: Docker, Docker Compose
Orchestration: Kubernetes (K8s)
IaC: Terraform
CI/CD: GitHub Actions, ArgoCD
Monitoring: Prometheus, Grafana, ELK Stack
```

#### Thành Viên 2 (Social)
```yaml
Image Processing: ImageMagick, Thumbnailator
Video: FFmpeg (for story videos)
Animation: Lottie (for stickers)
Graph DB: (Optional) Neo4j for friend suggestions
```

#### Thành Viên 3 (Messaging)
```yaml
NoSQL: Apache Cassandra / ScyllaDB
WebRTC: Janus Gateway, Kurento
Signaling: Socket.IO / Netty
Push: Firebase Cloud Messaging (FCM), APNs
```

#### Thành Viên 4 (Extended)
```yaml
Storage: AWS S3, MinIO (local)
CDN: CloudFront
AI: Google Gemini API, Ollama
Image Processing: ImageMagick, Sharp
Video: FFmpeg transcoding
```

---

## 📊 Metrics & KPIs

### Individual Performance Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Code Quality** | 80%+ test coverage | SonarQube, JaCoCo |
| **API Response Time** | < 200ms (p95) | Spring Actuator, Prometheus |
| **Error Rate** | < 1% | Grafana dashboard |
| **Code Review** | 100% reviewed | GitHub PR process |
| **Documentation** | 100% API documented | Swagger/OpenAPI |

### Team Deliverables per Phase

| Phase | Services Completed | Integration Tests | Docs |
|-------|-------------------|-------------------|------|
| Phase 1 | 4 services | 50%+ coverage | API specs |
| Phase 2 | 8 services | 70%+ coverage | User guides |
| Phase 3 | 16 services | 80%+ coverage | Deployment |
| Phase 4 | All optimized | 85%+ coverage | Complete |

---

## 🤝 Collaboration Guidelines

### Daily Standups (15 mins)
- **What did I do yesterday?**
- **What will I do today?**
- **Any blockers?**

### Weekly Sync (1 hour)
- **Demo progress** (working features)
- **Integration issues** discussion
- **Next week planning**

### Code Review Rules
- **Every PR needs 1 approval** (preferably from another team)
- **Max 500 lines per PR** (easier to review)
- **Must pass CI/CD** before merge
- **Squash and merge** to keep history clean

### Communication Channels
- **Slack/Discord**: Daily communication
- **GitHub Issues**: Task tracking
- **GitHub Projects**: Sprint board
- **Confluence/Notion**: Documentation
- **Zoom/Meet**: Weekly syncs

---

## 🔒 Security & Best Practices

### All Services Must Implement
1. ✅ **Input Validation** (javax.validation)
2. ✅ **JWT Authentication** (Spring Security)
3. ✅ **Rate Limiting** (Bucket4j)
4. ✅ **SQL Injection Prevention** (Parameterized queries)
5. ✅ **XSS Prevention** (Input sanitization)
6. ✅ **CORS Configuration** (Specific origins)
7. ✅ **Secrets Management** (Environment variables)
8. ✅ **HTTPS Only** (Production)
9. ✅ **Dependency Scanning** (OWASP, Dependabot)
10. ✅ **Audit Logging** (User actions)

---

## 📦 Shared Libraries (Reusable Components)

### common-dto
```
com.cnmzalo.common.dto
├── UserDTO
├── MessageDTO
├── ConversationDTO
├── ApiResponse<T>
└── PageResponse<T>
```

### common-security
```
com.cnmzalo.common.security
├── JwtTokenProvider
├── JwtAuthenticationFilter
├── SecurityConfig
└── UserPrincipal
```

### common-kafka
```
com.cnmzalo.common.kafka
├── KafkaProducer
├── KafkaConsumer
├── EventPublisher
└── Event Models
```

### common-exception
```
com.cnmzalo.common.exception
├── GlobalExceptionHandler
├── CustomExceptions
└── ErrorResponse
```

---

## 🎓 Learning Resources

### Required Reading (All Members)
1. [CONTRIBUTING.md](../CONTRIBUTING.md) - Code conventions
2. [OTT_AI_Agent_Project_Docs.md](OTT_AI_Agent_Project_Docs.md) - Architecture
3. [OTT_Zalo_Complete_Database_Schema.md](OTT_Zalo_Complete_Database_Schema.md) - Database

### Recommended Books
- **Clean Code** - Robert C. Martin
- **Microservices Patterns** - Chris Richardson
- **Designing Data-Intensive Applications** - Martin Kleppmann
- **Building Microservices** - Sam Newman

### Online Resources
- Spring Boot Official Docs
- Netty User Guide
- Cassandra Documentation
- WebRTC Handbook
- Kafka: The Definitive Guide

---

## ⚠️ Risk Mitigation

### High-Risk Areas

| Risk | Service | Mitigation |
|------|---------|------------|
| **Performance bottleneck** | Message Service | Use Cassandra, optimize queries, caching |
| **WebSocket scaling** | Realtime Gateway | Horizontal scaling, sticky sessions |
| **Call quality** | Call Service | TURN server, QoS monitoring |
| **AI availability** | AI Service | Ollama fallback, circuit breaker |
| **Data consistency** | All | Event sourcing, outbox pattern |

### Backup Plans
- **Cassandra complexity** → Use PostgreSQL with partitioning
- **Netty difficulty** → Use Spring WebSocket
- **WebRTC challenges** → Use third-party service (Agora, Twilio)
- **AI costs** → Use Ollama only

---

## 📞 Support & Escalation

### When to Escalate
- **Blocked for > 4 hours** → Ask in team channel
- **Architecture decision needed** → Weekly sync
- **Cross-service integration issue** → Pair programming session
- **Technical debt** → Document & prioritize

### Pair Programming Sessions
- **Thành viên 1 + 3**: Realtime Gateway ↔ Message Service
- **Thành viên 2 + 4**: Story ↔ Media integration
- **All members**: Integration testing

---

## 🏆 Success Criteria

### MVP (Minimum Viable Product) - End of Week 6
- ✅ Users can register & login
- ✅ Send 1-1 messages in real-time
- ✅ Create group conversations
- ✅ Send media (images, videos)
- ✅ Push notifications work
- ✅ Basic friend system
- ✅ User profiles

### Full Product - End of Week 8
- ✅ All 16 services deployed
- ✅ Voice/Video calls functional
- ✅ Stories & Timeline active
- ✅ AI assistant working
- ✅ 80%+ test coverage
- ✅ Performance < 200ms p95
- ✅ Complete documentation
- ✅ Production-ready on K8s

---

## 📝 Summary: Service Distribution

```
┌─────────────────────────────────────────────────────────────┐
│                   LOAD DISTRIBUTION                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Thành viên 1: 3 services + Realtime Gateway + Infra        │
│  Complexity: 🔴🔴🔴 (280-300h)                              │
│  - Auth (Critical) + User + QR                              │
│  - Realtime Gateway (Very High)                             │
│  - Infrastructure & DevOps                                  │
│                                                              │
│  Thành viên 2: 4 services (Social & Community)              │
│  Complexity: 🟡🟡 (270-290h)                                │
│  - Social Graph + Story + Timeline + Sticker                │
│                                                              │
│  Thành viên 3: 4 services (Messaging Core)                  │
│  Complexity: 🔴🔴 (310-330h)                                │
│  - Conversation + Message (Critical) + Call + Notification  │
│                                                              │
│  Thành viên 4: 5 services (Extended Features)               │
│  Complexity: 🟡 (260-280h)                                  │
│  - Media + AI + Analytics + Backup + Moderation             │
│                                                              │
│  TOTAL: 16 services + Realtime Gateway                      │
│  AVG: 1,120-1,200 hours total (280-300h per person)         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**Version**: 1.0  
**Last Updated**: January 20, 2026  
**Contact**: Team Lead - [GitHub Issues](https://github.com/CNM-DHKTPM18A-2526/CNM-ZALO/issues)
