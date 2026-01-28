# Java Version & Project Structure - FAQs

> **Last Updated**: January 20, 2026

---

## ❓ FAQ 1: Có phải từng service là project Spring Boot riêng không?

### ❌ KHÔNG - Không phải từng project riêng

### ✅ Đúng: Maven Monorepo với Multiple Modules

```
Cấu trúc ĐÚNG:
┌─────────────────────────────────────────────────────┐
│  cnm-zalo-backend (1 IntelliJ Project)              │
│  ├── pom.xml (parent)                               │
│  ├── common/                                        │
│  │   ├── common-domain/ (module 1)                 │
│  │   ├── common-security/ (module 2)               │
│  │   └── common-messaging/ (module 3)              │
│  └── services/                                      │
│      ├── core-service/ (module 4) ← Spring Boot App│
│      ├── messaging-service/ (module 5) ← Boot App  │
│      ├── media-service/ (module 6) ← Boot App      │
│      └── ... (8 modules total)                     │
└─────────────────────────────────────────────────────┘

Trong IntelliJ: 1 project, 11 modules
```

### Module vs Project

| Aspect | Module | Separate Project |
|--------|--------|------------------|
| **POM** | Child POM (inherits from parent) | Independent POM |
| **Dependencies** | Share from parent | Manage separately |
| **IntelliJ** | 1 project window | 8 project windows |
| **Build** | `mvn clean install` builds all | Build each separately |
| **Refactoring** | Easy across modules | Hard across projects |
| **Team** | Better for 4 people | Better for 20+ people |

### Why Monorepo for This Project?

✅ **Advantages**:
1. **Shared Code**: common-domain, common-security used by all
2. **Single Build**: `mvn clean install` builds everything
3. **Easier Refactoring**: Rename a class → updates everywhere
4. **Version Sync**: All modules use same Spring Boot version
5. **IntelliJ Performance**: 1 project loads faster than 8

✅ **Team Size**: Perfect for 4 developers

❌ **When to Use Separate Projects**:
- Team > 20 people
- Different tech stacks (Java, Go, Python)
- Completely independent services

---

## ☕ FAQ 2: Nên dùng Java/JDK version nào?

### ✅ Recommended: **Java 17** (LTS)

### Why Java 17?

| Reason | Details |
|--------|---------|
| **LTS** | Long-Term Support until September 2029 |
| **Spring Boot 3.x** | Requires Java 17 as minimum |
| **Modern Features** | Records, Pattern Matching, Text Blocks |
| **Performance** | Better GC, faster startup |
| **Industry Standard** | Most companies using 17 in 2024-2026 |

### Version Comparison

| Version | Status | End of Support | Spring Boot 3.x |
|---------|--------|----------------|-----------------|
| Java 8 | Old LTS | 2030 (paid) | ❌ Not supported |
| Java 11 | Old LTS | 2026 | ⚠️ Minimum for SB 2.x |
| **Java 17** | **Current LTS** | **2029** | **✅ Recommended** |
| Java 21 | Latest LTS | 2031 | ✅ Supported (maybe too new) |

### Final Decision: **Java 17**

```xml
<!-- Parent POM -->
<properties>
    <java.version>17</java.version>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
</properties>
```

### Compatible Versions

```yaml
Ecosystem:
├── Java: 17
├── Spring Boot: 3.2.1
├── Spring Framework: 6.1.x
├── Jakarta EE: 10
├── Maven: 3.8+
└── IntelliJ IDEA: 2023.2+
```

---

## 🛠️ IntelliJ Setup for Monorepo

### Step 1: Configure JDK

```
1. File → Project Structure (Ctrl+Alt+Shift+S)
2. Project Settings → Project
3. SDK: Select Java 17 (or download if not installed)
4. Language Level: 17 - Sealed types, always-strict...
5. Click OK
```

### Step 2: Verify Maven Settings

```
1. File → Settings (Ctrl+Alt+S)
2. Build, Execution, Deployment → Build Tools → Maven
3. Maven home path: Use bundled (or custom Maven 3.8+)
4. JDK for importer: Use Project JDK (17)
5. Click OK
```

### Step 3: Import Project

```
1. File → Open
2. Select: cnm-zalo-backend/pom.xml
3. Open as Project
4. Wait for Maven import to finish
5. All modules will appear in Project view
```

### Step 4: Verify Structure

```
Project view should show:
cnm-zalo-backend
├── .idea/ (IntelliJ settings)
├── common/
│   ├── common-domain
│   ├── common-security
│   └── common-messaging
├── services/
│   ├── core-service
│   ├── messaging-service
│   └── ... (8 total)
├── pom.xml (parent)
└── target/
```

