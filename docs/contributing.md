# 📋 Quy Định Đóng Góp - CNM Zalo Clone

> Tài liệu này quy định các chuẩn mực và quy tắc mà tất cả thành viên trong nhóm phải tuân thủ để đảm bảo code sạch, dễ đọc và dễ bảo trì.

---

## 📑 Mục Lục

1. [Commit Message Convention](#1-commit-message-convention)
2. [Quy Tắc Đặt Tên](#2-quy-tắc-đặt-tên)
3. [Cấu Trúc Code](#3-cấu-trúc-code)
4. [Clean Code Principles](#4-clean-code-principles)
5. [Git Workflow](#5-git-workflow)
6. [Code Review Guidelines](#6-code-review-guidelines)
7. [Documentation](#7-documentation)
8. [Testing Standards](#8-testing-standards)
9. [Security Best Practices](#9-security-best-practices)

---

## 1. Commit Message Convention

### 1.1 Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### 1.2 Types (Bắt buộc)

| Type | Mô Tả | Ví Dụ |
|------|-------|-------|
| `feat` | Tính năng mới | `feat(auth): add login with Google` |
| `fix` | Sửa lỗi | `fix(chat): resolve message not sending issue` |
| `docs` | Thay đổi documentation | `docs(readme): update installation guide` |
| `style` | Thay đổi không ảnh hưởng logic (format, spacing, etc.) | `style(button): fix indentation` |
| `refactor` | Refactor code không thêm feature hay fix bug | `refactor(api): restructure user service` |
| `perf` | Cải thiện performance | `perf(query): optimize database queries` |
| `test` | Thêm hoặc sửa test | `test(auth): add unit tests for login` |
| `build` | Thay đổi build system hoặc dependencies | `build(deps): upgrade Spring Boot to 3.2` |
| `ci` | Thay đổi CI/CD configuration | `ci(github): add deployment workflow` |
| `chore` | Các thay đổi khác không ảnh hưởng src/test | `chore(gitignore): add IDE files` |
| `revert` | Revert commit trước đó | `revert: revert commit abc123` |

### 1.3 Scope (Tùy chọn nhưng khuyến khích)

Scope là module/component bị ảnh hưởng:
- `auth`, `chat`, `user`, `group`, `message`, `media`, `notification`
- `api`, `db`, `config`, `docker`, `k8s`
- `frontend`, `backend`, `gateway`

### 1.4 Subject Rules

- ✅ Viết bằng tiếng Anh
- ✅ Dùng imperative mood: "add", "fix", "update" (không phải "added", "fixes")
- ✅ Không viết hoa chữ cái đầu
- ✅ Không kết thúc bằng dấu chấm
- ✅ Giới hạn 50 ký tự

### 1.5 Ví Dụ Commit Messages

```bash
# ✅ Đúng
feat(auth): implement JWT refresh token
fix(chat): prevent duplicate messages on reconnect
docs(api): add swagger documentation for user endpoints
refactor(user-service): extract validation logic to separate class
test(message): add integration tests for message delivery

# ❌ Sai
Added new feature           # Không có type, dùng past tense
feat: Fix bug              # Type không đúng, viết hoa
FEAT(auth): add login      # Type viết hoa
feat(auth): add login.     # Có dấu chấm cuối
```

---

## 2. Quy Tắc Đặt Tên

### 2.1 Tên File

#### Backend (Java/Spring Boot)

| Loại | Convention | Ví Dụ |
|------|------------|-------|
| Class/Interface | PascalCase | `UserService.java`, `MessageRepository.java` |
| Configuration | PascalCase + Config suffix | `SecurityConfig.java`, `RedisConfig.java` |
| Controller | PascalCase + Controller suffix | `AuthController.java`, `ChatController.java` |
| Service | PascalCase + Service suffix | `UserService.java`, `MessageService.java` |
| Repository | PascalCase + Repository suffix | `UserRepository.java` |
| DTO | PascalCase + DTO/Request/Response suffix | `UserDTO.java`, `LoginRequest.java` |
| Entity | PascalCase (số ít) | `User.java`, `Message.java`, `Conversation.java` |
| Exception | PascalCase + Exception suffix | `UserNotFoundException.java` |
| Test | PascalCase + Test suffix | `UserServiceTest.java` |

#### Frontend (React/TypeScript)

| Loại | Convention | Ví Dụ |
|------|------------|-------|
| Component | PascalCase | `ChatWindow.tsx`, `MessageBubble.tsx` |
| Hook | camelCase với prefix "use" | `useAuth.ts`, `useWebSocket.ts` |
| Utility | camelCase | `formatDate.ts`, `validateEmail.ts` |
| Type/Interface | PascalCase | `User.types.ts`, `Message.interface.ts` |
| Constant | SCREAMING_SNAKE_CASE trong file | `constants.ts` |
| Style | Component name + .module.css/scss | `ChatWindow.module.scss` |
| Test | Component name + .test.tsx | `ChatWindow.test.tsx` |

### 2.2 Tên Biến

#### Quy Tắc Chung

| Ngôn Ngữ | Convention | Ví Dụ |
|----------|------------|-------|
| Java | camelCase | `userName`, `messageCount`, `isActive` |
| TypeScript/JavaScript | camelCase | `userId`, `chatRoom`, `isLoading` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| Environment Variables | SCREAMING_SNAKE_CASE | `DATABASE_URL`, `JWT_SECRET` |

#### Naming Conventions Chi Tiết

```java
// ✅ Java - Đúng
private String userName;
private int messageCount;
private boolean isActive;
private List<User> activeUsers;
private Map<String, Object> userSettings;
private static final int MAX_CONNECTIONS = 100;

// ❌ Java - Sai
private String user_name;      // Dùng snake_case
private String UserName;       // Dùng PascalCase cho biến
private int msgCnt;           // Viết tắt không rõ ràng
```

```typescript
// ✅ TypeScript - Đúng
const userName: string = "John";
const isLoggedIn: boolean = true;
const messageList: Message[] = [];
const MAX_FILE_SIZE = 10 * 1024 * 1024;

// ❌ TypeScript - Sai
const user_name: string = "John";  // Dùng snake_case
const UserName: string = "John";   // Dùng PascalCase cho biến
```

### 2.3 Tên Hàm/Method

#### Quy Tắc

- Dùng **camelCase**
- Bắt đầu bằng **động từ**
- Mô tả rõ ràng chức năng

#### Prefix Conventions

| Prefix | Mục Đích | Ví Dụ |
|--------|----------|-------|
| `get` | Lấy dữ liệu | `getUserById()`, `getMessages()` |
| `set` | Gán giá trị | `setUserName()`, `setStatus()` |
| `is/has/can` | Kiểm tra boolean | `isActive()`, `hasPermission()`, `canEdit()` |
| `create` | Tạo mới | `createUser()`, `createConversation()` |
| `update` | Cập nhật | `updateProfile()`, `updateMessage()` |
| `delete/remove` | Xóa | `deleteUser()`, `removeMessage()` |
| `find` | Tìm kiếm (có thể null) | `findUserByEmail()` |
| `fetch` | Lấy từ external source | `fetchUserData()` |
| `load` | Load dữ liệu | `loadMessages()` |
| `save` | Lưu dữ liệu | `saveUser()` |
| `validate` | Kiểm tra tính hợp lệ | `validateEmail()` |
| `convert/to` | Chuyển đổi | `convertToDTO()`, `toEntity()` |
| `handle` | Xử lý event | `handleClick()`, `handleSubmit()` |
| `on` | Event listener | `onMessageReceived()` |

#### Ví Dụ

```java
// ✅ Đúng
public User getUserById(Long id) { }
public boolean isUserActive(Long userId) { }
public void sendMessage(Message message) { }
public List<Message> findMessagesByConversationId(Long conversationId) { }
public UserDTO convertToDTO(User user) { }

// ❌ Sai
public User user(Long id) { }           // Thiếu động từ
public User GetUserById(Long id) { }    // PascalCase
public void msg_send(Message m) { }     // snake_case, viết tắt
```

### 2.4 Tên Class/Interface

```java
// ✅ Đúng
public class UserService { }
public interface MessageRepository extends JpaRepository<Message, Long> { }
public class AuthenticationException extends RuntimeException { }
public record UserDTO(Long id, String name, String email) { }

// ❌ Sai
public class userService { }      // Không PascalCase
public class User_Service { }     // Dùng underscore
public class UserSvc { }          // Viết tắt
```

### 2.5 Tên Package/Module

```
# Java Package - lowercase, dot-separated
com.cnmzalo.userservice
com.cnmzalo.userservice.controller
com.cnmzalo.userservice.service
com.cnmzalo.userservice.repository
com.cnmzalo.userservice.dto
com.cnmzalo.userservice.entity
com.cnmzalo.userservice.exception
com.cnmzalo.userservice.config

# Frontend Module - kebab-case folders
src/
├── components/
│   ├── chat-window/
│   ├── message-bubble/
│   └── user-avatar/
├── hooks/
├── services/
├── utils/
└── types/
```

---

## 3. Cấu Trúc Code

### 3.1 Import Order

```java
// Java
// 1. Java standard library
import java.util.*;
import java.time.*;

// 2. Third-party libraries
import org.springframework.*;
import lombok.*;

// 3. Project imports
import com.cnmzalo.*;
```

```typescript
// TypeScript/React
// 1. React/Next.js
import React from 'react';
import { useRouter } from 'next/router';

// 2. Third-party libraries
import axios from 'axios';
import { useQuery } from '@tanstack/react-query';

// 3. Internal modules (absolute imports)
import { UserService } from '@/services/userService';
import { Button } from '@/components/ui';

// 4. Relative imports
import { formatDate } from './utils';
import styles from './Component.module.scss';
```

### 3.2 Code Formatting

#### Indentation
- **Spaces**: 2 spaces cho Frontend, 4 spaces cho Backend
- **Không dùng Tab**

#### Line Length
- Tối đa **100 ký tự** cho Java
- Tối đa **80 ký tự** cho TypeScript/JavaScript

#### Braces
```java
// ✅ Đúng - K&R style
if (condition) {
    doSomething();
} else {
    doSomethingElse();
}

// ❌ Sai - Allman style (không dùng)
if (condition)
{
    doSomething();
}
```

### 3.3 Comments

```java
/**
 * Gửi tin nhắn đến conversation.
 * 
 * @param conversationId ID của conversation
 * @param message Nội dung tin nhắn
 * @return Message đã được gửi
 * @throws ConversationNotFoundException nếu conversation không tồn tại
 */
public Message sendMessage(Long conversationId, String message) {
    // Validate input
    validateMessage(message);
    
    // TODO: Implement message encryption
    
    // FIXME: Handle edge case when user is offline
    
    return messageRepository.save(newMessage);
}
```

### 3.4 Error Handling

```java
// ✅ Đúng - Specific exceptions
public User getUserById(Long id) {
    return userRepository.findById(id)
        .orElseThrow(() -> new UserNotFoundException("User not found with id: " + id));
}

// ❌ Sai - Generic exception
public User getUserById(Long id) {
    try {
        return userRepository.findById(id).get();
    } catch (Exception e) {
        throw new RuntimeException("Error");
    }
}
```

---

## 4. Clean Code Principles

### 4.1 SOLID Principles

#### Single Responsibility Principle (SRP)
Mỗi class chỉ nên có **một lý do để thay đổi**.

```java
// ❌ Sai - Class có nhiều trách nhiệm
public class UserService {
    public void createUser(User user) { }
    public void sendEmail(String email) { }      // Email responsibility
    public void generateReport(User user) { }    // Report responsibility
    public void logActivity(String activity) { } // Logging responsibility
}

// ✅ Đúng - Tách thành các class riêng
public class UserService {
    private final EmailService emailService;
    private final ReportService reportService;
    private final LogService logService;
    
    public void createUser(User user) {
        // Only user creation logic
    }
}
```

#### Open/Closed Principle (OCP)
Class nên **mở cho việc mở rộng**, **đóng cho việc sửa đổi**.

```java
// ✅ Đúng - Sử dụng interface/abstract
public interface NotificationSender {
    void send(String message);
}

public class EmailNotificationSender implements NotificationSender {
    @Override
    public void send(String message) { /* email logic */ }
}

public class SmsNotificationSender implements NotificationSender {
    @Override
    public void send(String message) { /* SMS logic */ }
}
```

#### Liskov Substitution Principle (LSP)
Subclass phải có thể **thay thế** được base class mà không làm hỏng chương trình.

#### Interface Segregation Principle (ISP)
Không nên bắt class implement các method mà nó không dùng.

```java
// ❌ Sai - Interface quá lớn
public interface Worker {
    void work();
    void eat();
    void sleep();
}

// ✅ Đúng - Tách thành interface nhỏ
public interface Workable {
    void work();
}

public interface Eatable {
    void eat();
}
```

#### Dependency Inversion Principle (DIP)
Phụ thuộc vào **abstraction**, không phụ thuộc vào **implementation**.

```java
// ✅ Đúng - Dependency Injection
public class UserService {
    private final UserRepository userRepository;
    
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
}
```

### 4.2 Function/Method Best Practices

#### 4.2.1 Kích Thước Hàm
- Hàm nên **ngắn gọn** (tối đa 20-30 dòng)
- Mỗi hàm chỉ làm **một việc**
- Nếu hàm quá dài → chia nhỏ thành các hàm con

```java
// ❌ Sai - Hàm quá dài và làm nhiều việc
public void processOrder(Order order) {
    // Validate (20 lines)
    // Calculate price (30 lines)
    // Apply discount (25 lines)
    // Update inventory (20 lines)
    // Send notification (15 lines)
}

// ✅ Đúng - Chia nhỏ thành các hàm
public void processOrder(Order order) {
    validateOrder(order);
    double totalPrice = calculateTotalPrice(order);
    applyDiscount(order, totalPrice);
    updateInventory(order);
    sendOrderConfirmation(order);
}
```

#### 4.2.2 Tham Số Hàm
- Tối đa **3 tham số** cho mỗi hàm
- Nếu cần nhiều hơn → tạo object chứa các tham số

```java
// ❌ Sai - Quá nhiều tham số
public void createUser(String name, String email, String phone, 
                       String address, String city, String country, 
                       String zipCode, int age) { }

// ✅ Đúng - Sử dụng object
public void createUser(UserRegistrationRequest request) { }

public record UserRegistrationRequest(
    String name, String email, String phone,
    Address address, int age
) { }
```

#### 4.2.3 Tránh Side Effects
Hàm không nên thay đổi trạng thái bên ngoài scope của nó một cách không mong đợi.

```java
// ❌ Sai - Side effect không mong đợi
public boolean checkPassword(String password) {
    if (isValid(password)) {
        session.initialize();  // Side effect!
        return true;
    }
    return false;
}

// ✅ Đúng - Tách riêng logic
public boolean isPasswordValid(String password) {
    return isValid(password);
}

public void initializeSessionIfValid(String password) {
    if (isPasswordValid(password)) {
        session.initialize();
    }
}
```

#### 4.2.4 Return Early Pattern
Sử dụng **early return** để tránh nested conditions.

```java
// ❌ Sai - Nested conditions
public String processUser(User user) {
    if (user != null) {
        if (user.isActive()) {
            if (user.hasPermission()) {
                return "Success";
            } else {
                return "No permission";
            }
        } else {
            return "Inactive user";
        }
    } else {
        return "User not found";
    }
}

// ✅ Đúng - Early return
public String processUser(User user) {
    if (user == null) {
        return "User not found";
    }
    if (!user.isActive()) {
        return "Inactive user";
    }
    if (!user.hasPermission()) {
        return "No permission";
    }
    return "Success";
}
```

### 4.3 Class Design

#### 4.3.1 Cohesion
Các method trong class nên **liên quan chặt chẽ** với nhau.

#### 4.3.2 Coupling
Giảm thiểu **sự phụ thuộc** giữa các class.

#### 4.3.3 Encapsulation
- Luôn sử dụng **private** cho fields
- Cung cấp **getter/setter** chỉ khi cần thiết
- Ẩn implementation details

```java
// ✅ Đúng - Proper encapsulation
public class User {
    private String email;
    private String password;
    
    public String getEmail() {
        return email;
    }
    
    public void updatePassword(String oldPassword, String newPassword) {
        if (!this.password.equals(oldPassword)) {
            throw new InvalidPasswordException();
        }
        this.password = hashPassword(newPassword);
    }
    
    private String hashPassword(String password) {
        // Hashing logic
    }
}
```

### 4.4 DRY Principle (Don't Repeat Yourself)

Không lặp lại code - extract thành method/class riêng.

```java
// ❌ Sai - Code lặp lại
public void sendWelcomeEmail(User user) {
    String subject = "Welcome";
    String body = "Welcome to our platform";
    emailService.send(user.getEmail(), subject, body);
    logger.info("Email sent to: " + user.getEmail());
}

public void sendPasswordResetEmail(User user) {
    String subject = "Reset Password";
    String body = "Click here to reset password";
    emailService.send(user.getEmail(), subject, body);
    logger.info("Email sent to: " + user.getEmail());
}

// ✅ Đúng - Extract common logic
private void sendEmail(User user, String subject, String body) {
    emailService.send(user.getEmail(), subject, body);
    logger.info("Email sent to: " + user.getEmail());
}

public void sendWelcomeEmail(User user) {
    sendEmail(user, "Welcome", "Welcome to our platform");
}

public void sendPasswordResetEmail(User user) {
    sendEmail(user, "Reset Password", "Click here to reset password");
}
```

### 4.5 KISS Principle (Keep It Simple, Stupid)

Giữ code **đơn giản**, tránh **over-engineering**.

```java
// ❌ Sai - Over-complicated
public boolean isAdult(int age) {
    return Optional.ofNullable(age)
        .filter(a -> a >= 18)
        .map(a -> true)
        .orElse(false);
}

// ✅ Đúng - Simple and clear
public boolean isAdult(int age) {
    return age >= 18;
}
```

### 4.6 YAGNI Principle (You Aren't Gonna Need It)

Không implement tính năng cho đến khi **thực sự cần**.

### 4.7 Magic Numbers và Magic Strings

Tránh hardcode values - sử dụng **constants**.

```java
// ❌ Sai - Magic numbers/strings
if (user.getAge() >= 18) { }
if (status.equals("ACTIVE")) { }
if (attempts > 3) { }

// ✅ Đúng - Named constants
private static final int LEGAL_AGE = 18;
private static final String STATUS_ACTIVE = "ACTIVE";
private static final int MAX_LOGIN_ATTEMPTS = 3;

if (user.getAge() >= LEGAL_AGE) { }
if (status.equals(STATUS_ACTIVE)) { }
if (attempts > MAX_LOGIN_ATTEMPTS) { }
```

### 4.8 Null Safety

#### Java
```java
// ✅ Sử dụng Optional
public Optional<User> findUserById(Long id) {
    return userRepository.findById(id);
}

// ✅ Null checks
public void processUser(User user) {
    Objects.requireNonNull(user, "User cannot be null");
    // Process user
}

// ✅ Default values
public String getUserName(User user) {
    return user != null ? user.getName() : "Anonymous";
}
```

#### TypeScript
```typescript
// ✅ Optional chaining
const userName = user?.profile?.name;

// ✅ Nullish coalescing
const displayName = userName ?? 'Anonymous';

// ✅ Type guards
if (user !== null && user !== undefined) {
    console.log(user.name);
}
```

### 4.9 Meaningful Names

```java
// ❌ Sai - Unclear names
int d;           // elapsed time in days
int a;           // account list
String tmp;

// ✅ Đúng - Descriptive names
int elapsedTimeInDays;
List<Account> activeAccounts;
String formattedAddress;
```

### 4.10 Code Organization

#### Vertical Ordering
- Constants at top
- Fields
- Constructors
- Public methods
- Private methods

```java
public class UserService {
    // 1. Constants
    private static final int MAX_RETRY = 3;
    
    // 2. Fields
    private final UserRepository userRepository;
    private final EmailService emailService;
    
    // 3. Constructor
    public UserService(UserRepository userRepository, EmailService emailService) {
        this.userRepository = userRepository;
        this.emailService = emailService;
    }
    
    // 4. Public methods
    public User createUser(UserDTO dto) {
        User user = mapToEntity(dto);
        return userRepository.save(user);
    }
    
    // 5. Private methods
    private User mapToEntity(UserDTO dto) {
        // Mapping logic
    }
}
```

---

## 5. Git Workflow

### 5.1 Branch Naming

```
<type>/<issue-number>-<short-description>
```

| Type | Mô Tả | Ví Dụ |
|------|-------|-------|
| `feature` | Tính năng mới | `feature/123-user-authentication` |
| `bugfix` | Sửa lỗi | `bugfix/456-fix-message-duplicate` |
| `hotfix` | Sửa lỗi khẩn cấp trên production | `hotfix/789-security-patch` |
| `release` | Chuẩn bị release | `release/1.0.0` |
| `docs` | Cập nhật documentation | `docs/update-api-docs` |

### 5.2 Workflow

```
main (production)
  │
  ├── develop
  │     │
  │     ├── feature/123-new-feature
  │     │
  │     ├── bugfix/456-fix-bug
  │     │
  │     └── feature/789-another-feature
  │
  └── hotfix/urgent-fix
```

### 5.3 Pull Request

1. **Title**: Theo commit message convention
2. **Description**: 
   - Mô tả thay đổi
   - Link đến issue liên quan
   - Screenshots (nếu có UI changes)
   - Testing checklist
3. **Review**: Cần ít nhất 1 approval trước khi merge
4. **Merge**: Sử dụng "Squash and merge"

---

## 6. Code Review Guidelines

### 6.1 Checklist cho Reviewer

- [ ] Code có tuân thủ conventions không?
- [ ] Logic có đúng không?
- [ ] Có test coverage không?
- [ ] Có security issues không?
- [ ] Performance có ổn không?
- [ ] Documentation có đầy đủ không?
- [ ] Code có tuân thủ SOLID principles không?
- [ ] Có duplicate code không? (DRY)
- [ ] Error handling có đầy đủ không?
- [ ] Có hardcoded values (magic numbers/strings) không?

### 6.2 Checklist cho Author

- [ ] Self-review code trước khi tạo PR
- [ ] Chạy tests locally
- [ ] Update documentation nếu cần
- [ ] Resolve conflicts với target branch

---

## 7. Documentation

### 7.1 README.md

Mỗi service/module cần có README với:
- Mô tả ngắn
- Prerequisites
- Installation
- Configuration
- API documentation link
- Contributing guide link

### 7.2 API Documentation

- Sử dụng **Swagger/OpenAPI** cho REST APIs
- Document tất cả endpoints với:
  - Description
  - Request/Response examples
  - Error codes

### 7.3 Code Comments

- Comment **WHY**, không phải **WHAT**
- Giữ comments up-to-date
- Xóa commented-out code

---

## 8. Testing Standards

### 8.1 Test Coverage Requirements

| Component | Minimum Coverage |
|-----------|------------------|
| Service Layer | 80% |
| Controller Layer | 70% |
| Repository Layer | 60% |
| Utility Classes | 90% |

### 8.2 Testing Pyramid

```
        /\
       /  \  E2E Tests (10%)
      /____\
     /      \
    / Integration Tests (30%)
   /________\
  /          \
 / Unit Tests (60%)
/______________\
```

### 8.3 Unit Testing Best Practices

#### Naming Convention
```java
// Pattern: methodName_stateUnderTest_expectedBehavior
@Test
public void getUserById_validId_returnsUser() { }

@Test
public void getUserById_invalidId_throwsNotFoundException() { }

@Test
public void createUser_duplicateEmail_throwsException() { }
```

#### AAA Pattern (Arrange-Act-Assert)
```java
@Test
public void createUser_validData_savesUser() {
    // Arrange
    UserDTO dto = new UserDTO("John", "john@example.com");
    when(userRepository.save(any())).thenReturn(new User());
    
    // Act
    User result = userService.createUser(dto);
    
    // Assert
    assertNotNull(result);
    verify(userRepository, times(1)).save(any());
}
```

#### Test Independence
- Mỗi test phải **độc lập**
- Không phụ thuộc vào thứ tự chạy
- Không share state giữa các tests

```java
// ✅ Đúng - Setup cho mỗi test
@BeforeEach
public void setUp() {
    userService = new UserService(userRepository, emailService);
}

@Test
public void test1() { /* independent test */ }

@Test
public void test2() { /* independent test */ }
```

### 8.4 Integration Testing

```java
@SpringBootTest
@AutoConfigureMockMvc
public class UserControllerIntegrationTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @Test
    public void createUser_validRequest_returns201() throws Exception {
        String userJson = "{\"name\":\"John\",\"email\":\"john@example.com\"}";
        
        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(userJson))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.name").value("John"));
    }
}
```

### 8.5 Frontend Testing

#### Component Testing (React)
```typescript
// Component.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  it('should render email and password inputs', () => {
    render(<LoginForm />);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
  });
  
  it('should call onSubmit when form is submitted', () => {
    const handleSubmit = jest.fn();
    render(<LoginForm onSubmit={handleSubmit} />);
    
    fireEvent.click(screen.getByRole('button', { name: /login/i }));
    
    expect(handleSubmit).toHaveBeenCalledTimes(1);
  });
});
```

### 8.6 Test Data Management

#### Use Test Fixtures
```java
// TestFixtures.java
public class UserFixtures {
    public static User createValidUser() {
        return User.builder()
            .name("John Doe")
            .email("john@example.com")
            .build();
    }
    
    public static UserDTO createValidUserDTO() {
        return new UserDTO("John Doe", "john@example.com");
    }
}

// Usage in tests
@Test
public void test() {
    User user = UserFixtures.createValidUser();
    // Test logic
}
```

### 8.7 Mocking Guidelines

- Mock **external dependencies** (APIs, databases, services)
- Không mock **domain logic**
- Sử dụng **Mockito** cho Java, **Jest** cho TypeScript

```java
// ✅ Đúng - Mock external dependency
@Mock
private EmailService emailService;

@Mock
private UserRepository userRepository;

// ❌ Sai - Không mock domain logic
@Mock
private UserValidator userValidator; // Should test real validator
```

---

## 9. Security Best Practices

### 9.1 Authentication & Authorization

#### Password Security
```java
// ✅ Đúng - Hash passwords
public void createUser(UserDTO dto) {
    String hashedPassword = passwordEncoder.encode(dto.getPassword());
    user.setPassword(hashedPassword);
    userRepository.save(user);
}

// ❌ Sai - Plain text password
user.setPassword(dto.getPassword()); // NEVER!
```

#### JWT Best Practices
- Sử dụng **short-lived access tokens** (15-30 phút)
- Sử dụng **refresh tokens** cho renew
- Store refresh tokens **securely** (httpOnly cookies)
- Validate token **signature** và **expiration**

```java
// ✅ Token validation
public boolean validateToken(String token) {
    try {
        Jwts.parserBuilder()
            .setSigningKey(secretKey)
            .build()
            .parseClaimsJws(token);
        return true;
    } catch (JwtException | IllegalArgumentException e) {
        return false;
    }
}
```

### 9.2 Input Validation

#### Backend Validation
```java
// ✅ Đúng - Validate input
@PostMapping("/users")
public ResponseEntity<User> createUser(@Valid @RequestBody UserDTO dto) {
    return ResponseEntity.ok(userService.createUser(dto));
}

public record UserDTO(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 50)
    String name,
    
    @Email(message = "Invalid email format")
    @NotBlank(message = "Email is required")
    String email,
    
    @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$",
             message = "Password must be at least 8 characters with letters and numbers")
    String password
) { }
```

#### Frontend Validation
```typescript
// ✅ Validate before submission
const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const handleSubmit = (data: FormData) => {
  if (!validateEmail(data.email)) {
    showError('Invalid email format');
    return;
  }
  // Submit
};
```

### 9.3 SQL Injection Prevention

```java
// ✅ Đúng - Parameterized query
@Query("SELECT u FROM User u WHERE u.email = :email")
Optional<User> findByEmail(@Param("email") String email);

// ❌ Sai - String concatenation (SQL Injection risk!)
String query = "SELECT * FROM users WHERE email = '" + email + "'";
```

### 9.4 XSS Prevention

```typescript
// ✅ React automatically escapes content
<div>{userInput}</div>

// ⚠️ Dangerous - Only use when absolutely necessary
<div dangerouslySetInnerHTML={{ __html: sanitizedHTML }} />

// ✅ Sanitize user input
import DOMPurify from 'dompurify';
const sanitizedHTML = DOMPurify.sanitize(userInput);
```

### 9.5 CORS Configuration

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("https://yourdomain.com") // Specific domain
            .allowedMethods("GET", "POST", "PUT", "DELETE")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

### 9.6 Sensitive Data Protection

```java
// ✅ Đúng - Don't log sensitive data
logger.info("User logged in: {}", user.getId());

// ❌ Sai - Logging sensitive data
logger.info("User logged in: {}", user.toString()); // May contain password!

// ✅ Hide sensitive fields in logs
@ToString(exclude = {"password", "creditCard"})
public class User {
    private String password;
    private String creditCard;
}
```

### 9.7 Rate Limiting

```java
// Example với Bucket4j
@GetMapping("/api/resource")
@RateLimiter(name = "basic")
public ResponseEntity<String> getResource() {
    return ResponseEntity.ok("Data");
}

// application.yml
resilience4j.ratelimiter:
  instances:
    basic:
      limitForPeriod: 10
      limitRefreshPeriod: 1s
```

### 9.8 Environment Variables

```bash
# ✅ Đúng - Use environment variables for secrets
DATABASE_URL=jdbc:postgresql://localhost:5432/db
JWT_SECRET=your-secret-key-from-env
API_KEY=your-api-key

# ❌ Sai - Hardcode trong code
String apiKey = "sk-1234567890"; // NEVER!
```

```java
// ✅ Read from environment
@Value("${jwt.secret}")
private String jwtSecret;
```

### 9.9 Dependency Security

- Thường xuyên **update dependencies**
- Scan vulnerabilities với **OWASP Dependency-Check**
- Sử dụng **Dependabot** trên GitHub

```bash
# Check for vulnerabilities
mvn dependency-check:check
npm audit
```

### 9.10 HTTPS Only

```java
// Force HTTPS
@Configuration
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.requiresChannel()
            .anyRequest()
            .requiresSecure();
        return http.build();
    }
}
```

---

## ⚠️ Vi Phạm và Xử Lý

| Mức Độ | Vi Phạm | Hậu Quả |
|--------|---------|---------|
| Nhẹ | Format code sai, thiếu comment | Yêu cầu sửa trong PR |
| Trung bình | Commit message sai convention, branch name sai, vi phạm naming conventions | PR bị reject, yêu cầu sửa |
| Nặng | Push trực tiếp lên main, merge không qua review, code có security vulnerabilities | Revert commit, cảnh cáo nghiêm khắc |
| Rất nặng | Commit sensitive data (API keys, passwords), vi phạm nghiêm trọng security | Revert ngay, rotate credentials, họp kỷ luật |

---

## 📚 Tài Liệu Tham Khảo

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- [Clean Code - Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Refactoring - Martin Fowler](https://refactoring.com/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Test Driven Development](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)

---

**Cập nhật lần cuối**: Tháng 1/2026

**Người phê duyệt**: Team Lead
