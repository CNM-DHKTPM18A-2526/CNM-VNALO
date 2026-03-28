# Đặc Tả Và Danh Mục API Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Tài liệu tổng hợp đầy đủ contract API, hướng dẫn test, quy tắc chất lượng cho moderation-service

## Mục tiêu

Tập trung toàn bộ thông tin kỹ thuật cần thiết để backend, QA và frontend làm việc với moderation-service trong một tài liệu duy nhất.

## 1. Phạm vi dịch vụ

- Service: moderation-service
- Base URL local mặc định: http://localhost:8082/api/v1
- Health endpoint: GET /actuator/health
- Swagger endpoints:
  - /swagger-ui/index.html
  - /v3/api-docs

## 2. Xác thực và phân quyền

Tất cả endpoint nghiệp vụ dùng Bearer JWT, trừ health và swagger.

Quyền truy cập theo vai trò:

- USER:
  - POST /reports
  - GET /reports/me
- MODERATOR:
  - Toàn bộ endpoint dưới /api/v1/moderation/\*
- ADMIN:
  - Toàn bộ quyền của MODERATOR
  - POST /api/v1/admin/users

Lưu ý quan trọng:

- Ngoài role trong token, service còn kiểm tra bảng moderation_admin_user.
- Endpoint đặc quyền yêu cầu record hợp lệ và is_active=true.

## 3. Quy tắc contract chuẩn

- Tất cả endpoint nghiệp vụ trả về theo chuẩn ApiResponse.
- Định dạng lỗi ổn định theo code và errorCode.
- Endpoint đặc quyền bắt buộc JWT hợp lệ và pass guard moderation_admin_user.

## 4. Danh mục API hiện hành

### 4.1 Public/System

1. GET /actuator/health

- Mục đích: kiểm tra service sống.
- Auth: không cần token.

### 4.2 User Report APIs

1. POST /reports

- Mục đích: tạo report mới.
- Auth: USER, MODERATOR, ADMIN.
- Request body:
  - targetType: USER | MESSAGE
  - targetId: UUID
  - reasonCode: string (max 50)
  - description: string (max 1000, optional)
- Response data:
  - reportId
  - caseId
  - status

2. GET /reports/me?page=0&size=20

- Mục đích: lấy danh sách report của user đang đăng nhập.
- Auth: USER, MODERATOR, ADMIN.

### 4.3 Admin User APIs

1. POST /api/v1/admin/users

- Mục đích: thêm/cập nhật user moderation.
- Auth: ADMIN.
- Request body:
  - userId: UUID
  - role: MODERATOR | ADMIN

### 4.4 Moderation APIs

1. GET /api/v1/moderation/reports?page=0&size=20&status=&targetType=

- Mục đích: lấy danh sách report cho moderator.
- Auth: MODERATOR, ADMIN.
- Query params:
  - status (optional): OPEN | IN_REVIEW | RESOLVED | REJECTED
  - targetType (optional): USER | MESSAGE
  - page, size

2. GET /api/v1/moderation/reports/{reportId}

- Mục đích: lấy chi tiết report.
- Auth: MODERATOR, ADMIN.

3. POST /api/v1/moderation/reports/{reportId}/assign

- Mục đích: gán case cho moderator.
- Auth: MODERATOR, ADMIN.
- Request body:
  - moderatorId: UUID

4. POST /api/v1/moderation/cases/{caseId}/resolve

- Mục đích: xử lý case.
- Auth: MODERATOR, ADMIN.
- Request body:
  - decision: PENDING | DISMISS | WARN | FLAG_MESSAGE | ESCALATE
  - note: string (max 1000, optional)

5. POST /api/v1/moderation/actions

- Mục đích: tạo moderation action.
- Auth: MODERATOR, ADMIN.
- Request body:
  - caseId: UUID
  - actionType: WARN_USER | FLAG_MESSAGE | DISMISS_REPORT | ESCALATE_CASE
  - targetUserId: UUID (optional)
  - targetMessageId: UUID (optional)
  - targetConversationId: UUID (optional)
  - reason: string (max 1000, optional)

6. POST /api/v1/moderation/cases/{caseId}/appeal

- Mục đích: tạo appeal cho case.
- Auth: user đã đăng nhập (token hợp lệ).
- Request body:
  - reason: string (required)

7. GET /api/v1/moderation/appeals?page=0&size=20

- Mục đích: lấy danh sách appeal.
- Auth: MODERATOR, ADMIN.

