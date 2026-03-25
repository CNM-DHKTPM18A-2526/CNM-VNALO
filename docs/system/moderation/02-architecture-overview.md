# Tổng Quan Kiến Trúc Moderation Service

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Kiến trúc runtime, mô hình bảo mật và ranh giới tích hợp của moderation-service

## Mục tiêu

Mô tả rõ cấu trúc xử lý request end-to-end của moderation-service, điểm đặt kiểm soát bảo mật, trách nhiệm từng lớp và các quyết định kiến trúc chính để backend, QA, DevOps có cùng góc nhìn triển khai.

## Cấu trúc kiến trúc cấp cao

1. Entry/API layer:
   - `ReportController` cho user report APIs.
   - `ModerationController` cho moderation workflows và appeals moderation.
   - `AdminUserController` cho quản trị quyền moderation.
2. Security layer:
   - `SecurityConfig` cấu hình `SecurityFilterChain`, endpoint policy, custom 401/403 payload.
   - `JwtAuthenticationFilter` đọc Bearer token, validate token và nạp principal vào `SecurityContext`.
   - `ModeratorGuardService` kiểm tra quyền hiệu lực dựa trên `moderation_admin_user`.
3. Domain service layer:
   - `ReportService`, `ModerationCaseService`, `ModerationActionService`, `AppealService`, `AdminUserService`.
4. Supporting services:
   - `EvidenceSnapshotService` chụp snapshot nội dung bị report.
   - `AuditLogService` ghi `old/new` state theo event nghiệp vụ.
5. Persistence layer:
   - Spring Data JPA repositories + PostgreSQL (report/case/action/appeal/admin/audit).
   - Flyway migration quản trị tiến hóa schema.

## Mô hình triển khai runtime

- Nền tảng: Spring Boot 3.x, Java 21.
- Context path: `/api/v1`.
- Health endpoint: `/actuator/health` và `/api/v1/actuator/health`.
- OpenAPI/Swagger được mở cho mục đích khám phá API.
- Cấu hình JWT bắt buộc qua biến môi trường `JWT_SECRET`, `JWT_ISSUER`.

## Luồng request chuẩn

### Luồng endpoint đặc quyền (moderation/admin)

1. Token JWT được xác thực ở security filter.
2. Endpoint policy của `SecurityFilterChain` đảm bảo request đã xác thực.
3. Controller resolve `currentUserId` từ principal/authentication context.
4. `ModeratorGuardService` kiểm tra record hiệu lực trong `moderation_admin_user`:
   - `requireModerator`: MODERATOR hoặc ADMIN, `is_active=true`.
   - `requireAdmin`: ADMIN, `is_active=true`.
5. Domain service thực thi nghiệp vụ và ghi dữ liệu chính.
6. `AuditLogService` ghi sự kiện nghiệp vụ quan trọng (ví dụ: assign/resolve/action/appeal).
7. Trả về payload theo chuẩn `ApiResponse`.

### Luồng endpoint user report

1. Request đi qua JWT filter và endpoint authorization.
2. `ReportController` nhận request tạo report hoặc lấy report của chính user.
3. `ReportService` xử lý nghiệp vụ tạo report/case, chống trùng report theo cửa sổ thời gian bảo vệ.
4. `EvidenceSnapshotService` tạo snapshot ngữ cảnh bằng chứng (user/message).
5. Ghi audit event tương ứng.

## Thiết kế bảo mật và ủy quyền

- Authentication:
  - Bearer JWT là chuẩn bắt buộc cho endpoint nghiệp vụ.
  - 401/403 trả theo payload chuẩn tại `SecurityConfig` và `GlobalExceptionHandler`.
- Authorization theo 2 lớp:
  1. Endpoint-level policy trong `SecurityFilterChain`.
  2. Business guard trong `ModeratorGuardService` dựa vào `moderation_admin_user`.
- Ý nghĩa kiến trúc:
  - Role từ token chỉ là điều kiện cần.
  - Quyền moderation có hiệu lực là điều kiện đủ, tránh bypass khi role không được cấp/đã bị vô hiệu hóa.

## Thành phần logic và trách nhiệm

### API controllers

- `ReportController`: tạo report, lấy report của user hiện tại.
- `ModerationController`: report triage, case operations, action operations, appeal operations.
- `AdminUserController`: tạo/cập nhật user moderation ở mức admin.

### Domain services

- `ReportService`: core flow tạo report + case, query report list/detail.
- `ModerationCaseService`: assign case, resolve case.
- `ModerationActionService`: tạo action xử lý theo case.
- `AppealService`: tạo appeal và resolve appeal.
- `AdminUserService`: quản trị user moderation.

### Supporting services

- `EvidenceSnapshotService`: đóng băng dữ liệu tham chiếu tại thời điểm report.
- `AuditLogService`: truy vết thay đổi trạng thái/decision/action.

## Mô hình dữ liệu và persistence

- Bảng chính: `moderation_report`, `moderation_case`, `moderation_action`, `moderation_appeal`, `moderation_admin_user`, `moderation_audit_log`, `moderation_report_evidence`.
- Data access: Spring Data repositories + query services chia sẻ.
- Migration:
  - Flyway là kênh thay đổi schema bắt buộc.
  - Migration history table riêng cho moderation.
  - Thay đổi schema cần đi qua migration review checklist.

## Tích hợp với hệ thống xung quanh

- Nguồn định danh: JWT claims.
- Nguồn chân lý về quyền: bảng moderation_admin_user.
- Dữ liệu tham chiếu snapshot: query service tới domain user/message liên quan.
- Quyết định truy cập hiệu lực: guard check `requireModerator`/`requireAdmin`.

## Quan sát hệ thống và xử lý lỗi

- Chuẩn lỗi nhất quán cho 400/401/403/404/500 qua `ApiResponse`.
- Global exception handling gom lỗi validation, security, business, unexpected errors.
- Endpoint health phục vụ kiểm tra sẵn sàng runtime.
- Audit log là nguồn dữ liệu chính cho điều tra thay đổi moderation.

## Khoảng trống kiến trúc đã biết

- Chưa có contract phát sự kiện bất đồng bộ.
- Chưa có policy engine riêng cho quyền chi tiết.
- Chưa có cơ chế phân phối tải moderation dựa trên queue nâng cao.

## Ràng buộc vận hành quan trọng

- Thiếu `JWT_SECRET` sẽ làm service/test context không khởi tạo được đầy đủ security beans.
- Endpoint đặc quyền phụ thuộc tính đúng đắn của dữ liệu `moderation_admin_user`.
- Thay đổi schema không qua Flyway có nguy cơ gây drift giữa môi trường.

## Tài liệu liên quan

- 01-service-overview.md
- 03-api-spec-and-catalog.md
- 04-authn-authz-role-matrix.md
- 05-data-model-and-schema.md
- 09-cicd-release-and-rollback.md
- ../../moderation-service-analysis.md
