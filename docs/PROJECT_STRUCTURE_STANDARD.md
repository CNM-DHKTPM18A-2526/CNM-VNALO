# 📁 CẤU TRÚC CHUẨN DỰ ÁN VNALO

> **Hướng dẫn tổ chức code và chuẩn hóa cấu trúc thư mục cho toàn bộ dự án**

---

## 📋 Mục Lục

- [Tổng Quan Cấu Trúc](#-tổng-quan-cấu-trúc)
- [Backend - Java Services](#-backend---java-services)
- [Backend - Node Services](#-backend---node-services)
- [Frontend - React Native](#-frontend---react-native)
- [Docker & Infrastructure](#-docker--infrastructure)
- [Documentation](#-documentation)
- [Quy Tắc Đặt Tên](#-quy-tắc-đặt-tên)
- [Best Practices](#-best-practices)

---

## 🏗️ Tổng Quan Cấu Trúc

```
cnm-vnalo/                              # Root project
│
├── 📱 frontend/                         # Mobile app (React Native)
│   ├── src/
│   ├── android/
│   ├── ios/
│   └── package.json
│
├── 🔧 backend/                          # Backend services
│   ├── java-services/                  # Spring Boot microservices
│   │   ├── common/                     # Shared libraries
│   │   │   ├── common-domain/          # Domain models, base entities
│   │   │   ├── common-security/        # JWT, authentication
│   │   │   ├── common-utils/           # Utilities, helpers
│   │   │   └── common-dto/             # Shared DTOs
│   │   │
│   │   └── services/                   # Business services
│   │       ├── auth-service/           # 8081 - Authentication
│   │       ├── user-service/           # 8082 - User management
│   │       ├── messaging-service/      # 8083 - Chat, messages
│   │       ├── media-service/          # 8084 - File upload
│   │       ├── notification-service/   # 8085 - Push notifications
│   │       ├── story-service/          # 8086 - Stories, timeline
│   │       ├── group-service/          # 8087 - Group chat
│   │       ├── call-service/           # 8088 - Voice/video calls
│   │       ├── ai-service/             # 8089 - AI assistant
│   │       ├── moderation-service/     # 8090 - Content moderation
│   │       ├── analytics-service/      # 8091 - Analytics, logging
│   │       ├── search-service/         # 8092 - Search functionality
│   │       └── api-gateway/            # 8080 - Gateway
│   │
│   └── node-services/                  # Node.js services (optional)
│       ├── realtime-gateway/           # WebSocket server (Netty alternative)
│       └── streaming-service/          # Media streaming
│
├── 🐳 docker/                           # Docker infrastructure
│   ├── docker-compose.yml              # Development environment
│   ├── docker-compose.prod.yml         # Production
│   ├── init-db.sql                     # Database initialization
│   └── Dockerfile.*                    # Custom Dockerfiles
│
├── 📚 docs/                             # Documentation
│   ├── architecture/                   # Architecture diagrams
│   ├── api/                            # API documentation
│   ├── guides/                         # Developer guides
│   ├── database/                       # Database schemas
│   └── deployment/                     # Deployment guides
│
├── 🧪 tests/                            # Integration tests
│   ├── e2e/                            # End-to-end tests
│   └── load-testing/                   # Performance tests
│
├── 🚀 k8s/                              # Kubernetes configurations
│   ├── dev/                            # Development environment
│   ├── staging/                        # Staging environment
│   └── prod/                           # Production environment
│
├── 🔧 scripts/                          # Automation scripts
│   ├── setup/                          # Setup scripts
│   ├── build/                          # Build scripts
│   └── deploy/                         # Deployment scripts
│
├── 📄 .github/                          # GitHub workflows
│   └── workflows/
│       ├── ci.yml                      # Continuous Integration
│       └── cd.yml                      # Continuous Deployment
│
├── README.md                           # Project overview (English)
├── README.vi.md                        # Project overview (Vietnamese)
├── CONTRIBUTING.md                     # Contribution guidelines
├── LICENSE                             # License file
└── .gitignore                          # Git ignore rules
```

---

## 🔧 Backend - Java Services

### 1️⃣ Cấu Trúc Chi Tiết Một Service

```
services/auth-service/                  # Example service
│
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── vn/edu/hcmuaf/fit/ott/auth/
│   │   │       │
│   │   │       ├── AuthServiceApplication.java  # Main class
│   │   │       │
│   │   │       ├── config/                      # Configuration
│   │   │       │   ├── SecurityConfig.java
│   │   │       │   ├── SwaggerConfig.java
│   │   │       │   └── KafkaConfig.java
│   │   │       │
│   │   │       ├── controller/                  # REST Controllers
│   │   │       │   ├── AuthController.java
│   │   │       │   └── VerificationController.java
│   │   │       │
│   │   │       ├── service/                     # Business Logic
│   │   │       │   ├── AuthService.java
│   │   │       │   ├── impl/
│   │   │       │   │   └── AuthServiceImpl.java
│   │   │       │   └── OtpService.java
│   │   │       │
│   │   │       ├── repository/                  # Data Access
│   │   │       │   ├── UserRepository.java
│   │   │       │   └── OtpRepository.java
│   │   │       │
│   │   │       ├── entity/                      # Database Entities
│   │   │       │   ├── User.java
│   │   │       │   └── OtpVerification.java
│   │   │       │
│   │   │       ├── dto/                         # Data Transfer Objects
│   │   │       │   ├── request/
│   │   │       │   │   ├── LoginRequest.java
│   │   │       │   │   └── RegisterRequest.java
│   │   │       │   └── response/
│   │   │       │       ├── AuthResponse.java
│   │   │       │       └── UserResponse.java
│   │   │       │
│   │   │       ├── mapper/                      # DTO ↔ Entity Mappers
│   │   │       │   └── UserMapper.java
│   │   │       │
│   │   │       ├── exception/                   # Custom Exceptions
│   │   │       │   ├── AuthException.java
│   │   │       │   └── GlobalExceptionHandler.java
│   │   │       │
│   │   │       ├── event/                       # Event Producers/Consumers
│   │   │       │   ├── UserRegisteredEvent.java
│   │   │       │   └── producer/
│   │   │       │       └── AuthEventProducer.java
│   │   │       │
│   │   │       └── util/                        # Service-specific Utils
│   │   │           └── OtpGenerator.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml                  # Main config
│   │       ├── application-dev.yml              # Dev profile
│   │       ├── application-prod.yml             # Prod profile
│   │       └── db/
│   │           └── migration/                   # Flyway migrations
│   │               ├── V1__create_users_table.sql
│   │               └── V2__create_otp_table.sql
│   │
│   └── test/
│       ├── java/
│       │   └── vn/edu/hcmuaf/fit/ott/auth/
│       │       ├── controller/
│       │       │   └── AuthControllerTest.java
│       │       ├── service/
│       │       │   └── AuthServiceTest.java
│       │       └── integration/
│       │           └── AuthIntegrationTest.java
│       └── resources/
│           └── application-test.yml
│
├── pom.xml                                      # Maven configuration
├── Dockerfile                                   # Container image
├── README.md                                    # Service documentation
└── .gitignore
```

### 2️⃣ Common Modules (Shared Libraries)

```
common/
│
├── common-domain/                               # Base entities, interfaces
│   ├── src/main/java/vn/edu/hcmuaf/fit/ott/common/domain/
│   │   ├── BaseEntity.java                     # id, createdAt, updatedAt
│   │   ├── AuditableEntity.java                # createdBy, modifiedBy
│   │   └── SoftDeletableEntity.java            # deletedAt, isDeleted
│   └── pom.xml
│
├── common-security/                             # Security utilities
│   ├── src/main/java/vn/edu/hcmuaf/fit/ott/common/security/
│   │   ├── JwtTokenProvider.java               # JWT generation/validation
│   │   ├── SecurityUtils.java                  # Security helpers
│   │   └── UserPrincipal.java                  # Custom UserDetails
│   └── pom.xml
│
├── common-dto/                                  # Shared DTOs
│   ├── src/main/java/vn/edu/hcmuaf/fit/ott/common/dto/
│   │   ├── ApiResponse.java                    # Standard response wrapper
│   │   ├── PageResponse.java                   # Pagination response
│   │   └── ErrorResponse.java                  # Error response
│   └── pom.xml
│
├── common-utils/                                # Utilities
│   ├── src/main/java/vn/edu/hcmuaf/fit/ott/common/util/
│   │   ├── DateUtils.java
│   │   ├── StringUtils.java
│   │   ├── ValidationUtils.java
│   │   └── FileUtils.java
│   └── pom.xml
│
└── common-exception/                            # Exception handling
    ├── src/main/java/vn/edu/hcmuaf/fit/ott/common/exception/
    │   ├── BusinessException.java
    │   ├── NotFoundException.java
    │   ├── ValidationException.java
    │   └── GlobalExceptionHandler.java
    └── pom.xml
```

### 3️⃣ Parent POM Structure

```xml
<!-- backend/java-services/pom.xml -->
<project>
    <groupId>vn.edu.hcmuaf.fit.ott</groupId>
    <artifactId>vnalo-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>
    
    <modules>
        <!-- Common modules -->
        <module>common/common-domain</module>
        <module>common/common-security</module>
        <module>common/common-dto</module>
        <module>common/common-utils</module>
        <module>common/common-exception</module>
        
        <!-- Business services -->
        <module>services/auth-service</module>
        <module>services/user-service</module>
        <module>services/messaging-service</module>
        <!-- ... other services -->
    </modules>
    
    <properties>
        <java.version>21</java.version>
        <spring-boot.version>3.2.1</spring-boot.version>
        <spring-cloud.version>2023.0.0</spring-cloud.version>
    </properties>
</project>
```

---

## 🟢 Backend - Node Services

### Cấu Trúc Node Service (Realtime Gateway)

```
node-services/
│
└── realtime-gateway/                            # WebSocket server
    │
    ├── src/
    │   ├── server.ts                            # Main entry point
    │   │
    │   ├── config/                              # Configuration
    │   │   ├── index.ts
    │   │   ├── redis.config.ts
    │   │   └── kafka.config.ts
    │   │
    │   ├── handlers/                            # WebSocket handlers
    │   │   ├── MessageHandler.ts
    │   │   ├── PresenceHandler.ts
    │   │   └── NotificationHandler.ts
    │   │
    │   ├── services/                            # Business logic
    │   │   ├── ConnectionManager.ts
    │   │   ├── MessageRouter.ts
    │   │   └── PresenceTracker.ts
    │   │
    │   ├── middleware/                          # Middleware
    │   │   ├── AuthMiddleware.ts
    │   │   └── RateLimitMiddleware.ts
    │   │
    │   ├── events/                              # Event consumers
    │   │   ├── KafkaConsumer.ts
    │   │   └── RedisSubscriber.ts
    │   │
    │   ├── models/                              # Data models/types
    │   │   ├── Message.ts
    │   │   └── Connection.ts
    │   │
    │   └── utils/                               # Utilities
    │       ├── Logger.ts
    │       └── Validator.ts
    │
    ├── tests/
    │   ├── unit/
    │   └── integration/
    │
    ├── package.json
    ├── tsconfig.json
    ├── Dockerfile
    └── README.md
```

---

## 📱 Frontend - React Native

```
frontend/
│
├── src/
│   │
│   ├── app/                                     # Main app setup
│   │   ├── App.tsx                             # Root component
│   │   ├── navigation.tsx                      # Navigation config
│   │   └── providers.tsx                       # Context providers
│   │
│   ├── screens/                                 # Screen components
│   │   ├── auth/
│   │   │   ├── LoginScreen.tsx
│   │   │   ├── RegisterScreen.tsx
│   │   │   └── OtpScreen.tsx
│   │   │
│   │   ├── chat/
│   │   │   ├── ConversationListScreen.tsx
│   │   │   ├── ChatScreen.tsx
│   │   │   └── GroupChatScreen.tsx
│   │   │
│   │   ├── contacts/
│   │   │   ├── ContactsScreen.tsx
│   │   │   └── ContactDetailScreen.tsx
│   │   │
│   │   ├── profile/
│   │   │   ├── ProfileScreen.tsx
│   │   │   └── EditProfileScreen.tsx
│   │   │
│   │   └── story/
│   │       ├── StoryViewerScreen.tsx
│   │       └── CreateStoryScreen.tsx
│   │
│   ├── components/                              # Reusable components
│   │   ├── common/
│   │   │   ├── Button.tsx
│   │   │   ├── Input.tsx
│   │   │   ├── Avatar.tsx
│   │   │   └── LoadingSpinner.tsx
│   │   │
│   │   ├── chat/
│   │   │   ├── MessageBubble.tsx
│   │   │   ├── MessageInput.tsx
│   │   │   └── VoiceRecorder.tsx
│   │   │
│   │   └── story/
│   │       └── StoryCard.tsx
│   │
│   ├── services/                                # API & Business Logic
│   │   ├── api/
│   │   │   ├── client.ts                       # Axios instance
│   │   │   ├── authApi.ts
│   │   │   ├── userApi.ts
│   │   │   ├── messageApi.ts
│   │   │   └── mediaApi.ts
│   │   │
│   │   ├── websocket/
│   │   │   ├── WebSocketClient.ts
│   │   │   └── MessageHandler.ts
│   │   │
│   │   └── storage/
│   │       └── SecureStorage.ts
│   │
│   ├── store/                                   # State management (Zustand)
│   │   ├── authStore.ts
│   │   ├── chatStore.ts
│   │   ├── userStore.ts
│   │   └── index.ts
│   │
│   ├── hooks/                                   # Custom hooks
│   │   ├── useAuth.ts
│   │   ├── useChat.ts
│   │   ├── useWebSocket.ts
│   │   └── useKeyboard.ts
│   │
│   ├── utils/                                   # Utilities
│   │   ├── date.ts
│   │   ├── validators.ts
│   │   ├── formatting.ts
│   │   └── constants.ts
│   │
│   ├── types/                                   # TypeScript types
│   │   ├── models.ts
│   │   ├── api.ts
│   │   └── navigation.ts
│   │
│   ├── theme/                                   # Styling
│   │   ├── colors.ts
│   │   ├── typography.ts
│   │   └── spacing.ts
│   │
│   └── assets/                                  # Static assets
│       ├── images/
│       ├── icons/
│       └── fonts/
│
├── android/                                     # Android native code
├── ios/                                         # iOS native code
│
├── package.json
├── tsconfig.json
├── metro.config.js
├── babel.config.js
└── README.md
```

---

## 🐳 Docker & Infrastructure

```
docker/
│
├── docker-compose.yml                           # Development environment
│   # Services: postgres, redis, kafka, zookeeper
│
├── docker-compose.prod.yml                      # Production setup
│
├── init-db.sql                                  # Database initialization
│
└── services/                                    # Individual service configs
    ├── postgres/
    │   ├── Dockerfile
    │   └── postgresql.conf
    │
    ├── redis/
    │   ├── Dockerfile
    │   └── redis.conf
    │
    └── kafka/
        └── server.properties
```

### Docker Compose Example

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: vnalo_db
      POSTGRES_USER: vnalo_user
      POSTGRES_PASSWORD: vnalo_pass
    ports:
      - "5432:5432"
    volumes:
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092

volumes:
  postgres_data:
  redis_data:
```

---

## 📚 Documentation

```
docs/
│
├── architecture/                                # Architecture documentation
│   ├── system-overview.md
│   ├── microservices-design.md
│   ├── data-flow.md
│   └── diagrams/
│       ├── message-flow.md
│       └── deployment.md
│
├── api/                                         # API documentation
│   ├── auth-api.md
│   ├── messaging-api.md
│   ├── user-api.md
│   └── postman/
│       └── vnalo.postman_collection.json
│
├── database/                                    # Database documentation
│   ├── OTT_Zalo_Complete_Database_Schema.md
│   ├── OTT_Zalo_Database_Design_By_Service.md
│   └── migrations/
│
├── guides/                                      # Developer guides
│   ├── DEV1_CORE_MESSAGING_GUIDE.md
│   ├── DEV2_REALTIME_MEDIA_GUIDE.md
│   ├── DEV3_CONTENT_NOTIFICATION_GUIDE.md
│   ├── DEV4_MODERATION_ANALYTICS_GUIDE.md
│   ├── INITIAL_SETUP_GUIDE.md
│   └── FAQ_SETUP.md
│
├── deployment/                                  # Deployment guides
│   ├── aws-deployment.md
│   ├── kubernetes-setup.md
│   └── ci-cd-pipeline.md
│
└── PROJECT_SUMMARY.md                           # Project overview
```

---

## 📝 Quy Tắc Đặt Tên

### 1. Packages (Java)

```
✅ ĐÚNG:
vn.edu.hcmuaf.fit.ott.auth.controller
vn.edu.hcmuaf.fit.ott.messaging.service
vn.edu.hcmuaf.fit.ott.common.domain

❌ SAI:
com.vnalo.Auth.Controllers
vn.hcmuaf.OTT.service
```

**Quy tắc:**
- Lowercase only
- Reverse domain notation
- Meaningful package names

### 2. Classes (Java)

```
✅ ĐÚNG:
AuthController.java
UserServiceImpl.java
MessageRepository.java
LoginRequest.java

❌ SAI:
authcontroller.java
user_service_impl.java
IMessageRepository.java
```

**Quy tắc:**
- PascalCase
- Descriptive names
- Suffix theo mục đích: Controller, Service, Repository, Request, Response

### 3. Files & Folders

```
✅ ĐÚNG:
auth-service/
user-profile-screen.tsx
message-handler.ts

❌ SAI:
Auth_Service/
UserProfileScreen.tsx
messagehandler.ts
```

**Quy tắc:**
- kebab-case cho folders và files
- Descriptive names
- No abbreviations (trừ khi rất phổ biến)

### 4. Variables & Functions

**Java:**
```java
✅ ĐÚNG:
private String userName;
public void sendMessage() {}

❌ SAI:
private String UserName;
public void SendMessage() {}
```

**TypeScript:**
```typescript
✅ ĐÚNG:
const userId = '123';
const handleSubmit = () => {};

❌ SAI:
const user_id = '123';
const HandleSubmit = () => {};
```

**Quy tắc:**
- camelCase
- Descriptive names
- Boolean: isActive, hasPermission, canEdit

### 5. Constants

```java
✅ ĐÚNG:
public static final String API_BASE_URL = "http://api.vnalo.com";
public static final int MAX_RETRY_ATTEMPTS = 3;

❌ SAI:
public static final String apiBaseUrl = "http://api.vnalo.com";
public static final int max_retry = 3;
```

**Quy tắc:**
- UPPER_SNAKE_CASE
- Descriptive names

### 6. Database Tables & Columns

```sql
✅ ĐÚNG:
CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    phone_number VARCHAR(20),
    created_at TIMESTAMP
);

❌ SAI:
CREATE TABLE Users (
    userId UUID PRIMARY KEY,
    PhoneNumber VARCHAR(20),
    CreatedAt TIMESTAMP
);
```

**Quy tắc:**
- snake_case
- Plural for tables (users, messages)
- Singular for columns (user_id, message_text)

---

## ✅ Best Practices

### 1. Code Organization

- **Single Responsibility**: Mỗi class/file chỉ làm 1 việc
- **DRY Principle**: Don't Repeat Yourself
- **Separation of Concerns**: Tách biệt logic layers
- **Dependency Injection**: Sử dụng DI framework

### 2. Configuration Management

```yaml
# application.yml
spring:
  profiles:
    active: ${PROFILE:dev}
  
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/vnalo_db}
    username: ${DB_USER:vnalo_user}
    password: ${DB_PASS:vnalo_pass}
```

- Sử dụng environment variables
- Profile-specific configs (dev, staging, prod)
- Không commit sensitive data

### 3. Error Handling

```java
// Global exception handling
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(
        BusinessException ex
    ) {
        return ResponseEntity
            .status(ex.getStatus())
            .body(new ErrorResponse(ex.getMessage()));
    }
}
```

### 4. API Design

```java
// RESTful API standards
@RestController
@RequestMapping("/api/v1/users")
public class UserController {
    
    @GetMapping                         // GET /api/v1/users
    @PostMapping                        // POST /api/v1/users
    @GetMapping("/{id}")               // GET /api/v1/users/{id}
    @PutMapping("/{id}")               // PUT /api/v1/users/{id}
    @DeleteMapping("/{id}")            // DELETE /api/v1/users/{id}
}
```

**Standards:**
- Use HTTP methods correctly
- Versioning: /api/v1/
- Plural nouns: /users, /messages
- Nested resources: /users/{id}/messages

### 5. Testing Structure

```
src/test/java/
├── unit/                              # Unit tests
│   ├── service/
│   └── util/
├── integration/                       # Integration tests
│   └── controller/
└── e2e/                              # End-to-end tests
```

### 6. Logging

```java
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class AuthService {
    
    public void login(String phone) {
        log.info("Login attempt for phone: {}", phone);
        try {
            // business logic
            log.debug("User authenticated successfully");
        } catch (Exception e) {
            log.error("Login failed for phone: {}", phone, e);
            throw e;
        }
    }
}
```

**Log Levels:**
- `ERROR`: Errors, exceptions
- `WARN`: Warnings, deprecated usage
- `INFO`: Important business events
- `DEBUG`: Detailed diagnostic info

### 7. Git Workflow

```bash
# Branch naming
feature/auth-login
bugfix/message-sending-error
hotfix/security-patch
release/v1.0.0

# Commit messages
feat: add user registration endpoint
fix: resolve message duplication issue
docs: update API documentation
refactor: improve error handling
test: add unit tests for auth service
```

**Commit Message Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: feat, fix, docs, style, refactor, test, chore

---

## 🎯 Service Port Allocation

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| API Gateway | 8080 | HTTP | Main entry point |
| Auth Service | 8081 | HTTP | Authentication |
| User Service | 8082 | HTTP | User management |
| Messaging Service | 8083 | HTTP | Chat, messages |
| Media Service | 8084 | HTTP | File upload |
| Notification Service | 8085 | HTTP | Push notifications |
| Story Service | 8086 | HTTP | Stories, timeline |
| Group Service | 8087 | HTTP | Group chat |
| Call Service | 8088 | HTTP | Voice/video calls |
| AI Service | 8089 | HTTP | AI assistant |
| Moderation Service | 8090 | HTTP | Content moderation |
| Analytics Service | 8091 | HTTP | Analytics, logging |
| Search Service | 8092 | HTTP | Search functionality |
| Realtime Gateway | 9000 | WebSocket | Real-time connections |

---

## 📦 Dependencies Management

### Maven (Java)

```xml
<!-- Use dependency management in parent POM -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>${spring-boot.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### NPM (Node/React Native)

```json
{
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.76.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.0.0"
  }
}
```

---

## 🔐 Security Best Practices

1. **Environment Variables**
   - Không commit .env files
   - Sử dụng .env.example cho templates
   
2. **Secrets Management**
   - Sử dụng AWS Secrets Manager / HashiCorp Vault
   - Không hardcode credentials

3. **Authentication**
   - JWT tokens với expiration
   - Refresh token rotation
   - Rate limiting

4. **API Security**
   - HTTPS only
   - CORS configuration
   - Input validation
   - SQL injection prevention

---

## 📊 Monitoring & Observability

```
logs/                                  # Application logs
├── application.log                   # General logs
├── error.log                         # Error logs
└── access.log                        # Access logs

metrics/                               # Metrics collection
├── prometheus.yml                    # Prometheus config
└── grafana/                          # Grafana dashboards
```

---

## 🚀 Deployment Structure

```
k8s/
├── base/                             # Base configurations
│   ├── deployment.yml
│   ├── service.yml
│   └── configmap.yml
│
├── overlays/                         # Environment-specific
│   ├── dev/
│   │   └── kustomization.yml
│   ├── staging/
│   │   └── kustomization.yml
│   └── prod/
│       └── kustomization.yml
```

---

## 📚 Tài Liệu Tham Khảo

- [Spring Boot Best Practices](https://spring.io/guides)
- [React Native Best Practices](https://reactnative.dev/docs/getting-started)
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [12-Factor App](https://12factor.net/)
- [Microservices Patterns](https://microservices.io/patterns/index.html)

---

## 📞 Liên Hệ & Hỗ Trợ

- **Documentation**: `docs/` folder
- **Issues**: GitHub Issues
- **Team Chat**: Slack/Discord
- **Code Review**: Pull Requests

---

**📌 Note**: Document này nên được cập nhật thường xuyên khi có thay đổi trong cấu trúc dự án.

**Last Updated**: January 27, 2026
**Version**: 1.0.0
**Maintainers**: Development Team
