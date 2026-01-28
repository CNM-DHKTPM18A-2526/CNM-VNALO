# Backend README

## Spring Boot Microservices

### Services Overview

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| core-service | 8081 | 🚧 Development | Authentication, User Management, Social Features |
| messaging-service | 8082 | ⏳ Planned | Conversations, Messages, Chat |
| media-service | 8083 | ⏳ Planned | File Upload, Cloudinary, Stickers |
| content-service | 8084 | ⏳ Planned | Stories, Timeline Posts |
| notification-service | 8086 | ⏳ Planned | Push Notifications |
| moderation-service | 8087 | ⏳ Planned | Content Moderation, Reports |
| analytics-service | 8088 | ⏳ Planned | Analytics, Logs, Backups |

### Node.js Services

| Service | Port | Status | Description |
|---------|------|--------|-------------|
| realtime-gateway | 8085 | ⏳ Planned | WebSocket, Real-time messaging |

---

## 📁 Structure

```
backend/
├── java-services/          ← Spring Boot monorepo
│   ├── pom.xml             ← Parent POM
│   ├── common/             ← Shared libraries
│   └── services/           ← Microservices
│
└── node-services/          ← Node.js monorepo (NestJS)
    ├── package.json
    ├── apps/               ← Applications
    └── libs/               ← Shared libraries
```

---

## 🚀 Quick Start

### Prerequisites

- Java 17+
- Maven 3.8+
- Docker Desktop
- Node.js 20+ (for realtime-gateway)

### Build All Services

```bash
cd java-services
mvn clean install
```

### Build Specific Service

```bash
mvn clean install -pl services/core-service -am
```

### Run Service

```bash
# core-service
mvn spring-boot:run -pl services/core-service

# Or specific port
mvn spring-boot:run -pl services/core-service -Dspring-boot.run.arguments=--server.port=8081
```

### Run Tests

```bash
# All tests
mvn test

# Specific service
mvn test -pl services/core-service
```

---

## 🏗️ Technology Stack

### Spring Boot Services
- **Framework**: Spring Boot 3.2.1
- **Java**: 17 LTS
- **Database**: PostgreSQL 15
- **ORM**: Spring Data JPA / Hibernate
- **Security**: Spring Security + JWT
- **Cache**: Redis
- **Message Queue**: RabbitMQ
- **Build**: Maven

### Node.js Services
- **Framework**: NestJS 10
- **Runtime**: Node.js 20 LTS
- **WebSocket**: Socket.IO
- **Language**: TypeScript
- **Build**: npm/pnpm

---

## 📦 Common Modules

### common-domain
Shared domain entities, DTOs, and base classes

### common-security
JWT token provider, security filters, authentication

---

## 🔧 Development

### Adding New Service

1. Create service directory
```bash
mkdir -p services/new-service/src/main/java/vn/edu/hcmuaf/fit/ott/newservice
```

2. Create `pom.xml`
3. Add to parent POM modules
4. Create Application class
5. Configure `application.yml`

See [HOW_TO_CREATE_SERVICE.md](./HOW_TO_CREATE_SERVICE.md) for details.

---

## 🐳 Docker

Services can be containerized individually or run together:

```bash
# Start infrastructure
cd ../../docker
docker-compose up -d

# Build service image
cd ../backend/java-services
docker build -f ../../docker/services/core-service.Dockerfile -t core-service .
```

---

## 📝 API Documentation

- Swagger UI: http://localhost:8081/swagger-ui.html (when service running)
- Postman Collection: [docs/api/postman/](../../docs/api/postman/)

---

## 🧪 Testing

### Unit Tests
```bash
mvn test
```

### Integration Tests
```bash
mvn verify
```

### E2E Tests
```bash
cd ../../tests/e2e
npm test
```

---

## 📊 Database

### Connection Details
```
Host: localhost
Port: 5432
Database: ott_zalo
Username: postgres
Password: postgres
```

### Migrations
Located in: `docs/database/migrations/`

---

## 🚀 Deployment

### Build Production JARs
```bash
mvn clean package -DskipTests
```

JARs will be in `services/<service-name>/target/*.jar`

### Run Production
```bash
java -jar services/core-service/target/core-service-1.0.0-SNAPSHOT.jar
```

---

## 📚 Resources

- [Development Guide](../../docs/guides/DEVELOPMENT_GUIDE.md)
- [API Documentation](../../docs/api/)
- [Database Schema](../../docs/database/OTT_Zalo_Complete_Database_Schema.md)

---

## 👥 Team

- **Dev 1**: core-service
- **Dev 2**: realtime-gateway
- **Dev 3**: messaging-service
- **Dev 4**: media-service

---

## 📄 License

MIT
