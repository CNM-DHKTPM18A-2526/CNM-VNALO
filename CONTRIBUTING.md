# 📋 Quy Định Đóng Góp - CNM Zalo Clone

> Tài liệu này quy định các chuẩn mực và quy tắc mà tất cả thành viên trong nhóm phải tuân thủ để đảm bảo code sạch, dễ đọc và dễ bảo trì.

---

## 📑 Mục Lục

1. [Commit Message Convention](#1-commit-message-convention)
2. [Quy Tắc Đặt Tên](#2-quy-tắc-đặt-tên)
3. [Cấu Trúc Code](#3-cấu-trúc-code)
4. [Git Workflow](#4-git-workflow)
5. [Code Review Guidelines](#5-code-review-guidelines)
6. [Documentation](#6-documentation)

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

## 4. Git Workflow

### 4.1 Branch Naming

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

### 4.2 Workflow

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

### 4.3 Pull Request

1. **Title**: Theo commit message convention
2. **Description**: 
   - Mô tả thay đổi
   - Link đến issue liên quan
   - Screenshots (nếu có UI changes)
   - Testing checklist
3. **Review**: Cần ít nhất 1 approval trước khi merge
4. **Merge**: Sử dụng "Squash and merge"

---

## 5. Code Review Guidelines

### 5.1 Checklist cho Reviewer

- [ ] Code có tuân thủ conventions không?
- [ ] Logic có đúng không?
- [ ] Có test coverage không?
- [ ] Có security issues không?
- [ ] Performance có ổn không?
- [ ] Documentation có đầy đủ không?

### 5.2 Checklist cho Author

- [ ] Self-review code trước khi tạo PR
- [ ] Chạy tests locally
- [ ] Update documentation nếu cần
- [ ] Resolve conflicts với target branch

---

## 6. Documentation

### 6.1 README.md

Mỗi service/module cần có README với:
- Mô tả ngắn
- Prerequisites
- Installation
- Configuration
- API documentation link
- Contributing guide link

### 6.2 API Documentation

- Sử dụng **Swagger/OpenAPI** cho REST APIs
- Document tất cả endpoints với:
  - Description
  - Request/Response examples
  - Error codes

### 6.3 Code Comments

- Comment **WHY**, không phải **WHAT**
- Giữ comments up-to-date
- Xóa commented-out code

---

## ⚠️ Vi Phạm và Xử Lý

| Mức Độ | Vi Phạm | Hậu Quả |
|--------|---------|---------|
| Nhẹ | Format code sai, thiếu comment | Yêu cầu sửa trong PR |
| Trung bình | Commit message sai convention, branch name sai | PR bị reject, yêu cầu sửa |
| Nặng | Push trực tiếp lên main, merge không qua review | Revert commit, cảnh cáo |

---

## 📚 Tài Liệu Tham Khảo

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- [Clean Code - Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)

---

**Cập nhật lần cuối**: Tháng 1/2026

**Người phê duyệt**: Team Lead
