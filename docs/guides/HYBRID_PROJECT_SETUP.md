# Hybrid Project Setup Guide - Complete Structure

> **Architecture**: Node.js (2 services) + Spring Boot (5 services)  
> **Setup Time**: ~3 hours (Dev 1)

---

## 📁 Final Project Structure

```
cnm-zalo-clone/                           ← Root Git repository
│
├── backend/                              ← Backend workspace
│   │
│   ├── node-services/                    ← Node.js workspace (NestJS monorepo)
│   │   ├── package.json                  ← Root package.json
│   │   ├── tsconfig.json
│   │   ├── nest-cli.json                 ← Monorepo config
│   │   │
│   │   ├── apps/                         ← NestJS applications
│   │   │   ├── realtime-gateway/
│   │   │   │   ├── src/
│   │   │   │   │   ├── main.ts
│   │   │   │   │   ├── app.module.ts
│   │   │   │   │   └── gateway/
│   │   │   │   └── tsconfig.app.json
│   │   │   │
│   │   │   └── messaging-service/
│   │   │       ├── src/
│   │   │       │   ├── main.ts
│   │   │       │   ├── app.module.ts
│   │   │       │   ├── conversation/
│   │   │       │   └── message/
│   │   │       └── tsconfig.app.json
│   │   │
│   │   ├── libs/                         ← Shared libraries
│   │   │   ├── common/
│   │   │   │   └── src/
│   │   │   │       ├── dto/
│   │   │   │       └── entities/
│   │   │   └── database/
│   │   │       └── src/
│   │   │           └── prisma/
│   │   │
│   │   └── node_modules/
│   │
│   └── java-services/                    ← Spring Boot workspace (Maven monorepo)
│       ├── pom.xml                       ← Parent POM
│       │
│       ├── common/                       ← Shared libraries
│       │   ├── common-domain/
│       │   │   ├── pom.xml
│       │   │   └── src/main/java/.../domain/
│       │   └── common-security/
│       │       ├── pom.xml
│       │       └── src/main/java/.../security/
│       │
│       └── services/                     ← Spring Boot services (modules)
│           ├── core-service/             ← Module 1
│           │   ├── pom.xml               ← Child POM
│           │   └── src/
│           │       ├── main/java/.../core/
│           │       │   ├── CoreServiceApplication.java
│           │       │   ├── auth/
│           │       │   ├── user/
│           │       │   └── social/
│           │       └── main/resources/
│           │           └── application.yml
│           │
│           ├── media-service/            ← Module 2
│           │   ├── pom.xml
│           │   └── src/...
│           │
│           ├── content-service/          ← Module 3
│           │   ├── pom.xml
│           │   └── src/...
│           │
│           ├── moderation-service/       ← Module 4
│           │   ├── pom.xml
│           │   └── src/...
│           │
│           └── analytics-service/        ← Module 5
│               ├── pom.xml
│               └── src/...
│
├── frontend/                             ← Frontend apps
│   ├── mobile-app/                       ← React Native
│   └── web-app/                          ← React
│
├── docker/
│   ├── docker-compose.yml
│   └── init-db.sql
│
├── docs/                                 ← Documentation
│   ├── OTT_Zalo_Complete_Database_Schema.md
│   └── guides/
│
├── .gitignore
└── README.md
```

---

## ✅ TRẢ LỜI CÂU HỎI

### Có phải mỗi service Spring Boot là 1 project module không?

**✅ ĐÚNG VẬY!** - Mỗi Spring Boot service là 1 **Maven Module** trong Maven Monorepo

### Cấu Trúc Chi Tiết

```
java-services/ (Maven Monorepo)
│
├── pom.xml                    ← PARENT POM (packaging: pom)
│   └── <modules>
│       ├── common-domain      ← Library module
│       ├── common-security    ← Library module
│       ├── core-service       ← Spring Boot module
│       ├── media-service      ← Spring Boot module
│       └── ... (5 modules)
│
├─ common/
│  └─ common-domain/
│     └── pom.xml              ← CHILD POM (packaging: jar)
│         └── <parent>cnm-zalo-backend</parent>
│
└─ services/
   └─ core-service/
      └── pom.xml              ← CHILD POM (packaging: jar)
          └── <parent>cnm-zalo-backend</parent>
          └── <build>
              └── spring-boot-maven-plugin
```

