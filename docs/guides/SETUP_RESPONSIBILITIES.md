# Project Setup - Phân Công Chi Tiết

> **Mục đích**: Phân biệt rõ Dev 1 setup gì, các dev khác tự tạo gì

---

## 🎯 Nguyên Tắc Phân Công

### ✅ Dev 1 (Team Leader) Setup:
- Infrastructure (Docker, Git repo)
- Parent POMs
- Common/shared modules
- Template examples

### ✅ Các Dev Khác Tự Tạo:
- Service modules của mình
- Application classes
- Business logic

---

## 📋 Chi Tiết Phân Công

### Phase 1: Dev 1 Setup Infrastructure (Day 1 Morning - 2 hours)

#### ✅ Dev 1 Làm (Setup 1 lần cho cả team)

**1. Create Git Repository**
```bash
# Trên GitHub/GitLab
- Create repository: cnm-zalo-clone
- Clone về local
```

**2. Create Base Structure**
```bash
mkdir cnm-zalo-clone
cd cnm-zalo-clone

mkdir -p backend/node-services
mkdir -p backend/java-services
mkdir -p docker
mkdir -p docs
```

**3. Setup Docker Compose**
```yaml
# docker/docker-compose.yml
# Dev 1 tạo sẵn file này cho cả team
```

**4. Setup Node.js Workspace (if using hybrid)**
```bash
cd backend/node-services

# Tạo NestJS monorepo
npm i -g @nestjs/cli
nest new . --skip-git

# Tạo shared libraries
nest generate library common
nest generate library database

# Install common dependencies
npm install @nestjs/typeorm typeorm pg
npm install @nestjs/websockets socket.io
npm install @nestjs/jwt passport-jwt
npm install ioredis amqplib

# Commit
git add .
git commit -m "Setup Node.js workspace with shared libraries"
```

**5. Setup Spring Boot Parent POM**

Create `backend/java-services/pom.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.1</version>
    </parent>

    <groupId>vn.edu.hcmuaf.fit.ott</groupId>
    <artifactId>cnm-zalo-backend</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <properties>
        <java.version>17</java.version>
    </properties>

    <!-- EMPTY modules for now - devs will add their own -->
    <modules>
        <module>common/common-domain</module>
        <module>common/common-security</module>
        <!-- Services added by each dev -->
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

**6. Create Common Modules**

```bash
cd backend/java-services

# common-domain module
mkdir -p common/common-domain/src/main/java/vn/edu/hcmuaf/fit/ott/common/domain
```

Create `common/common-domain/pom.xml`:
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

    <artifactId>common-domain</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
        </dependency>
        <dependency>
            <groupId>jakarta.persistence</groupId>
            <artifactId>jakarta.persistence-api</artifactId>
        </dependency>
    </dependencies>
</project>
```

Create base entity:
```java
// common/common-domain/src/main/java/.../domain/BaseEntity.java
package vn.edu.hcmuaf.fit.ott.common.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.LocalDateTime;
import java.util.UUID;

@MappedSuperclass
@Getter
@Setter
public abstract class BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

Repeat similar for `common-security` module.

**7. Create Service Module Template**

Create template file `docs/SERVICE_MODULE_TEMPLATE.md`:

```markdown
# How to Create Your Service Module

## Step 1: Create Directory Structure
```bash
cd backend/java-services
mkdir -p services/YOUR-SERVICE-NAME/src/main/java/vn/edu/hcmuaf/fit/ott/YOUR_PACKAGE
mkdir -p services/YOUR-SERVICE-NAME/src/main/resources
```

## Step 2: Create pom.xml
[Template POM content here]

## Step 3: Create Application Class
[Template Application.java here]

## Step 4: Create application.yml
[Template config here]

## Step 5: Add to Parent POM
Edit parent pom.xml, add:
```xml
<module>services/YOUR-SERVICE-NAME</module>
```
```

**8. Push to Git**
```bash
git add .
git commit -m "Initial project setup

- Docker Compose (PostgreSQL, Redis, RabbitMQ)
- Node.js workspace with shared libraries
- Spring Boot parent POM
- Common modules (domain, security)
- Service module template"

git push origin main
```

**9. Share with Team**

Post in team chat:
```
✅ Project setup complete!

Repo: https://github.com/your-org/cnm-zalo-clone

Setup done:
✅ Docker Compose
✅ Parent POM
✅ Common modules
✅ Template for creating services

Next: Each developer creates their own service module
See docs/SERVICE_MODULE_TEMPLATE.md
```

---

### Phase 2: Các Dev Tự Tạo Service Module (Day 1 Afternoon)

#### ❌ Dev 1 KHÔNG tạo sẵn service modules

**Lý do:**
- Tránh conflict khi merge
- Mỗi dev tự setup theo cách hiểu của mình
- Practice hands-on
- Ownership rõ ràng

#### ✅ Mỗi Dev Tự Tạo Module Của Mình

**Example: Dev 2 tạo media-service**

**Step 1: Clone & Verify**
```bash
git clone https://github.com/your-org/cnm-zalo-clone.git
cd cnm-zalo-clone/backend/java-services

# Verify parent POM exists
cat pom.xml

