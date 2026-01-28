# Initial Project Setup - Step-by-Step Guide

> **Who**: Dev 1 (Team Leader) sets up initial structure  
> **When**: Day 1, before other developers start  
> **Time**: ~2-3 hours

---

## 🎯 Overview

**Đúng vậy!** Nhóm trưởng (Dev 1) setup project structure sẵn, sau đó các thành viên khác clone về.

### Setup Flow

```
Day 1 Morning (Dev 1 only):
├── 1. Create Git repository
├── 2. Setup Maven monorepo structure
├── 3. Create all modules (empty)
├── 4. Setup common libraries
├── 5. Configure Docker Compose
├── 6. Push to GitHub
└── 7. Share with team

Day 1 Afternoon (All developers):
├── 1. Clone repository
├── 2. Open in IntelliJ
├── 3. Setup database
└── 4. Start coding their services
```

---

## 📋 Dev 1 (Team Leader) - Initial Setup

### Step 1: Create Git Repository (10 minutes)

```bash
# 1. On GitHub/GitLab, create new repository
Repository name: cnm-zalo-backend
Description: OTT Zalo Clone - Microservices Backend
Visibility: Private
✅ Initialize with README
✅ Add .gitignore (Java)

# 2. Clone to local
git clone https://github.com/your-org/cnm-zalo-backend.git
cd cnm-zalo-backend
```

### Step 2: Create Project Structure (30 minutes)

#### Option A: Manual Setup

```bash
# Create directory structure
mkdir -p common/common-domain/src/main/java/vn/edu/hcmuaf/fit/ott/common/domain
mkdir -p common/common-domain/src/main/resources
mkdir -p common/common-security/src/main/java/vn/edu/hcmuaf/fit/ott/common/security
mkdir -p common/common-security/src/main/resources
mkdir -p common/common-messaging/src/main/java/vn/edu/hcmuaf/fit/ott/common/messaging
mkdir -p common/common-messaging/src/main/resources

mkdir -p services/core-service/src/main/java/vn/edu/hcmuaf/fit/ott/core
mkdir -p services/core-service/src/main/resources
mkdir -p services/messaging-service/src/main/java/vn/edu/hcmuaf/fit/ott/messaging
mkdir -p services/messaging-service/src/main/resources
mkdir -p services/media-service/src/main/java/vn/edu/hcmuaf/fit/ott/media
mkdir -p services/media-service/src/main/resources
mkdir -p services/content-service/src/main/java/vn/edu/hcmuaf/fit/ott/content
mkdir -p services/content-service/src/main/resources
mkdir -p services/realtime-gateway/src/main/java/vn/edu/hcmuaf/fit/ott/gateway
mkdir -p services/realtime-gateway/src/main/resources
mkdir -p services/notification-service/src/main/java/vn/edu/hcmuaf/fit/ott/notification
mkdir -p services/notification-service/src/main/resources
mkdir -p services/moderation-service/src/main/java/vn/edu/hcmuaf/fit/ott/moderation
mkdir -p services/moderation-service/src/main/resources
mkdir -p services/analytics-service/src/main/java/vn/edu/hcmuaf/fit/ott/analytics
mkdir -p services/analytics-service/src/main/resources

mkdir -p docker
mkdir -p scripts
```

#### Option B: Use Setup Script (Recommended)

Create `scripts/setup-project.sh`:

```bash
#!/bin/bash

echo "🚀 Setting up OTT Zalo Backend project structure..."

# Base directories
mkdir -p common services docker scripts docs

# Common modules
for module in common-domain common-security common-messaging; do
    echo "Creating common/$module..."
    mkdir -p "common/$module/src/main/java/vn/edu/hcmuaf/fit/ott/common/${module##common-}"
    mkdir -p "common/$module/src/main/resources"
    mkdir -p "common/$module/src/test/java"
done

# Service modules
services=(
    "core-service:core"
    "messaging-service:messaging"
    "media-service:media"
    "content-service:content"
    "realtime-gateway:gateway"
    "notification-service:notification"
    "moderation-service:moderation"
    "analytics-service:analytics"
)

for service in "${services[@]}"; do
    IFS=':' read -r name package <<< "$service"
    echo "Creating services/$name..."
    mkdir -p "services/$name/src/main/java/vn/edu/hcmuaf/fit/ott/$package"
    mkdir -p "services/$name/src/main/resources"
    mkdir -p "services/$name/src/test/java"
done

echo "✅ Project structure created!"
```

