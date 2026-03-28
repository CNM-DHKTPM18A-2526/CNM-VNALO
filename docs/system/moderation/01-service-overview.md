# Tổng Quan Dịch Vụ Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Tổng quan nghiệp vụ, ranh giới kỹ thuật và baseline chất lượng của moderation-service

## Mục tiêu

Tài liệu này đóng vai trò "entry point" cho moderation-service: mô tả dịch vụ giải quyết bài toán gì, ai sử dụng, luồng giá trị chính, ranh giới với các dịch vụ khác, và các mốc chất lượng cần đạt trước khi phát hành.

## Sứ mệnh dịch vụ

Moderation-service cung cấp nền tảng kiểm duyệt nội dung theo vòng đời khép kín:

1. Tiếp nhận report từ người dùng.
2. Hỗ trợ moderator triage, điều phối và ra quyết định.
3. Thực thi moderation action có kiểm soát và truy vết.
4. Quản lý vòng đời appeal để đảm bảo khả năng khiếu nại.
5. Đảm bảo quyền truy cập endpoint đặc quyền thông qua guard runtime.

## Đối tượng sử dụng và giá trị

### Người dùng cuối (USER)

- Gửi report với đối tượng `USER` hoặc `MESSAGE`.
- Theo dõi danh sách report của chính mình.
- Tạo appeal sau khi case đã được xử lý.

Giá trị nhận được: có kênh phản hồi vi phạm rõ ràng, có cơ chế khiếu nại chính thức.

### Moderator (MODERATOR)

- Xem danh sách report theo bộ lọc nghiệp vụ.
- Xem chi tiết report để đánh giá ngữ cảnh.
- Gán/nhận case, resolve case và tạo action xử lý.
- Duyệt và resolve appeal.

Giá trị nhận được: luồng xử lý tập trung, có audit log cho mọi thay đổi quan trọng.

### Admin (ADMIN)

- Có toàn bộ quyền của moderator.
- Quản trị user moderation qua endpoint admin.

Giá trị nhận được: kiểm soát vòng đời cấp quyền moderation tập trung.

## Năng lực nghiệp vụ cốt lõi

1. Report intake:
   Tạo report, chống trùng trong cửa sổ bảo vệ, tạo case tương ứng và snapshot bằng chứng.
2. Case triage and resolution:
   Lọc report theo trạng thái/đối tượng, gán case và đưa ra quyết định xử lý.
3. Enforcement actions:
   Tạo moderation action gắn với case và ghi nhận audit trail.
4. Appeal lifecycle:
   Người dùng tạo appeal, moderator/admin xử lý kết quả appeal.
5. Access governance:
   Endpoint đặc quyền yêu cầu đồng thời JWT hợp lệ và record hiệu lực trong `moderation_admin_user`.

## Ranh giới dịch vụ

### Trong phạm vi hiện tại

- API cho report, moderation workflows, appeal workflows, admin user management.
- Kiểm soát xác thực/phân quyền cho endpoint đặc quyền.
- Ghi nhận audit log cho các thao tác làm thay đổi trạng thái quan trọng.
- Cung cấp hợp đồng lỗi ổn định để frontend/QA tích hợp.

### Ngoài phạm vi hiện tại

- Phát hiện vi phạm tự động bằng ML/risk scoring.
- Trung tâm cảnh báo realtime chuyên dụng cho moderator.
- Quy trình escalation nhiều cấp reviewer và legal hold nâng cao.
- Policy engine tách biệt cho quyền chi tiết ngoài mức role.

## Bức tranh tích hợp hệ thống

- Xác thực: Bearer JWT do core-service phát hành.
- Ủy quyền runtime endpoint đặc quyền: guard dựa trên bảng `moderation_admin_user` và `is_active=true`.
- Dữ liệu tham chiếu: user/profile và đối tượng nội dung từ các domain liên quan.
- Dữ liệu nội bộ moderation: report, case, action, appeal, admin user, audit log trong PostgreSQL.
- Quản trị schema: Flyway migration với quy trình review migration.

## Luồng giá trị end-to-end

1. User tạo report (`POST /reports`).
2. Hệ thống tạo report/case, snapshot bằng chứng, ghi audit `REPORT_CREATED`.
3. Moderator xem danh sách và chi tiết report (`GET /api/v1/moderation/reports`).
4. Moderator gán case (`POST /api/v1/moderation/reports/{reportId}/assign`).
5. Moderator resolve case (`POST /api/v1/moderation/cases/{caseId}/resolve`).
6. Moderator tạo action xử lý (`POST /api/v1/moderation/actions`) khi cần.
7. User tạo appeal (`POST /api/v1/moderation/cases/{caseId}/appeal`).
8. Moderator/Admin resolve appeal (`POST /api/v1/moderation/appeals/{appealId}/resolve`).

## Mục tiêu chất lượng và độ tin cậy

- Bảo mật:
  - Endpoint đặc quyền phải qua cả kiểm tra JWT và moderation guard.
  - Sai quyền hoặc role không active phải trả về 403 nhất quán.
- Contract API:
  - Phản hồi nghiệp vụ theo chuẩn `ApiResponse`.
  - Lỗi chuẩn hóa với `code` + `errorCode` ổn định.
- Chất lượng phát hành:
  - Unit/integration/regression tests cho luồng trọng yếu.
  - CI moderation tests phải pass trước merge.
  - Tài liệu API, checklist và artifact test phải đồng bộ.

## Rủi ro và giới hạn đã biết

- Chưa có contract event-driven bất đồng bộ cho moderation actions.
- Chưa có bộ SLO/SLA chi tiết theo endpoint và backlog appeal.

## Điều hướng tài liệu

- API contract và danh mục endpoint: `03-api-spec-and-catalog.md`
- Kiến trúc runtime: `02-architecture-overview.md`
- Ma trận authn/authz: `04-authn-authz-role-matrix.md`
- Data model và migration: `05-data-model-and-schema.md`
- Workflows và trạng thái: `06-business-workflows-and-states.md`
- Test strategy và quality gates: `07-testing-strategy-and-quality.md`
- Runbook vận hành: `08-operations-runbook-and-observability.md`
- CI/CD và rollback: `09-cicd-release-and-rollback.md`
- DoD và quality gates: `10-definition-of-done-and-quality-gates.md`
- Phân tích chi tiết service: `../../moderation-service-analysis.md`
- Checklist backend release: `../../checklists/moderation-backend-dod.md`
