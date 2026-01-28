# Developer 1 Guide - Core & Messaging Services (Senior)

> **Your Services**: core-service, messaging-service  
> **Complexity**: 🔴 High  
> **Estimated LOC**: 7,500  
> **Timeline**: Week 1-3

---

## 🎯 Your Responsibilities

You are the **Critical Path Owner**. The entire project depends on your services being completed first.

### Services Overview

1. **core-service** (Week 1-2)
   - Auth module (register, login, JWT)
   - User module (profile, settings, privacy)
   - Social module (friends, blocks, contacts)
   - QR module (generate, scan)

2. **messaging-service** (Week 2-3)
   - Conversation module (1:1, group chats)
   - Message module (send, receive, history)
   - Reaction module (emoji reactions)
   - Receipt module (read receipts)
   - Poll module (group polls)

---

## 📦 Setup Project (Day 1)

### Step 1: Create Maven Monorepo

```bash
# 1. Open IntelliJ IDEA
File → New → Project

# 2. Select Maven
# 3. Fill in:
Name: cnm-zalo-backend
Location: D:\Download\Project\cnm-zalo-backend
GroupId: vn.edu.hcmuaf.fit.ott
ArtifactId: cnm-zalo-backend
Version: 1.0.0-SNAPSHOT

# 4. Click Create
```

### Step 2: Configure Parent POM

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

    <properties>
        <java.version>17</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <modules>
        <module>common/common-domain</module>
        <module>common/common-security</module>
        <module>common/common-messaging</module>
        <module>services/core-service</module>
        <module>services/messaging-service</module>
    </modules>

    <dependencyManagement>
        <dependencies>
            <!-- Internal modules -->
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
        </dependencies>
    </dependencyManagement>
</project>
```

### Step 3: Create Common Modules

```bash
# In IntelliJ:
Right-click project root → New → Module

# Create 3 modules:
1. common/common-domain
2. common/common-security  
3. common/common-messaging
```

**common-domain/pom.xml**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
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
            <groupId>jakarta.validation</groupId>
            <artifactId>jakarta.validation-api</artifactId>
        </dependency>
    </dependencies>
</project>
```

**common-security/pom.xml**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <parent>
        <groupId>vn.edu.hcmuaf.fit.ott</groupId>
        <artifactId>cnm-zalo-backend</artifactId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>common-security</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <dependency>
            <groupId>vn.edu.hcmuaf.fit.ott</groupId>
            <artifactId>common-domain</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-api</artifactId>
            <version>0.12.3</version>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-impl</artifactId>
            <version>0.12.3</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt-jackson</artifactId>
            <version>0.12.3</version>
            <scope>runtime</scope>
        </dependency>
    </dependencies>
</project>
```

---

## 🔨 Week 1: Common Libraries + Core Service

### Day 1-2: Common Libraries

#### 1. Create Base Entities (common-domain)

```java
// common-domain/src/main/java/.../domain/entity/BaseEntity.java
package vn.edu.hcmuaf.fit.ott.common.domain.entity;

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

    @Column(name = "created_at", nullable = false, updatable = false)
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

#### 2. Create JWT Provider (common-security)

```java
// common-security/src/main/java/.../security/JwtTokenProvider.java
package vn.edu.hcmuaf.fit.ott.common.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.security.Key;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtTokenProvider {
    
    @Value("${jwt.secret}")
    private String jwtSecret;
    
    @Value("${jwt.expiration}")
    private long jwtExpiration;
    
    public String generateAccessToken(UUID userId) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + jwtExpiration);
        
        Key key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        return Jwts.builder()
                .setSubject(userId.toString())
                .setIssuedAt(now)
                .setExpiration(expiryDate)
                .signWith(key, SignatureAlgorithm.HS512)
                .compact();
    }
    
    public UUID getUserIdFromToken(String token) {
        Key key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
        
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        
        return UUID.fromString(claims.getSubject());
    }
    
    public boolean validateToken(String token) {
        try {
            Key key = Keys.hmacShaKeyFor(jwtSecret.getBytes());
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }
}
```

### Day 3-7: core-service

#### 1. Create core-service Module

```bash
Right-click services/ → New → Module
Name: core-service
```

**pom.xml**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <parent>
        <groupId>vn.edu.hcmuaf.fit.ott</groupId>
        <artifactId>cnm-zalo-backend</artifactId>
        <version>1.0.0-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>core-service</artifactId>

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
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>

        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>

        <!-- Utils -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
</project>
```

#### 2. Create Application Class

```java
// core-service/src/main/java/.../core/CoreServiceApplication.java
package vn.edu.hcmuaf.fit.ott.core;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication(scanBasePackages = {
    "vn.edu.hcmuaf.fit.ott.core",
    "vn.edu.hcmuaf.fit.ott.common.security"
})
@EnableJpaRepositories
public class CoreServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(CoreServiceApplication.class, args);
    }
}
```

#### 3. Create application.yml

```yaml
# core-service/src/main/resources/application.yml
server:
  port: 8081

spring:
  application:
    name: core-service
  
  datasource:
    url: jdbc:postgresql://localhost:5432/ott_zalo
    username: postgres
    password: postgres
    driver-class-name: org.postgresql.Driver
  
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        default_schema: auth
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true
    show-sql: true
  
  redis:
    host: localhost
    port: 6379

