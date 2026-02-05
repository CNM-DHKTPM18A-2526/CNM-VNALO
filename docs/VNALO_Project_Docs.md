# VNALO - AI Agent Project Documentation

> **Version**: 2.2  
> **Last Updated**: February 5, 2026  
> **Project**: VNALO - Enterprise Real-Time Messaging Platform  
> **Package**: `iuh.cnm.vnalo`

---

## 1. Project Overview

### 1.1 What is VNALO?

VNALO is an enterprise-grade real-time messaging platform inspired by Zalo. Developed as part of the CNM (Computer Networks and Communications) course at IUH (Industrial University of Ho Chi Minh City).

### 1.2 Quick Facts

| Attribute | Value |
|-----------|-------|
| **Project Name** | VNALO |
| **GroupId** | `iuh.cnm.vnalo` |
| **Main Package** | `iuh.cnm.vnalo.core_service` |
| **Language** | Java 21 |
| **Framework** | Spring Boot 3.4.2 |
| **Database** | PostgreSQL 16 |
| **Cache** | Redis 7 |
| **Message Queue** | Apache Kafka |
| **API Docs** | SpringDoc OpenAPI 2.8.4 |
| **JWT Library** | JJWT 0.12.6 |
| **Team Size** | 4 members |

---

## 2. Current Implementation Status

### 2.1 Core Service Summary

The `core-service` is the main backend service currently implemented:

| Component | Count | Details |
|-----------|-------|---------|
| **Controllers** | 4 | Auth, User, Friend, Block |
| **Services** | 5 | AuthService, **OtpService**, UserService, FriendService, BlockService |
| **Repositories** | 8 | Auth (3), Social (3), User (2) |
| **Entities** | 8 | Auth (3), Social (3), User (2) + BaseEntity |
| **DTOs** | 12 | 6 Request + 6 Response |
| **Enums** | 11 | AccountStatus, Gender, Visibility, etc. |
| **Config Classes** | 6 | Security, JWT, CORS, OpenAPI, **OtpConfig**, Firebase |
| **Security Classes** | 4 | JWT Filter, Provider, UserDetails |
| **Exception Handlers** | 3 | ApiException, ErrorCode (17 codes), GlobalHandler |

### 2.2 API Endpoints (27 Total)

#### Authentication (`/api/v1/auth`) - 7 endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register/send-otp` | ✨ Send OTP for registration |
| POST | `/register` | Register new account (with OTP) |
| POST | `/login` | Login with phone/password |
| POST | `/refresh` | Refresh access token |
| POST | `/logout` | Logout (revoke token) |
| POST | `/logout-all` | Logout from all devices |
| GET | `/otp/status` | ✨ Check OTP configuration status |

#### Users (`/api/v1/users`) - 6 endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/me` | Get current user profile |
| GET | `/{userId}` | Get user by ID |
| PATCH | `/me` | Update profile |
| GET | `/search` | Search users |
| GET | `/me/privacy` | Get privacy settings |
| PUT | `/me/privacy` | Update privacy settings |

#### Friends (`/api/v1/friends`) - 10 endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/requests` | Send friend request |
| GET | `/requests/incoming` | Get incoming requests |
| GET | `/requests/sent` | Get sent requests |
| POST | `/requests/{id}/accept` | Accept request |
| POST | `/requests/{id}/decline` | Decline request |
| DELETE | `/requests/{id}` | Cancel request |
| GET | `/` | Get friends list |
| DELETE | `/{friendId}` | Unfriend |
| GET | `/{userId}/status` | Check friendship status |
| GET | `/stats` | Get friend statistics |

#### Blocks (`/api/v1/blocks`) - 4 endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/{userId}` | Block user |
| DELETE | `/{userId}` | Unblock user |
| GET | `/` | Get blocked users list |
| GET | `/{userId}/status` | Check block status |

---

## 3. Database Entities

### 3.1 Auth Module (3 entities)

```
auth_account
├── id (UUID, PK)
├── phone (VARCHAR 20, UNIQUE)
├── password_hash (VARCHAR 255)
├── password_updated_at (TIMESTAMP)
├── status (ENUM: PENDING_VERIFICATION, ACTIVE, LOCKED, DISABLED)
├── last_login_at (TIMESTAMP)
├── created_at, updated_at

auth_refresh_token
├── token_id (UUID, PK)
├── account_id (UUID, FK)
├── token_hash (VARCHAR 64)
├── device_id (VARCHAR 100)
├── expires_at (TIMESTAMP)
├── revoked_at (TIMESTAMP)
├── created_at

auth_otp
├── otp_id (UUID, PK)
├── account_id (UUID)
├── phone (VARCHAR 20)
├── otp_code (VARCHAR 6)
├── purpose (ENUM)
├── expires_at, verified_at
├── attempts, is_used
```

### 3.2 User Module (2 entities)

