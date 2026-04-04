# Ma Trận Xác Thực Và Phân Quyền Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Cơ chế xác thực JWT, phân quyền theo role và guard runtime của moderation-service

## Mục tiêu

Chuẩn hóa một nguồn tham chiếu duy nhất cho toàn bộ quyết định truy cập của moderation-service: ai được gọi endpoint nào, điều kiện nào dẫn tới 401/403, và cách kiểm soát quyền được thực thi ở runtime.

## Bối cảnh kỹ thuật

- Service context path: /api/v1.
- Cơ chế xác thực: Bearer JWT.
- Thành phần chính:
  - Security filter chain kiểm soát truy cập theo nhóm endpoint.
  - JWT authentication filter nạp principal từ token.
  - Moderator guard kiểm tra quyền hiệu lực từ bảng moderation_admin_user.

## Xác thực

- Loại token: Bearer JWT.
- Nguồn phát hành token: core-service.
- Token được đọc từ Authorization header theo chuẩn Bearer.
- Request không xác thực vào endpoint bảo vệ trả về 401.
- Cấu hình JWT runtime yêu cầu biến môi trường JWT_SECRET; thiếu cấu hình này có thể làm context bảo mật không khởi tạo đầy đủ.

## Phân quyền

### Mô hình phân quyền hai lớp

1. Lớp 1 - Endpoint policy (SecurityFilterChain):
   - Endpoint report của user yêu cầu role USER/MODERATOR/ADMIN.
   - Endpoint dưới /moderation và /admin yêu cầu đã xác thực.
2. Lớp 2 - Guard nghiệp vụ (ModeratorGuardService):
   - requireModerator: user có record moderation_admin_user active với role MODERATOR hoặc ADMIN.
   - requireAdmin: user có record moderation_admin_user active với role ADMIN.

Kết luận runtime:

- Role trong JWT là điều kiện cần.
- Record quyền hiệu lực trong moderation_admin_user là điều kiện đủ cho endpoint đặc quyền.

## Chính sách phân quyền runtime

- Endpoint cho người dùng:
  - POST /reports
  - GET /reports/me
- Endpoint cho moderator/admin:
  - /api/v1/moderation/\* (ngoại lệ: tạo appeal vẫn theo luồng user đã xác thực)
- Endpoint chỉ admin:
  - POST /api/v1/admin/users

## Ma trận endpoint chi tiết

| Endpoint                                           | USER  | MODERATOR | ADMIN | Guard runtime bắt buộc | Kỳ vọng khi thiếu quyền |
| -------------------------------------------------- | ----- | --------- | ----- | ---------------------- | ----------------------- |
| GET /actuator/health                               | Có    | Có        | Có    | Không                  | N/A                     |
| POST /reports                                      | Có    | Có        | Có    | Không                  | 401 nếu thiếu JWT       |
| GET /reports/me                                    | Có    | Có        | Có    | Không                  | 401 nếu thiếu JWT       |
| GET /api/v1/moderation/reports                     | Không | Có        | Có    | requireModerator       | 403                     |
| GET /api/v1/moderation/reports/{reportId}          | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/moderation/reports/{reportId}/assign  | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/moderation/cases/{caseId}/resolve     | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/moderation/actions                    | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/moderation/cases/{caseId}/appeal      | Có    | Có        | Có    | Không                  | 401 nếu thiếu JWT       |
| GET /api/v1/moderation/appeals                     | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/moderation/appeals/{appealId}/resolve | Không | Có        | Có    | requireModerator       | 403                     |
| POST /api/v1/admin/users                           | Không | Không     | Có    | requireAdmin           | 403                     |

## Ma trận vai trò hiệu lực

| Nhóm endpoint                          | USER  | MODERATOR | ADMIN |
| -------------------------------------- | ----- | --------- | ----- |
| Tạo report và xem report của mình      | Có    | Có        | Có    |
| Triage moderation và xử lý case/action | Không | Có        | Có    |
| Danh sách/giải quyết appeal            | Không | Có        | Có    |
| Quản trị user admin                    | Không | Không     | Có    |

## Quy tắc ra quyết định 401 và 403

- Trả về 401 khi:
  - Thiếu Bearer token.
  - Token không hợp lệ/hết hạn/sai issuer.
  - Principal không resolve được user ID hợp lệ.
- Trả về 403 khi:
  - Đã xác thực nhưng không đủ vai trò endpoint.
  - Có role token nhưng không có record moderation_admin_user hợp lệ.
  - Có record moderation_admin_user nhưng is_active=false.
  - MODERATOR gọi endpoint chỉ dành cho ADMIN.

## Các kịch bản kiểm thử bắt buộc

1. USER gọi /api/v1/moderation/reports phải bị 403.
2. MODERATOR gọi /api/v1/admin/users phải bị 403.
3. ADMIN gọi toàn bộ endpoint moderation + admin users phải thành công theo contract.
4. User có role token nhưng thiếu moderation_admin_user phải bị 403 ở endpoint đặc quyền.
5. User có moderation_admin_user nhưng is_active=false phải bị 403.
6. Request thiếu JWT vào endpoint bảo vệ phải bị 401.

### Postman Testing

**Collection**: `moderation-e2e-multi-role.postman_collection.json` (recommended)

Covers all scenarios above:

- **PHASE 1**: Admin bootstrap (seeding role record)
- **PHASE 2**: USER flow (report creation) + verifies USER cannot access /moderation
- **PHASE 3**: ADMIN flow (case processing) + verifies ADMIN has full access

**Environment**: `moderation-local.postman_environment.json`

- Separate credentials: testAdminPhone vs testUserPhone
- Separate tokens: adminAccessToken vs userAccessToken
- Automatic variable capture via Postman test scripts

## Ghi chú bảo mật

- Chỉ có role trong JWT là chưa đủ để truy cập moderation/admin.
- Thiếu record moderation_admin_user hoặc record không active phải fail 403.
- Bắt buộc check phân quyền ở controller flow trước khi mutate dữ liệu.
- Payload lỗi bảo mật phải theo chuẩn ApiResponse để frontend map ổn định.

## Hướng cải tiến

- Bổ sung chính sách vòng đời role: cấp, tạm ngưng, thu hồi, hết hạn.
- Bổ sung ma trận quyền chi tiết hơn ngoài mức role.
- Bổ sung chính sách ABAC theo đối tượng nghiệp vụ (case ownership, scope moderation theo miền).
- Bổ sung kiểm thử tự động cho mọi tổ hợp role x endpoint ở mức contract test.

## Tài liệu liên quan

- 02-architecture-overview.md
- 03-api-spec-and-catalog.md
- 07-testing-strategy-and-quality.md
- ../../checklists/moderation-backend-dod.md