8. POST /api/v1/moderation/appeals/{appealId}/resolve

- Mục đích: phê duyệt/từ chối appeal.
- Auth: MODERATOR, ADMIN.
- Request body:
  - status: PENDING | APPROVED | REJECTED
  - response: string (optional)

## 5. Danh mục chức năng nghiệp vụ

1. Tiếp nhận report

- User gửi report với target user/message.
- Hệ thống tạo report và case ban đầu.

2. Hàng đợi triage cho moderator

- Moderator xem report theo filter.
- Moderator xem chi tiết report để đánh giá.

3. Gán case

- Gán case cho moderator phụ trách.

4. Giải quyết case

- Moderator đưa ra quyết định moderation cho case.

5. Thực thi action

- Tạo action xử lý đối tượng vi phạm.

6. Vòng đời appeal

- User tạo appeal sau khi case được xử lý.
- Moderator/Admin xem và resolve appeal.

7. Quản trị vai trò moderation

- ADMIN cấp quyền MODERATOR/ADMIN.

## 6. Ma trận role theo endpoint

| Endpoint                                           | USER  | MODERATOR | ADMIN | Ghi chú                        |
| -------------------------------------------------- | ----- | --------- | ----- | ------------------------------ |
| GET /actuator/health                               | Có    | Có        | Có    | Public                         |
| POST /reports                                      | Có    | Có        | Có    | Tạo report                     |
| GET /reports/me                                    | Có    | Có        | Có    | Report của user đang đăng nhập |
| GET /api/v1/moderation/reports                     | Không | Có        | Có    | Danh sách report moderation    |
| GET /api/v1/moderation/reports/{reportId}          | Không | Có        | Có    | Chi tiết report                |
| POST /api/v1/moderation/reports/{reportId}/assign  | Không | Có        | Có    | Gán case                       |
| POST /api/v1/moderation/cases/{caseId}/resolve     | Không | Có        | Có    | Resolve case                   |
| POST /api/v1/moderation/actions                    | Không | Có        | Có    | Tạo moderation action          |
| POST /api/v1/moderation/cases/{caseId}/appeal      | Có    | Có        | Có    | Tạo appeal                     |
| GET /api/v1/moderation/appeals                     | Không | Có        | Có    | Danh sách appeal               |
| POST /api/v1/moderation/appeals/{appealId}/resolve | Không | Có        | Có    | Resolve appeal                 |
| POST /api/v1/admin/users                           | Không | Không     | Có    | Cấp quyền MODERATOR/ADMIN      |

Lưu ý:

- Có role trong JWT nhưng không có record moderation_admin_user hợp lệ (hoặc is_active=false) vẫn bị từ chối.

## 7. Chuẩn lỗi và error contract

Mã lỗi chung:

- ERR_400: Validation failed / malformed request
- ERR_401: Unauthorized
- ERR_403: Access denied
- ERR_404: Resource not found
- ERR_500: Internal server error
- MOD_001..MOD_010: domain errors của moderation

Mẫu response lỗi chuẩn:

```json
{
  "success": false,
  "message": "Validation failed",
  "data": null,
  "code": 400,
  "errorCode": "ERR_400",
  "details": {
    "field": "must not be null"
  }
}
```

Quy ước field:

- code: HTTP status code.
- errorCode: mã lỗi ổn định để frontend map logic.
- message: thông điệp hiển thị/ghi log.
- details: chi tiết validation hoặc ngữ cảnh lỗi.

## 8. Hướng dẫn test thủ công bằng Postman

### 8.1 Điều kiện trước khi test

- Docker stack đã chạy:
  - core-service: http://localhost:8081
  - moderation-service: http://localhost:8082
- Health check:
  - GET http://localhost:8081/api/v1/actuator/health
  - GET http://localhost:8082/api/v1/actuator/health

### 8.2 Postman Collections & Environments

**Environment**: `moderation-local.postman_environment.json`

- Base URLs, role-separated phone/password, tokens, resource IDs

**Collections** (2 options):

1. **moderation-e2e.postman_collection.json** (Legacy - single admin account)
   - All operations from 1 admin account
   - For quick smoke test
   - Not recommended for role-based testing

2. **moderation-e2e-multi-role.postman_collection.json** (Recommended)
   - Phase 1: Bootstrap admin (register → login → seed ADMIN role)
   - Phase 2: User flow (user register → login → create report → create appeal)
   - Phase 3: Admin flow (admin assign case → resolve case → resolve appeal)
   - Tests role separation: USER cannot perform admin actions
   - More realistic end-to-end scenario

