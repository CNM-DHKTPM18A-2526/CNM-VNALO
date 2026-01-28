# Master Implementation Guide - OTT Zalo Clone

> **Version**: 1.0  
> **Team**: 4 Developers  
> **Timeline**: 6 Weeks  
> **Last Updated**: January 20, 2026

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Team Structure](#team-structure)
3. [Setup Instructions](#setup-instructions)
4. [Week-by-Week Plan](#week-by-week-plan)
5. [Service Dependencies](#service-dependencies)
6. [Testing Strategy](#testing-strategy)
7. [Deployment](#deployment)

---

## 🎯 Project Overview

### Goal
Build a production-ready messaging platform with 8 microservices in 6 weeks.

### Architecture
```
8 Services:
1. core-service (Auth, User, Social)
2. messaging-service (Conversations, Messages)
3. realtime-gateway (WebSocket, Presence)
4. media-service (Upload, Stickers)
5. content-service (Stories, Timeline)
6. notification-service (Push notifications)
7. moderation-service (Reports, Admin)
8. analytics-service (Logs, Stats)
```

---

## 👥 Team Structure

| Developer | Services | Role | Complexity |
|-----------|----------|------|------------|
| **Dev 1 (Senior)** | core-service<br>messaging-service | Tech Lead<br>Critical Path Owner | 🔴 High |
| **Dev 2 (Mid-Senior)** | realtime-gateway<br>media-service | Real-time Owner<br>Media Owner | 🟡 Med-High |
| **Dev 3 (Mid)** | content-service<br>notification-service | UX Features Owner | 🟡 Medium |
| **Dev 4 (Mid)** | moderation-service<br>analytics-service | Support Owner<br>DevOps | 🟢 Low-Med |

### Individual Guides

- [Developer 1 Guide](./DEV1_CORE_MESSAGING_GUIDE.md)
- [Developer 2 Guide](./DEV2_REALTIME_MEDIA_GUIDE.md)
- [Developer 3 Guide](./DEV3_CONTENT_NOTIFICATION_GUIDE.md)
- [Developer 4 Guide](./DEV4_MODERATION_ANALYTICS_GUIDE.md)

---

## 🚀 Setup Instructions

### Prerequisites (All Developers)

1. **Install Tools**
   ```bash
   - Java 17 (JDK)
   - IntelliJ IDEA Ultimate (or Community)
   - Docker Desktop
   - Git
   - Postman (for API testing)
   ```

2. **Clone Repository**
   ```bash
   git clone https://github.com/your-org/cnm-zalo-clone.git
   cd cnm-zalo-clone
   ```

3. **Start Infrastructure (Dev 2)**
   ```bash
   cd docker
   docker-compose up -d
   
   # Verify services
   docker ps
   # Should see: postgres, redis, rabbitmq
   ```

4. **Create Database Schema (Dev 3)**
   ```bash
   psql -h localhost -U postgres -d ott_zalo -f scripts/schema.sql
   ```

---

## 📅 Week-by-Week Plan

### Week 1: Foundation

#### All Developers
- [x] Install tools & setup environment
- [x] Clone repository & review docs
- [x] Attend kickoff meeting

#### Dev 1 (Senior) - CRITICAL PATH
- [x] Create Maven monorepo structure
- [x] Setup parent POM
- [x] Create common-domain module
- [x] Create common-security module (JWT)
- [x] Create common-messaging module (RabbitMQ)
- [x] Create core-service module
- [x] Implement Auth module (register, login)
- **Deliverable**: `/api/v1/auth/register` and `/api/v1/auth/login` working

#### Dev 2
- [x] Setup Docker Compose
- [x] Configure PostgreSQL, Redis, RabbitMQ
- [x] Create init scripts
- [x] Document infrastructure
- **Deliverable**: All infrastructure running

#### Dev 3
- [x] Create database migration scripts (Flyway)
- [x] Apply all schemas
- [x] Create seed data
- [x] Verify all tables created
- **Deliverable**: Database ready with test data

#### Dev 4
- [x] Setup CI/CD pipeline (GitHub Actions)
- [x] Create Postman collection for testing
- [x] Setup project documentation
- [x] Configure code quality tools
- **Deliverable**: CI passing, docs started

### Week 2: Core Services

#### Dev 1
- [ ] core-service: User module (profile CRUD)
- [ ] core-service: Social module (friends, blocks)
- [ ] core-service: QR module
- [ ] Start messaging-service: Conversation module
- **Deliverable**: User management + Friends working

#### Dev 2
- [ ] media-service: Cloudinary setup
- [ ] media-service: Upload endpoint
- [ ] media-service: Image processing
- [ ] Start realtime-gateway: WebSocket config
- **Deliverable**: Image upload working

#### Dev 3
- [ ] content-service: Story module
- [ ] content-service: Story views
- [ ] content-service: Story privacy
- **Deliverable**: Story creation & viewing working

#### Dev 4
- [ ] analytics-service: Activity logging
- [ ] analytics-service: Event tracking
- [ ] Help with integration testing
- **Deliverable**: Logging system working

### Week 3: Messaging & Real-time

#### Dev 1 - CRITICAL
- [ ] messaging-service: Message send/receive
- [ ] messaging-service: Message history
- [ ] messaging-service: Reactions
- [ ] messaging-service: Read receipts
- **Deliverable**: Full chat functionality

#### Dev 2 - CRITICAL
- [ ] realtime-gateway: WebSocket authentication
- [ ] realtime-gateway: Message broadcasting
- [ ] realtime-gateway: Presence system
- [ ] realtime-gateway: Typing indicators
- **Deliverable**: Real-time messaging

#### Dev 3
- [ ] content-service: Timeline posts
- [ ] content-service: Likes & comments
- [ ] notification-service: FCM setup
- **Deliverable**: Timeline working

#### Dev 4
- [ ] moderation-service: Report submission
- [ ] moderation-service: Admin panel
- [ ] Setup monitoring (Prometheus)
- **Deliverable**: Report system working

### Week 4: Integration

#### All Developers
- [ ] Integration testing between services
- [ ] Fix cross-service bugs
- [ ] API documentation
- [ ] Code reviews

#### Dev 1 & Dev 2
- [ ] Integrate messaging with realtime
- [ ] Test message flow end-to-end
- [ ] Performance tuning

#### Dev 3
- [ ] notification-service: Event listeners
- [ ] Integrate with all services
- [ ] Test push notifications

#### Dev 4
- [ ] moderation-service: Action execution
- [ ] analytics-service: Stats dashboard
- [ ] Complete CI/CD

### Week 5: Testing & Polish

#### All Developers
- [ ] E2E testing
- [ ] Load testing
- [ ] Security audit
- [ ] Bug fixes
- [ ] Documentation

#### Specific Tasks
- **Dev 1**: Load test messaging (1000 msg/s)
- **Dev 2**: Load test WebSocket (10K concurrent)
- **Dev 3**: Frontend integration testing
- **Dev 4**: Setup Grafana dashboards

### Week 6: Deployment

#### All Developers
- [ ] Deploy to AWS
- [ ] Final testing in production
- [ ] Monitoring setup
- [ ] Documentation finalization

#### Deployment Tasks
- **Dev 1 + Dev 2**: AWS infrastructure setup
- **Dev 3**: Mobile app integration
- **Dev 4**: Final testing & docs

---

## 🔗 Service Dependencies

### Dependency Graph
```
core-service (Auth)
    ↓ JWT tokens
    ├─→ messaging-service
    │       ↓ events
    │       └─→ realtime-gateway
    │       ↓ events
    │       └─→ notification-service
    │
    ├─→ content-service
    │       ↓ media_id
    │       └─→ media-service
    │
    └─→ moderation-service
```

### Critical Path
```
1. core-service FIRST (provides auth)
2. messaging-service (depends on core)
3. realtime-gateway (depends on messaging)
4. Others can be parallel after core
```

---

## 🧪 Testing Strategy

### Unit Testing
```bash
# Each service
mvn test

# Coverage report
mvn jacoco:report
```

### Integration Testing
```bash
# All services
mvn verify -P integration-test
```

### E2E Testing Flow
```
1. User registers → core-service
2. User uploads avatar → media-service
3. User adds friend → core-service (social)
4. User sends message → messaging-service
5. Friend receives via WebSocket → realtime-gateway
6. Friend gets push notification → notification-service
7. User posts story → content-service
8. Another user reports → moderation-service
```

### Load Testing
```bash
# Use Apache JMeter
jmeter -n -t load-test.jmx -l results.jtl

# Targets:
- 1000 messages/second
- 10,000 concurrent WebSocket connections  
- <200ms API response time (p95)
```

---

## 🚀 Deployment

### Local Development
```bash
# Start infrastructure
docker-compose up -d

# Run each service in IntelliJ
Right-click Application.java → Run

# Or via Maven
mvn spring-boot:run -pl services/core-service
```

### AWS Production

**Architecture**:
```
3× EC2 t2.micro (free tier)
├── EC2-1: core, messaging, notification
├── EC2-2: media, content, moderation, analytics
└── EC2-3: realtime-gateway + nginx

1× RDS PostgreSQL t3.micro (free tier)
1× ElastiCache Redis t3.micro
Cloudinary (free 25GB)
```

**Deployment Steps**:
```bash
# 1. Build all services
mvn clean package -DskipTests

# 2. Build Docker images
docker build -t core-service:latest services/core-service

# 3. Push to AWS ECR (or Docker Hub)
docker push your-repo/core-service:latest

# 4. Deploy via docker-compose on EC2
docker-compose -f docker-compose.prod.yml up -d
```

---

## 📊 Monitoring

### Tools
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards
- **ELK Stack**: Logging (optional)
- **AWS CloudWatch**: Infrastructure

### Key Metrics
- API response time
- WebSocket connections count
- Message throughput (msg/s)
- Error rate
- Database query time

---

## 🤝 Collaboration

### Daily Standups
- **Time**: 9:00 AM
- **Duration**: 15 minutes
- **Format**: What did I do yesterday? What will I do today? Any blockers?

### Code Reviews
- All PRs require 1 approval
- Dev 1 reviews Dev 3, Dev 4
- Dev 2 reviews Dev 3, Dev 4
- Cross-reviews for knowledge sharing

### Communication
- **Slack/Discord**: Daily communication
- **GitHub Issues**: Task tracking
- **Weekly Demo**: Friday 4 PM

---

## 📚 Resources

### Documentation
- [Database Schema](../OTT_Zalo_Complete_Database_Schema.md)
- [Database Details](../OTT_Zalo_Database_Documentation.md)
- [Team Allocation Plan](../../brain/.../team_allocation_plan.md)
- [Deployment Plan](../../brain/.../deployment_optimization_plan.md)

### External References
- Spring Boot Docs: https://spring.io/projects/spring-boot
- Cloudinary API: https://cloudinary.com/documentation
- Firebase FCM: https://firebase.google.com/docs/cloud-messaging
- RabbitMQ: https://www.rabbitmq.com/documentation.html

---

## ✅ Success Criteria

- [ ] All 8 services deployed and healthy
- [ ] User can register/login
- [ ] User can send/receive messages (real-time)
- [ ] User can upload media
- [ ] User can post stories
- [ ] Push notifications working
- [ ] Admin can moderate content
- [ ] System handles 1000 concurrent users
- [ ] API response time < 200ms (p95)
- [ ] Monthly cost < $50

---

## 🎯 Next Steps

1. **Team Meeting**: Assign exact services to developers
2. **Setup Day**: All developers setup environment (Day 1)
3. **Kickoff**: Start Week 1 development (Day 2)
4. **End of Week 1**: Demo auth working
5. **Continue**: Follow individual guides

---

**Good luck team! Let's build something amazing! 🚀**

*Last updated: January 20, 2026*