Run it:
```bash
chmod +x scripts/setup-project.sh
./scripts/setup-project.sh
```

### Step 3: Create Parent POM (20 minutes)

Create `pom.xml` in project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.1</version>
        <relativePath/>
    </parent>

    <groupId>vn.edu.hcmuaf.fit.ott</groupId>
    <artifactId>cnm-zalo-backend</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <name>OTT Zalo Clone Backend</name>

    <properties>
        <java.version>17</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <jwt.version>0.12.3</jwt.version>
        <cloudinary.version>1.36.0</cloudinary.version>
    </properties>

    <modules>
        <module>common/common-domain</module>
        <module>common/common-security</module>
        <module>common/common-messaging</module>
        <module>services/core-service</module>
        <module>services/messaging-service</module>
        <module>services/media-service</module>
        <module>services/content-service</module>
        <module>services/realtime-gateway</module>
        <module>services/notification-service</module>
        <module>services/moderation-service</module>
        <module>services/analytics-service</module>
    </modules>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>vn.edu.hcmuaf.fit.ott</groupId>
                <artifactId>common-domain</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>vn.edu.hcmuaf.fit.ott</groupId>
                <artifactId>common-security</artifactId>
                <version>${project.version}</version>
            </dependency>
            <dependency>
                <groupId>vn.edu.hcmuaf.fit.ott</groupId>
                <artifactId>common-messaging</artifactId>
                <version>${project.version}</version>
            </dependency>

            <dependency>
                <groupId>io.jsonwebtoken</groupId>
                <artifactId>jjwt-api</artifactId>
                <version>${jwt.version}</version>
            </dependency>
            <dependency>
                <groupId>io.jsonwebtoken</groupId>
                <artifactId>jjwt-impl</artifactId>
                <version>${jwt.version}</version>
            </dependency>
            <dependency>
                <groupId>io.jsonwebtoken</groupId>
                <artifactId>jjwt-jackson</artifactId>
                <version>${jwt.version}</version>
            </dependency>

            <dependency>
                <groupId>com.cloudinary</groupId>
                <artifactId>cloudinary-http44</artifactId>
                <version>${cloudinary.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

### Step 4: Create Module POMs (40 minutes)

**Template for common modules** (`common/common-domain/pom.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>vn.edu.hcmuaf.fit.ott</groupId>
        <artifactId>cnm-zalo-backend</artifactId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>common-domain</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>jakarta.persistence</groupId>
            <artifactId>jakarta.persistence-api</artifactId>
        </dependency>
    </dependencies>
</project>
```

**Template for service modules** (`services/core-service/pom.xml`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>vn.edu.hcmuaf.fit.ott</groupId>
        <artifactId>cnm-zalo-backend</artifactId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>core-service</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-domain</artifactId>
        </dependency>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>

        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

### Step 5: Setup Docker Compose (20 minutes)

Create `docker/docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: ott-postgres
    environment:
      POSTGRES_DB: ott_zalo
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - ott-network

  redis:
    image: redis:7-alpine
    container_name: ott-redis
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - ott-network

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: ott-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin
    ports:
      - "5672:5672"   # AMQP
      - "15672:15672" # Management UI
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - ott-network

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:

networks:
  ott-network:
    driver: bridge
```

Create `docker/init-db.sql`:

```sql
-- Create schemas
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS social;
CREATE SCHEMA IF NOT EXISTS messaging;
CREATE SCHEMA IF NOT EXISTS media;
CREATE SCHEMA IF NOT EXISTS content;
CREATE SCHEMA IF NOT EXISTS moderation;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Grant permissions
GRANT ALL PRIVILEGES ON SCHEMA auth TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA users TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA social TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA messaging TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA media TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA content TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA moderation TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO postgres;
```

### Step 6: Create .gitignore (5 minutes)

```gitignore
# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties

# IntelliJ IDEA
.idea/
*.iml
*.iws
*.ipr
out/

# Eclipse
.classpath
.project
.settings/

# VS Code
.vscode/

# macOS
.DS_Store

# Windows
Thumbs.db

# Application
logs/
*.log
application-local.yml
application-secret.yml

# Docker
docker/data/

# Other
node_modules/
*.class
```

### Step 7: Create README (10 minutes)

```markdown
# OTT Zalo Clone - Backend

Microservices backend for OTT Zalo messaging platform.

## Tech Stack
- Java 17
- Spring Boot 3.2.1
- PostgreSQL 15
- Redis 7
- RabbitMQ 3

## Project Structure
```
cnm-zalo-backend/
├── common/                 # Shared libraries
├── services/               # 8 microservices
├── docker/                 # Docker Compose
└── docs/                   # Documentation
```

## Quick Start

### Prerequisites
- Java 17 JDK
- Maven 3.8+
- Docker Desktop
- IntelliJ IDEA

### Setup
1. Clone repository
2. Start infrastructure: `cd docker && docker-compose up -d`
3. Open in IntelliJ: File → Open → pom.xml
4. Build: `mvn clean install`
5. Run core-service

## Team
- Dev 1: core-service, messaging-service
- Dev 2: realtime-gateway, media-service
- Dev 3: content-service, notification-service
- Dev 4: moderation-service, analytics-service
```

### Step 8: Push to GitHub (5 minutes)

```bash
git add .
git commit -m "Initial project setup

- Maven monorepo structure
- 11 modules (3 common + 8 services)
- Docker Compose (PostgreSQL, Redis, RabbitMQ)
- Parent POM with Spring Boot 3.2.1
- Java 17 configuration"

git push origin main
```

### Step 9: Share with Team (5 minutes)

Send to team chat:
```
✅ Project setup complete!

Repository: https://github.com/your-org/cnm-zalo-backend

Next steps for everyone:
1. Clone: git clone <url>
2. Open IntelliJ: File → Open → pom.xml
3. Wait for Maven import
4. Read your guide:
   - Dev 2: docs/guides/DEV2_REALTIME_MEDIA_GUIDE.md
   - Dev 3: docs/guides/DEV3_CONTENT_NOTIFICATION_GUIDE.md
   - Dev 4: docs/guides/DEV4_MODERATION_ANALYTICS_GUIDE.md

Meeting at 2 PM to discuss!
```

---

## 👥 Other Developers - Clone & Setup

### Dev 2, 3, 4 (Day 1 Afternoon)

#### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/cnm-zalo-backend.git
cd cnm-zalo-backend
```

#### Step 2: Open in IntelliJ

```
1. Open IntelliJ IDEA
2. File → Open
3. Select cnm-zalo-backend/pom.xml
4. Click "Open as Project"
5. Wait for Maven import (5-10 minutes)
```

#### Step 3: Verify Setup

```bash
# Build all modules
mvn clean install

# Should see:
# [INFO] BUILD SUCCESS
# [INFO] Total time: 1-2 minutes
```

#### Step 4: Start Infrastructure

```bash
cd docker
docker-compose up -d

# Verify
docker ps
# Should see: postgres, redis, rabbitmq running
```

#### Step 5: Start Coding!

Follow your individual guide:
- **Dev 2**: Start with realtime-gateway
- **Dev 3**: Start with content-service
- **Dev 4**: Help with database migration scripts

---

## 📋 Checklist for Dev 1

### Before Pushing to Git
- [ ] Parent POM created with correct versions
- [ ] All 11 module POMs created
- [ ] Directory structure matches design
- [ ] Docker Compose tested locally
- [ ] PostgreSQL schemas created
- [ ] Redis connection works
- [ ] RabbitMQ management UI accessible
- [ ] README.md complete
- [ ] .gitignore configured
- [ ] `mvn clean install` succeeds
- [ ] All documentation in docs/guides/

### After Pushing
- [ ] Team members can clone
- [ ] Team members can build
- [ ] Team members can run infrastructure
- [ ] Kickoff meeting scheduled

---

## 🎯 Summary

| Who | What | When |
|-----|------|------|
| **Dev 1 (Leader)** | Setup entire project structure | Day 1 morning (2-3 hours) |
| **Dev 2, 3, 4** | Clone & verify setup | Day 1 afternoon (30 min) |
| **All** | Start coding their services | Day 1 afternoon onwards |

**Key Point**: Dev 1 làm setup 1 lần, push lên Git, các developer khác clone về và bắt đầu code ngay!

---

*See individual guides for next steps after setup complete*