# Verify common modules exist
ls common/
```

**Step 2: Create Service Directory**
```bash
mkdir -p services/media-service/src/main/java/vn/edu/hcmuaf/fit/ott/media
mkdir -p services/media-service/src/main/resources
```

**Step 3: Create Module POM**

Create `services/media-service/pom.xml`:
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

    <artifactId>media-service</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <!-- Internal -->
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-domain</artifactId>
        </dependency>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-security</artifactId>
        </dependency>

        <!-- Spring Boot -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>

        <!-- Cloudinary -->
        <dependency>
            <groupId>com.cloudinary</groupId>
            <artifactId>cloudinary-http44</artifactId>
        </dependency>

        <!-- Utils -->
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

**Step 4: Create Application Class**

Create `services/media-service/src/main/java/.../media/MediaServiceApplication.java`:
```java
package vn.edu.hcmuaf.fit.ott.media;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {
    "vn.edu.hcmuaf.fit.ott.media",
    "vn.edu.hcmuaf.fit.ott.common"
})
public class MediaServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MediaServiceApplication.class, args);
    }
}
```

**Step 5: Create application.yml**

Create `services/media-service/src/main/resources/application.yml`:
```yaml
server:
  port: 8083

spring:
  application:
    name: media-service
  
  datasource:
    url: jdbc:postgresql://localhost:5432/ott_zalo
    username: postgres
    password: postgres
  
  jpa:
    hibernate:
      ddl-auto: validate
```

**Step 6: Add to Parent POM**

Edit `backend/java-services/pom.xml`, add to `<modules>`:
```xml
<modules>
    <module>common/common-domain</module>
    <module>common/common-security</module>
    <module>services/media-service</module>  <!-- ADD THIS -->
</modules>
```

**Step 7: Build & Test**
```bash
# Build all
mvn clean install

# Run service
mvn spring-boot:run -pl services/media-service
```

**Step 8: Commit**
```bash
git add services/media-service
git add pom.xml  # Updated with new module
git commit -m "Add media-service module"
git push origin dev2-media-service  # Push to feature branch
```

**Step 9: Create Pull Request**
```
Title: Add media-service module
Description: Initial setup for media upload service

Changes:
- Created media-service module
- Added to parent POM
- Basic application structure
```

---

## 🔄 Workflow Summary

```
Day 1 Morning:
├── Dev 1: Setup infrastructure (2 hours)
│   ├── Git repo
│   ├── Docker Compose
│   ├── Parent POM
│   ├── Common modules
│   └── Push to main branch
│
Day 1 Afternoon:
├── Dev 2: Clone → Create media-service → PR
├── Dev 3: Clone → Create content-service → PR
├── Dev 4: Clone → Create moderation-service → PR
│
Day 2:
├── Dev 1: Review PRs → Merge all
├── Everyone: Pull latest → Start coding
```

---

## 📋 Complete Checklist

### Dev 1 (Team Leader)

**Infrastructure (Do Once)**
- [ ] Create Git repository
- [ ] Setup directory structure
- [ ] Create Docker Compose
- [ ] Setup Node.js workspace (if hybrid)
- [ ] Create Spring Boot parent POM
- [ ] Create common-domain module
- [ ] Create common-security module
- [ ] Create service template doc
- [ ] Build & verify: `mvn clean install`
- [ ] Push to main branch
- [ ] Notify team

**After Team Creates Modules**
- [ ] Review all PRs
- [ ] Merge service modules
- [ ] Verify builds after merge
- [ ] Start implementing core-service

### Dev 2 (Media Service Owner)

**Your Tasks**
- [ ] Clone repository
- [ ] Create services/media-service/ directory
- [ ] Create media-service/pom.xml
- [ ] Create MediaServiceApplication.java
- [ ] Create application.yml
- [ ] Add module to parent POM
- [ ] Test build: `mvn clean install`
- [ ] Test run: `mvn spring-boot:run -pl services/media-service`
- [ ] Commit & push to feature branch
- [ ] Create PR

### Dev 3, 4 (Similar)

- [ ] Same steps as Dev 2 for their services

---

## ⚠️ Important Notes

### ❌ Anti-Patterns (TRÁNh)

1. **Dev 1 tạo sẵn tất cả service modules**
   - ❌ Tạo conflict khi merge
   - ❌ Không ai hiểu setup

2. **Mọi người tự setup parent POM**
   - ❌ Versions không nhất quán
   - ❌ Duplicate dependencies

3. **Không dùng template**
   - ❌ Mỗi người setup khác nhau
   - ❌ Hard to maintain

### ✅ Best Practices

1. **Dev 1 setup infrastructure shared**
   - ✅ 1 source of truth
   - ✅ Consistent setup

2. **Each dev creates their own service module**
   - ✅ Ownership clear
   - ✅ Hands-on learning
   - ✅ No merge conflicts

3. **Use template & follow convention**
   - ✅ Consistent structure
   - ✅ Easy review

---

## 🎯 TL;DR

| Task | Who | When |
|------|-----|------|
| **Setup Git, Docker, Parent POM, Common modules** | Dev 1 only | Day 1 AM |
| **Create service modules** | Each dev for their services | Day 1 PM |
| **Review & merge PRs** | Dev 1 | Day 2 |
| **Start coding business logic** | All | Day 2+ |

**Key Rule**: Infrastructure = Dev 1. Service modules = Respective owners. 🎯