```
user_profile
├── id (UUID, PK = account_id)
├── display_name (VARCHAR 100)
├── avatar_url, cover_url (VARCHAR 500)
├── gender (ENUM: MALE, FEMALE, UNKNOWN)
├── dob (DATE)
├── bio (VARCHAR 500)
├── status_message (VARCHAR 200)
├── status_message_type (ENUM)
├── qr_code_url (VARCHAR 500)
├── is_verified (BOOLEAN)
├── created_at, updated_at

user_privacy_setting
├── user_id (UUID, PK)
├── profile_visibility, dob_visibility, phone_visibility (ENUM)
├── allow_friend_requests, show_online_status (BOOLEAN)
├── allow_calling_type (ENUM)
└── ...
```

### 3.3 Social Module (3 entities)

```
friend_request
├── request_id (UUID, PK)
├── user_id_from, user_id_to (UUID)
├── message (VARCHAR 200)
├── source (ENUM: SEARCH, CONTACT_SYNC, QR_CODE, GROUP, PHONE_NUMBER)
├── status (ENUM: PENDING, ACCEPTED, DECLINED, CANCELED)
├── created_at, responded_at

friendship
├── friendship_id (UUID, PK)
├── user_id_from, user_id_to (UUID)
├── source (ENUM)
├── nickname_from, nickname_to (VARCHAR 50)
├── created_at

block_list
├── block_id (UUID, PK)
├── user_id, blocked_user_id (UUID)
├── block_messages, block_calls, block_and_hide_logs (BOOLEAN)
├── created_at
```

---

## 4. Configuration

### 4.1 Application Properties

```yaml
# application.yml
spring:
  application.name: core-service
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:5432/${DB_NAME:vnalo_core}
    username/password: postgres
  jpa:
    hibernate.ddl-auto: validate (prod) / update (dev)
    open-in-view: false
  flyway:
    enabled: true (prod) / false (dev)
  profiles.active: dev

server:
  port: 8081
  servlet.context-path: /api/v1

jwt:
  secret: ${JWT_SECRET}
  access-token-expiration: 86400000 (24h)
  refresh-token-expiration: 604800000 (7d)

# OTP Configuration (NEW)
otp:
  enabled: ${OTP_ENABLED:true}       # Set false for dev
  expiration-minutes: 5
  max-attempts: 3
  rate-limit:
    requests-per-hour: 5
    cooldown-seconds: 60
  test-mode:
    enabled: ${OTP_TEST_MODE:false}  # Use mock OTP "123456"
    mock-otp: "123456"
```

### 4.2 Profiles

| Profile | Database | Flyway | OTP | Redis/Kafka |
|---------|----------|--------|-----|-------------|
| **dev** | PostgreSQL, DDL auto-update | Disabled | **Disabled** | Disabled |
| **test** | H2 in-memory | Disabled | Test mode | Disabled |
| **prod** | PostgreSQL, DDL validate | Enabled | **Enabled** | Enabled |

---

## 5. Technology Stack

### 5.1 Dependencies

| Category | Library | Version |
|----------|---------|---------|
| **Framework** | Spring Boot | 3.4.2 |
| **Security** | Spring Security | 6.x |
| **Database** | PostgreSQL Driver | 42.x |
| **ORM** | Spring Data JPA | 3.x |
| **Migration** | Flyway | 9.x |
| **Cache** | Spring Data Redis | 3.x |
| **Messaging** | Spring Kafka | 3.x |
| **JWT** | JJWT (io.jsonwebtoken) | 0.12.6 |
| **API Docs** | SpringDoc OpenAPI | 2.8.4 |
| **Utilities** | Lombok | 1.18.x |
| **Phone Validation** | libphonenumber | 8.13.52 |
| **Testing** | Testcontainers | 1.x |

### 5.2 Build Configuration

```xml
<groupId>iuh.cnm.vnalo</groupId>
<artifactId>core-service</artifactId>
<version>1.0.0-SNAPSHOT</version>
<java.version>21</java.version>
<parent>spring-boot-starter-parent:3.4.2</parent>
```

---

## 6. Project Structure

