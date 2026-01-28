# OTT Zalo Clone - Backend Setup

## Project Structure

```
cnm-zalo-clone/
├── backend/
│   └── java-services/          # Spring Boot workspace
│       ├── pom.xml             # Parent POM
│       ├── common/             # Shared libraries
│       │   ├── common-domain/
│       │   └── common-security/
│       └── services/           # Microservices (create your own)
│
├── docker/
│   ├── docker-compose.yml      # PostgreSQL, Redis, RabbitMQ
│   └── init-db.sql
│
└── docs/
```

## Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd cnm-zalo-clone
```

### 2. Start Infrastructure
```bash
cd docker
docker-compose up -d

# Verify
docker ps  # Should see postgres, redis, rabbitmq running
```

### 3. Open Project in IntelliJ
```
File → Open → backend/java-services/pom.xml
Select: "Open as Project"
Wait for Maven import
```

### 4. Create Your Service Module

See [HOW_TO_CREATE_SERVICE.md](./HOW_TO_CREATE_SERVICE.md) for detailed instructions.

## Tech Stack

- **Java**: 17 LTS
- **Spring Boot**: 3.2.1
- **Database**: PostgreSQL 15
- **Cache**: Redis 7
- **Message Queue**: RabbitMQ 3
- **Build Tool**: Maven 3.8+

## Available Services

The following services need to be created by team members:

| Service | Owner | Port | Description |
|---------|-------|------|-------------|
| core-service | Dev 1 | 8081 | Auth, User, Social |
| messaging-service | Dev 1 | 8082 | Conversations, Messages |
| media-service | Dev 2 | 8083 | Upload, Cloudinary, Stickers |
| content-service | Dev 3 | 8084 | Stories, Timeline |
| moderation-service | Dev 4 | 8087 | Reports, Admin |
| analytics-service | Dev 4 | 8088 | Logs, Stats, Backup |

## Development Workflow

1. Create your service module (see HOW_TO_CREATE_SERVICE.md)
2. Implement your business logic
3. Test locally
4. Commit & push to feature branch
5. Create Pull Request
6. Code review
7. Merge to main

## Common Commands

```bash
# Build all modules
mvn clean install

# Build specific module
mvn clean install -pl services/core-service -am

# Run specific service
mvn spring-boot:run -pl services/core-service

# Run tests
mvn test

# Skip tests during build
mvn clean install -DskipTests
```

## Database Access

```
Host: localhost
Port: 5432
Database: ott_zalo
Username: postgres
Password: postgres
```

## Redis Access

```
Host: localhost
Port: 6379
```

## RabbitMQ

```
AMQP: localhost:5672
Management UI: http://localhost:15672
Username: admin
Password: admin
```

## Documentation

- [OTT Zalo Complete Database Schema](../docs/OTT_Zalo_Complete_Database_Schema.md)
- [OTT Zalo Database Documentation](../docs/OTT_Zalo_Database_Documentation.md)
- [Backend Implementation Guide](../docs/BACKEND_IMPLEMENTATION_GUIDE.md)

## Need Help?

- Check documentation in `docs/` folder
- Ask team leader (Dev 1)
- Review existing code in `common/` modules

## Next Steps

1. Read HOW_TO_CREATE_SERVICE.md
2. Create your service module
3. Start implementing features
4. Follow your individual guide in docs/guides/