### 8.3 Bootstrap - Admin Role Setup (Required)

After admin login, you'll have `{{adminUserId}}` in environment.

Run this SQL on postgres:

```bash
docker exec -it vnalo-postgres psql -U postgres -d vnalo_core -c "
INSERT INTO moderation_admin_user(user_id, role, is_active, created_at, updated_at)
VALUES ('<paste-adminUserId-here>', 'ADMIN', true, now(), now())
ON CONFLICT (user_id)
DO UPDATE SET role='ADMIN', is_active=true, updated_at=now();
"
```

**For multi-role testing: Repeat for TEST USERS if needed**

- Regular users (USER role) don't need moderation_admin_user entry
- Only MODERATOR/ADMIN roles require moderation_admin_user record

### 8.4 Multi-Role Flow (Recommended)

**PHASE 1 - Bootstrap Admin**

- Health check moderation service
- Admin register (testAdminPhone / testAdminPassword)
- Admin login → captures adminAccessToken + adminUserId
- Manual SQL: Seed ADMIN role
- Admin upsert self as ADMIN

**PHASE 2 - User Flow**

- User register (testUserPhone / testUserPassword)
- User login → captures userAccessToken + userId
- User creates report (targeting admin user) → captures reportId + caseId
- User views own reports
- User creates appeal with reason → captures appealId

**PHASE 3 - Admin Flow**

- Admin gets paginated reports
- Admin views report detail
- Admin assigns case to self
- Admin resolves case (decision WARN)
- Admin creates action (WARN_USER on reporter)
- Admin gets paginated appeals
- Admin resolves appeal (status APPROVED)

### 8.5 Environment Variables

**Account credentials** (change as needed):

- `testAdminPhone`: +84901112222
- `testAdminPassword`: Test@1234
- `testUserPhone`: +84901112333
- `testUserPassword`: UserTest@1234

**Captured during test**:

- `adminAccessToken`: JWT token for ADMIN
- `adminUserId`: UUID from ADMIN JWT
- `userAccessToken`: JWT token for USER
- `userId`: UUID from USER JWT
- `reportId`: Created by user
- `caseId`: Auto-created with report
- `appealId`: Created by user

### 8.6 Common Errors & Troubleshooting

| Error            | Cause                           | Solution                                                 |
| ---------------- | ------------------------------- | -------------------------------------------------------- |
| 401 Unauthorized | Missing/invalid token           | Re-run auth login request                                |
| 403 Forbidden    | No moderation_admin_user record | Run bootstrap SQL                                        |
| 404 Not Found    | Wrong route path                | Check if moderation-service restarted after code changes |
| 400 Bad Request  | Missing required field          | Check request body schema                                |

### 8.7 Running Full E2E

1. Import environment: `moderation-local.postman_environment.json`
2. Import collection: `moderation-e2e-multi-role.postman_collection.json`
3. Select correct environment
4. Run PHASE 1 requests sequentially (stop at bootstrap SQL step)
5. Execute bootstrap SQL manually on postgres
6. Continue PHASE 1 remaining requests
7. Run PHASE 2 requests sequentially
8. Run PHASE 3 requests sequentially

Each request captures and stores data for next requests using Postman test scripts (pm.environment.set).

## 9. Tiêu chí hoàn tất backend (DoD tóm tắt)

- [x] Functional coverage cho các luồng chính moderation.
- [x] Authorization rules cho USER/MODERATOR/ADMIN.
- [x] Validation và error contract ổn định.
- [x] Regression guards cho principal null, SQL schema drift, JSONB audit log.
- [x] Unit + integration test đã có.
- [x] CI chạy test moderation trên PR.
- [ ] Required status check chặn merge khi test fail.

Ghi nhận kiểm thử hiện tại:

- Tổng 39 tests.
- SecurityAndErrorContractIntegrationTest: 13 test cases.
- RegressionGuardIntegrationTest: 7 test cases.
- FunctionalCoverageIntegrationTest: 9 test cases.

## 10. Quy tắc versioning và thay đổi tài liệu

- Chiến lược version base path hiện tại: /api/v1.
- Thay đổi phá vỡ tương thích phải đổi path hoặc nâng version contract rõ ràng.
- Khi thay đổi endpoint:
  1.  Cập nhật triển khai endpoint.
  2.  Cập nhật ngay tài liệu này.
  3.  Cập nhật Postman collection/environment.
  4.  Cập nhật regression tests và mục DoD liên quan.