### Key Points

| Aspect | Details |
|--------|---------|
| **1 IntelliJ Project** | java-services/ (opened as Maven project) |
| **1 Parent POM** | `java-services/pom.xml` |
| **7 Module POMs** | 2 common + 5 services |
| **Each Service** | Independent Spring Boot app with own `main()` |
| **Shared Dependencies** | Managed in parent `<dependencyManagement>` |
| **Build** | `mvn clean install` builds all 7 modules |
| **Run** | Each service runs independently on different ports |

---

## 🚀 Step-by-Step Setup (Dev 1)

### Phase 1: Create Node.js Workspace (30 minutes)

```bash
# 1. Create root directory
mkdir cnm-zalo-clone
cd cnm-zalo-clone
mkdir backend
cd backend

# 2. Create Node.js workspace
mkdir node-services
cd node-services

# 3. Initialize NestJS monorepo
npm i -g @nestjs/cli
nest new . --skip-git

# 4. Generate services
nest generate app realtime-gateway
nest generate app messaging-service

# 5. Generate shared libraries
nest generate library common
nest generate library database

# 6. Install dependencies
npm install @nestjs/websockets socket.io
npm install @nestjs/typeorm typeorm pg
npm install @nestjs/microservices amqplib
npm install @nestjs/jwt passport-jwt
npm install ioredis
npm install @prisma/client
npm install -D prisma

# 7. Verify structure
tree -L 2
```

**Result:**
```
node-services/
├── apps/
│   ├── realtime-gateway/
│   └── messaging-service/
├── libs/
│   ├── common/
│   └── database/
├── package.json           ← All deps here
└── nest-cli.json          ← Monorepo config
```

### Phase 2: Create Spring Boot Workspace (60 minutes)

```bash
# Back to backend/
cd ../

# 1. Create java-services directory
mkdir java-services
cd java-services

# 2. Create parent POM
```

**Create `java-services/pom.xml`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
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

    <properties>
        <java.version>17</java.version>
    </properties>

    <modules>
        <!-- Common Libraries -->
        <module>common/common-domain</module>
        <module>common/common-security</module>
        
        <!-- Spring Boot Services -->
        <module>services/core-service</module>
        <module>services/media-service</module>
        <module>services/content-service</module>
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
        </dependencies>
    </dependencyManagement>
</project>
```

**Create directory structure:**

```bash
# 3. Create directories
mkdir -p common/common-domain/src/main/java/vn/edu/hcmuaf/fit/ott/common/domain
mkdir -p common/common-security/src/main/java/vn/edu/hcmuaf/fit/ott/common/security

mkdir -p services/core-service/src/main/java/vn/edu/hcmuaf/fit/ott/core
mkdir -p services/core-service/src/main/resources

mkdir -p services/media-service/src/main/java/vn/edu/hcmuaf/fit/ott/media
mkdir -p services/media-service/src/main/resources

mkdir -p services/content-service/src/main/java/vn/edu/hcmuaf/fit/ott/content
mkdir -p services/content-service/src/main/resources

mkdir -p services/moderation-service/src/main/java/vn/edu/hcmuaf/fit/ott/moderation
mkdir -p services/moderation-service/src/main/resources

mkdir -p services/analytics-service/src/main/java/vn/edu/hcmuaf/fit/ott/analytics
mkdir -p services/analytics-service/src/main/resources
```

**Create module POMs (example for core-service):**

`services/core-service/pom.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
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

**Repeat for all 5 services** (media, content, moderation, analytics)

### Phase 3: Create Docker Setup (20 minutes)