---

## 🏃 Running Services

### Option 1: Run from IntelliJ (Recommended for Dev)

```
For each service (e.g., core-service):

1. Navigate to: services/core-service/src/main/java/.../CoreServiceApplication.java
2. Right-click → Run 'CoreServiceApplication'
3. Or click green play button

Service starts on port 8081 (see application.yml)
```

### Option 2: Run from Terminal

```bash
# Single service
mvn spring-boot:run -pl services/core-service

# All services (different terminals)
mvn spring-boot:run -pl services/core-service &
mvn spring-boot:run -pl services/messaging-service &
mvn spring-boot:run -pl services/media-service &
```

### Option 3: Build JAR and Run

```bash
# Build all
mvn clean package -DskipTests

# Run specific service
java -jar services/core-service/target/core-service-1.0.0-SNAPSHOT.jar
```

---

## 📦 Parent POM Configuration (Complete)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <!-- Spring Boot Parent -->
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.1</version>
        <relativePath/>
    </parent>

    <!-- Project Info -->
    <groupId>vn.edu.hcmuaf.fit.ott</groupId>
    <artifactId>cnm-zalo-backend</artifactId>
    <version>1.0.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <name>OTT Zalo Clone Backend</name>
    <description>Microservices backend for OTT Zalo Clone</description>

    <!-- Java Version -->
    <properties>
        <java.version>17</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        
        <!-- Versions -->
        <spring-cloud.version>2023.0.0</spring-cloud.version>
        <jwt.version>0.12.3</jwt.version>
        <cloudinary.version>1.36.0</cloudinary.version>
    </properties>

    <!-- Modules -->
    <modules>
        <!-- Common Libraries -->
        <module>common/common-domain</module>
        <module>common/common-security</module>
        <module>common/common-messaging</module>
        
        <!-- Microservices -->
        <module>services/core-service</module>
        <module>services/messaging-service</module>
        <module>services/media-service</module>
        <module>services/content-service</module>
        <module>services/realtime-gateway</module>
        <module>services/notification-service</module>
        <module>services/moderation-service</module>
        <module>services/analytics-service</module>
    </modules>

    <!-- Dependency Management -->
    <dependencyManagement>
        <dependencies>
            <!-- Internal Modules -->
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

            <!-- Spring Cloud -->
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>

            <!-- JWT -->
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

            <!-- Cloudinary -->
            <dependency>
                <groupId>com.cloudinary</groupId>
                <artifactId>cloudinary-http44</artifactId>
                <version>${cloudinary.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <!-- Build Configuration -->
    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <configuration>
                        <excludes>
                            <exclude>
                                <groupId>org.projectlombok</groupId>
                                <artifactId>lombok</artifactId>
                            </exclude>
                        </excludes>
                    </configuration>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

---

## ✅ Quick Verification Checklist

Complete này để đảm bảo setup đúng:

### Environment Setup
- [ ] Java 17 JDK installed
- [ ] `java -version` shows "17.x.x"
- [ ] IntelliJ IDEA installed (2023.2+)
- [ ] Maven 3.8+ installed (or use bundled)
- [ ] Docker Desktop installed and running

### IntelliJ Project
- [ ] Opened as Maven project (not folder)
- [ ] Project SDK: Java 17
- [ ] Language Level: 17
- [ ] All 11 modules visible in Project view
- [ ] No red errors in pom.xml files
- [ ] Maven dependencies downloaded (check External Libraries)

### First Build
- [ ] `mvn clean install` succeeds
- [ ] All modules build without errors
- [ ] Target folders created in each module

### First Run
- [ ] Docker compose up (postgres, redis, rabbitmq)
- [ ] core-service starts successfully
- [ ] Accessible at http://localhost:8081
- [ ] `/api/v1/auth/health` returns "OK"

---

## 🎯 Summary

| Question | Answer |
|----------|--------|
| **Từng service là project riêng?** | ❌ KHÔNG - Là modules trong 1 monorepo |
| **Bao nhiêu IntelliJ projects?** | ✅ **1 project** với 11 modules |
| **Java version?** | ✅ **Java 17 LTS** |
| **Spring Boot version?** | ✅ **3.2.1** |
| **Maven version?** | ✅ **3.8+** |

### Next Steps

1. ✅ Install Java 17 JDK
2. ✅ Open IntelliJ
3. ✅ Clone repository
4. ✅ Open `pom.xml` as project
5. ✅ Wait for Maven import
6. ✅ Follow DEV1_GUIDE to start coding

**Ready to code!** 🚀