jwt:
  secret: your-very-long-secret-key-at-least-512-bits-for-hs512-algorithm
  expiration: 86400000  # 1 day
```

#### 4. Implement Auth Module (Priority 1)

**Entity**:
```java
// core-service/src/main/java/.../core/auth/entity/AuthAccount.java
@Entity
@Table(name = "auth_account", schema = "auth")
@Getter
@Setter
public class AuthAccount extends BaseEntity {
    
    @Column(unique = true, nullable = false, length = 20)
    private String phone;
    
    @Column(name = "password_hash")
    private String passwordHash;
    
    @Enumerated(Enum String.STRING)
    @Column(length = 20)
    private AccountStatus status = AccountStatus.ACTIVE;
    
    @Column(name = "failed_login_count")
    private Integer failedLoginCount = 0;
    
    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;
}
```

**Repository**:
```java
// core-service/src/main/java/.../core/auth/repository/AuthAccountRepository.java
public interface AuthAccountRepository extends JpaRepository<AuthAccount, UUID> {
    Optional<AuthAccount> findByPhone(String phone);
    boolean existsByPhone(String phone);
}
```

**DTO**:
```java
// core-service/src/main/java/.../core/auth/dto/RegisterRequest.java
@Data
public class RegisterRequest {
    @NotBlank
    @Pattern(regexp = "^\\d{10}$")
    private String phone;
    
    @NotBlank
    @Size(min = 6)
    private String password;
    
    @NotBlank
    private String displayName;
}

@Data
public class LoginRequest {
    @NotBlank
    private String phone;
    
    @NotBlank
    private String password;
}

@Data
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private UUID userId;
    private String phone;
}
```

**Service**:
```java
// core-service/src/main/java/.../core/auth/service/AuthService.java
@Service
@RequiredArgsConstructor
public class AuthService {
    
    private final AuthAccountRepository authAccountRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        // 1. Check if phone exists
        if (authAccountRepository.existsByPhone(request.getPhone())) {
            throw new DuplicatePhoneException("Phone already registered");
        }
        
        // 2. Create auth account
        AuthAccount account = new AuthAccount();
        account.setPhone(request.getPhone());
        account.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        account.setStatus(AccountStatus.ACTIVE);
        authAccountRepository.save(account);
        
        // 3. Create user profile
        UserProfile profile = new UserProfile();
        profile.setId(account.getId());
        profile.setDisplayName(request.getDisplayName());
        userProfileRepository.save(profile);
        
        // 4. Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(account.getId());
        String refreshToken = generateRefreshToken(account.getId());
        
        return new AuthResponse(accessToken, refreshToken, account.getId(), account.getPhone());
    }
    
    @Transactional
    public AuthResponse login(LoginRequest request) {
        // 1. Find account
        AuthAccount account = authAccountRepository.findByPhone(request.getPhone())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid phone or password"));
        
        // 2. Check password
        if (!passwordEncoder.matches(request.getPassword(), account.getPasswordHash())) {
            handleFailedLogin(account);
            throw new InvalidCredentialsException("Invalid phone or password");
        }
        
        // 3. Check account status
        if (account.getStatus() != AccountStatus.ACTIVE) {
            throw new AccountLockedException("Account is locked or disabled");
        }
        
        // 4. Update last login
        account.setLastLoginAt(LocalDateTime.now());
        account.setFailedLoginCount(0);
        authAccountRepository.save(account);
        
        // 5. Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(account.getId());
        String refreshToken = generateRefreshToken(account.getId());
        
        return new AuthResponse(accessToken, refreshToken, account.getId(), account.getPhone());
    }
    
    private void handleFailedLogin(AuthAccount account) {
        account.setFailedLoginCount(account.getFailedLoginCount() + 1);
        if (account.getFailedLoginCount() >= 5) {
            account.setStatus(AccountStatus.LOCKED);
            account.setLockedUntil(LocalDateTime.now().plusMinutes(30));
        }
        authAccountRepository.save(account);
    }
}
```

**Controller**:
```java
// core-service/src/main/java/.../core/auth/controller/AuthController.java
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {
    
    private final AuthService authService;
    
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
    
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("OK");
    }
}
```

---

## 📝 Testing Your Work

```bash
# 1. Start PostgreSQL (Docker)
docker-compose up -d postgres redis

# 2. Run core-service
cd services/core-service
mvn spring-boot:run

# 3. Test Register
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "0909123456",
    "password": "password123",
    "displayName": "Nguyen Van A"
  }'

# 4. Test Login
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "0909123456",
    "password": "password123"
  }'
```

---

## ✅ Week 1 Checklist

- [ ] Create Maven monorepo structure
- [ ] Setup common-domain module
- [ ] Setup common-security module
- [ ] Implement JwtTokenProvider
- [ ] Create core-service module
- [ ] Implement Auth module (register, login)
- [ ] Test register API
- [ ] Test login API
- [ ] Code review with team
- [ ] Merge to main branch

**Next**: Week 2 - User & Social modules, then start messaging-service

---

*See WEEK2-3_GUIDE.md for continued implementation*