```bash
# Back to root
cd ../../..  # Now in cnm-zalo-clone/

mkdir docker
cd docker
```

**Create `docker-compose.yml`:**

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

  redis:
    image: redis:7-alpine
    container_name: ott-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: ott-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
```

---

## 🖥️ Opening Projects in IntelliJ

### Option 1: Two IntelliJ Windows (Recommended)

**Window 1: Node.js Services**
```
File → Open → cnm-zalo-clone/backend/node-services/
Type: Auto-detect (will recognize as Node.js project)
```

**Window 2: Spring Boot Services**
```
File → Open → cnm-zalo-clone/backend/java-services/pom.xml
Select: "Open as Project"
Wait for Maven import
```

### Option 2: Single Window (if you prefer)

```
File → Open → cnm-zalo-clone/
```

IntelliJ will recognize:
- `backend/java-services/` as Maven project
- `backend/node-services/` as Node.js project

---

## 🏃 Running Services

### Terminal Setup (Recommended Layout)

```
Terminal 1: Infrastructure
  cd docker
  docker-compose up

Terminal 2: Node.js - realtime-gateway
  cd backend/node-services
  npm run start:dev realtime-gateway

Terminal 3: Node.js - messaging-service  
  cd backend/node-services
  npm run start:dev messaging-service

Terminal 4: Spring Boot - core-service
  cd backend/java-services
  mvn spring-boot:run -pl services/core-service

Terminal 5: Spring Boot - media-service
  mvn spring-boot:run -pl services/media-service

... (and so on)
```

### IntelliJ Run Configurations

**For Node.js services:**
```
Run → Edit Configurations → + → npm
Script: start:dev realtime-gateway
Package.json: backend/node-services/package.json
```

**For Spring Boot services:**
```
Run → Edit Configurations → + → Spring Boot
Main class: CoreServiceApplication
Module: core-service
```

---

## 📊 Service Port Mapping

| Service | Type | Port | URL |
|---------|------|------|-----|
| **realtime-gateway** | Node.js | 8085 | http://localhost:8085 |
| **messaging-service** | Node.js | 8082 | http://localhost:8082 |
| **core-service** | Spring Boot | 8081 | http://localhost:8081 |
| **media-service** | Spring Boot | 8083 | http://localhost:8083 |
| **content-service** | Spring Boot | 8084 | http://localhost:8084 |
| **moderation-service** | Spring Boot | 8087 | http://localhost:8087 |
| **analytics-service** | Spring Boot | 8088 | http://localhost:8088 |

---

## 🔧 Build Commands

### Build All Node.js Services

```bash
cd backend/node-services
npm run build  # Builds all apps in apps/
```

### Build All Spring Boot Services

```bash
cd backend/java-services
mvn clean install  # Builds all 7 modules
```

### Build Specific Service

```bash
# Node.js
npm run build realtime-gateway

# Spring Boot
mvn clean package -pl services/core-service -am
# -am = also make (builds dependencies)
```

---

## ✅ Verification Checklist

### After Setup Complete

- [ ] `backend/node-services/` has `apps/` and `libs/` folders
- [ ] `backend/java-services/pom.xml` lists 7 modules
- [ ] `docker-compose up` starts 3 containers
- [ ] IntelliJ recognizes both projects
- [ ] `npm run build` succeeds
- [ ] `mvn clean install` succeeds
- [ ] No red errors in IntelliJ
- [ ] All POMs valid

---

## 🎯 Summary

| Question | Answer |
|----------|--------|
| **Mỗi Spring Boot service là 1 module?** | ✅ Đúng! Each is a Maven module |
| **Bao nhiêu IntelliJ projects?** | 2 projects: node-services + java-services |
| **Cấu trúc thư mục?** | 2 monorepos: NestJS + Maven |
| **Build command?** | Node: `npm run build` / Spring: `mvn clean install` |
| **Shared code?** | Node: libs/ / Spring: common/ modules |

**Key Insight**: Hybrid = 2 separate monorepos, each following their framework's best practices! 🎯