```
backend/java-services/services/core-service/
├── pom.xml
├── src/main/java/iuh/cnm/vnalo/core_service/
│   ├── CoreServiceApplication.java
│   ├── config/
│   │   ├── CorsConfig.java
│   │   ├── JwtConfig.java
│   │   ├── OpenApiConfig.java
│   │   └── SecurityConfig.java
│   ├── controller/
│   │   ├── AuthController.java      # 5 endpoints
│   │   ├── UserController.java      # 6 endpoints
│   │   ├── FriendController.java    # 10 endpoints
│   │   └── BlockController.java     # 4 endpoints
│   ├── service/
│   │   ├── AuthService.java
│   │   ├── UserService.java
│   │   ├── FriendService.java
│   │   └── BlockService.java
│   ├── repository/
│   │   ├── auth/ (3 repos)
│   │   ├── social/ (3 repos)
│   │   └── user/ (2 repos)
│   ├── model/
│   │   ├── entity/ (8 entities)
│   │   ├── dto/request/ (5 DTOs)
│   │   ├── dto/response/ (5 DTOs)
│   │   └── enums/ (11 enums)
│   ├── security/
│   │   ├── JwtTokenProvider.java
│   │   ├── JwtAuthenticationFilter.java
│   │   ├── UserDetailsServiceImpl.java
│   │   └── UserPrincipal.java
│   └── exception/
│       ├── ApiException.java
│       ├── ErrorCode.java
│       └── GlobalExceptionHandler.java
└── src/main/resources/
    ├── application.yml
    └── db/migration/
```

---

## 7. Improvement Recommendations

### 7.1 High Priority

| Area | Current | Status |
|------|---------|--------|
| **OTP Verification** | ✅ Implemented | OtpService, OtpConfig with toggle |
| **Unit Tests** | No test files found | ⏳ Needed |
| **Input Validation** | Basic @Valid | ⏳ Add phone validators |
| **Rate Limiting** | OTP has rate limiting | ⏳ Extend to other APIs |
| **Password Policy** | ✅ Implemented | Uppercase + lowercase + number required |

### 7.2 Medium Priority

| Area | Current | Recommendation |
|------|---------|----------------|
| **Caching** | Redis configured but not used | Implement caching for user profiles |
| **Events** | Kafka configured but not used | Publish events for user actions |
| **Logging** | Basic SLF4J | Add structured logging with correlation IDs |
| **API Versioning** | URL-based `/api/v1` | Document versioning strategy |
| **Error Responses** | ErrorCode enum | Add i18n support for error messages |

### 7.3 Future Enhancements

| Feature | Description |
|---------|-------------|
| **Contact Sync** | Sync phone contacts to find friends |
| **Avatar Upload** | Media service integration for avatars |
| **QR Code Generation** | Generate personal QR codes |
| **Account Deletion** | GDPR-compliant account deletion |
| **Login History** | Track login devices and locations |

---

## 8. Quick Reference

### 8.1 Running the Service

```bash
# Development mode
cd backend/java-services/services/core-service
mvn spring-boot:run

# With Docker PostgreSQL
docker run -d --name vnalo-db \
  -e POSTGRES_DB=vnalo_core \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 postgres:16

# Access Swagger UI
http://localhost:8081/api/v1/swagger-ui.html
```

### 8.2 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | vnalo_core | Database name |
| `DB_USER` | postgres | Database user |
| `DB_PASS` | postgres | Database password |
| `JWT_SECRET` | (base64 key) | JWT signing key |
| `REDIS_HOST` | localhost | Redis host (prod) |
| `KAFKA_SERVERS` | localhost:9092 | Kafka brokers (prod) |

---

## 9. Code Conventions

### 9.1 Package Structure
- Base package: `iuh.cnm.vnalo.core_service`
- Layers: `controller`, `service`, `repository`, `model`, `config`, `security`, `exception`

### 9.2 Naming Conventions
- Classes: PascalCase (`AuthController`, `UserService`)
- Methods: camelCase (`sendFriendRequest`, `acceptRequest`)
- Entities: Singular (`AuthAccount`, `UserProfile`)
- Tables: snake_case (`auth_account`, `friend_request`)

### 9.3 API Design
- Base path: `/api/v1`
- Resource-based: `/users`, `/friends`, `/blocks`, `/auth`
- Standard response: `ApiResponse<T>` wrapper
- Pagination: Spring `Pageable` with default size 20

---

## Changelog

### v2.2 (February 5, 2026)
- ✅ Added Flyway migrations V3-V6:
  - V3: auth_account enhancements (firebase_uid, locked_until, failed_login_count)
  - V4: auth_refresh_token device info (platform, ip_address, user_agent)
  - V5: social enhancements (block reason/note, friendship favorites/hidden)
  - V6: user_profile enhancements (region, is_official_account, follower_count)
- ✅ Updated Docker to VNALO naming convention
- ✅ Replaced RabbitMQ with Kafka in docker-compose.yml
- ✅ Updated VNALO_Complete_Database_Schema.md with Option A (current implementation)

### v2.1 (February 4, 2026)
- ✅ Added OTP system with toggle feature (OtpConfig, OtpService)
- ✅ Added 2 new auth endpoints (/register/send-otp, /otp/status)
- ✅ Added OTP rate limiting and test mode
- ✅ Updated ErrorCode with OTP-related codes
- ✅ Password policy implemented (uppercase + lowercase + number)

### v2.0 (January 29, 2026)
- Initial core-service implementation
- Auth, User, Friend, Block modules

---

**End of Document**

> Version: 2.2 | Last Updated: February 5, 2026
