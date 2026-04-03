# Luồng Nghiệp Vụ Và Trạng Thái Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Luồng nghiệp vụ runtime, chuyển trạng thái và quy tắc xử lý của moderation-service

## Mục tiêu

Chuẩn hóa các luồng nghiệp vụ moderation theo hành vi triển khai hiện tại để backend, QA và reviewer có thể kiểm chứng cùng một chuẩn: trigger, precondition, trạng thái trước/sau, side effects và error outcomes.

## Danh sách luồng nghiệp vụ cốt lõi

1. Người dùng đã xác thực tạo report.
2. Moderator triage qua danh sách/chi tiết report.
3. Gán case cho moderator.
4. Giải quyết case theo quyết định moderation.
5. Tạo moderation action.
6. Người dùng tạo appeal.
7. Moderator/admin giải quyết appeal.
8. Admin cấp vai trò cho user moderation.

## Định nghĩa trạng thái domain

### ReportStatus

- OPEN
- IN_REVIEW
- RESOLVED
- REJECTED

Ghi chú hiện trạng:

- Luồng create report đang set OPEN.
- Chuyển report sang IN_REVIEW/RESOLVED/REJECTED chưa được service layer cập nhật tường minh trong code hiện tại.

### ModerationCaseStatus

- OPEN
- ASSIGNED
- RESOLVED

### ModerationDecision

- PENDING
- DISMISS
- WARN
- FLAG_MESSAGE
- ESCALATE

### AppealStatus

- PENDING
- APPROVED
- REJECTED

Ghi chú hiện trạng:

- Endpoint resolve appeal hiện chấp nhận cả PENDING từ request vì chưa có rule chặn transition không hợp lệ ở service.

## Bảng chuyển trạng thái chuẩn

### Report

| Từ trạng thái | Sự kiện        | Đến trạng thái         | Trạng thái triển khai      |
| ------------- | -------------- | ---------------------- | -------------------------- |
| N/A           | Tạo report     | OPEN                   | Đã triển khai              |
| OPEN          | Bắt đầu triage | IN_REVIEW              | Chưa triển khai tường minh |
| IN_REVIEW     | Kết thúc xử lý | RESOLVED hoặc REJECTED | Chưa triển khai tường minh |

### Case

| Từ trạng thái      | Sự kiện      | Đến trạng thái               | Trạng thái triển khai |
| ------------------ | ------------ | ---------------------------- | --------------------- |
| N/A                | Tạo report   | OPEN + decision=PENDING      | Đã triển khai         |
| OPEN hoặc ASSIGNED | Assign case  | ASSIGNED                     | Đã triển khai         |
| OPEN hoặc ASSIGNED | Resolve case | RESOLVED + decision cập nhật | Đã triển khai         |

### Appeal

| Từ trạng thái | Sự kiện                    | Đến trạng thái         | Trạng thái triển khai          |
| ------------- | -------------------------- | ---------------------- | ------------------------------ |
| N/A           | Tạo appeal                 | PENDING                | Đã triển khai                  |
| PENDING       | Resolve appeal             | APPROVED hoặc REJECTED | Đã triển khai                  |
| PENDING       | Resolve appeal với PENDING | PENDING                | Được chấp nhận ở code hiện tại |

## Workflow chi tiết

### Workflow 1: Report Creation

- Endpoint: POST /reports
- Tác nhân: USER/MODERATOR/ADMIN đã xác thực
- Preconditions:
  - JWT hợp lệ.
  - Không trùng report trong 24h theo cùng reporter_user_id + target_type + target_id + reason_code.
- Steps chính:
  1.  Validate payload CreateReportRequest.
  2.  Check duplicate window 24h.
  3.  Build evidence snapshot.
  4.  Tạo moderation_report với status=OPEN, priority=MEDIUM.
  5.  Tạo moderation_report_evidence.
  6.  Tạo moderation_case với status=OPEN, decision=PENDING.
  7.  Ghi audit event REPORT_CREATED.
- Postconditions:
  - Có report, case, evidence và audit log tương ứng.
- Lỗi chính:
  - 400 nếu payload không hợp lệ hoặc trùng report trong 24h.
  - 401 nếu thiếu/invalid JWT.

### Workflow 2: Report Discovery and Triage

- Endpoints:
  - GET /api/v1/moderation/reports
  - GET /api/v1/moderation/reports/{reportId}
- Tác nhân: MODERATOR/ADMIN với quyền hiệu lực (moderation_admin_user active)
- Preconditions:
  - JWT hợp lệ.
  - Pass requireModerator guard.
- Steps chính:
  1.  Guard kiểm tra quyền moderator/admin active.
  2.  Query report theo filter (status, targetType, reporterId, targetId, date range).
  3.  Trả danh sách phân trang hoặc chi tiết report.
- Postconditions:
  - Không mutate dữ liệu.
- Lỗi chính:
  - 403 nếu không có quyền moderation hiệu lực.
  - 404 nếu reportId không tồn tại (chi tiết).

### Workflow 3: Case Assignment

- Endpoint: POST /api/v1/moderation/reports/{reportId}/assign
- Tác nhân: MODERATOR/ADMIN active
- Preconditions:
  - Pass requireModerator guard.
  - reportId có case tương ứng.
- Steps chính:
  1.  Tìm case theo reportId.
  2.  Cập nhật assignedModeratorId.
  3.  Cập nhật case status=ASSIGNED.
  4.  Ghi audit event CASE_ASSIGNED với old/new assignee.
- Postconditions:
  - Case được gán moderator.
- Lỗi chính:
  - 404 nếu không tìm thấy case theo reportId.
  - 403 nếu không đủ quyền.

### Workflow 4: Case Resolution

- Endpoint: POST /api/v1/moderation/cases/{caseId}/resolve
- Tác nhân: MODERATOR/ADMIN active
- Preconditions:
  - Pass requireModerator guard.
  - caseId hợp lệ.
- Steps chính:
  1.  Tìm case theo caseId.
  2.  Cập nhật decision theo request.
  3.  Cập nhật note (optional).
  4.  Cập nhật case status=RESOLVED và resolvedAt=now.
  5.  Ghi audit event CASE_RESOLVED.
- Postconditions:
  - Case ở trạng thái RESOLVED.
- Lỗi chính:
  - 404 nếu case không tồn tại.
  - 403 nếu không đủ quyền.

### Workflow 5: Moderation Action Creation

- Endpoint: POST /api/v1/moderation/actions
- Tác nhân: MODERATOR/ADMIN active
- Preconditions:
  - Pass requireModerator guard.
  - caseId tồn tại.
- Steps chính:
  1.  Validate payload action.
  2.  Tìm case theo caseId.
  3.  Tạo moderation_action với actionType và target fields tương ứng.
  4.  Ghi audit event ACTION_CREATED.
- Postconditions:
  - Có action mới gắn với case.
- Lỗi chính:
  - 404 nếu case không tồn tại.
  - 400 nếu payload không hợp lệ.

### Workflow 6: Appeal Creation

- Endpoint: POST /api/v1/moderation/cases/{caseId}/appeal
- Tác nhân: User đã xác thực
- Preconditions:
  - JWT hợp lệ.
  - caseId hợp lệ (FK ở DB sẽ enforce).
- Steps chính:
  1.  Validate reason không rỗng.
  2.  Tạo moderation_appeal với status=PENDING.
  3.  Ghi audit event APPEAL_CREATED.
- Postconditions:
  - Có appeal mới gắn với case.
- Lỗi chính:
  - 400 nếu payload không hợp lệ.
  - 500 có thể xảy ra nếu caseId không hợp lệ ở tầng DB và chưa map lỗi domain cụ thể.

### Workflow 7: Appeal Resolution

- Endpoint: POST /api/v1/moderation/appeals/{appealId}/resolve
- Tác nhân: MODERATOR/ADMIN active
- Preconditions:
  - Pass requireModerator guard.
  - appealId tồn tại.
- Steps chính:
  1.  Tìm appeal theo appealId.
  2.  Cập nhật status theo request.
  3.  Cập nhật moderatorResponse và moderatorId.
  4.  Ghi audit event APPEAL_RESOLVED.
- Postconditions:
  - Appeal được cập nhật trạng thái xử lý.
- Lỗi chính:
  - 403 nếu không đủ quyền.
  - Runtime exception nếu appeal không tồn tại (cần chuẩn hóa về domain error).

### Workflow 8: Admin User Management

- Endpoint: POST /api/v1/admin/users
- Tác nhân: ADMIN active
- Preconditions:
  - Pass requireAdmin guard.
  - Payload chứa userId và role hợp lệ.
- Steps chính:
  1.  Guard requireAdmin.
  2.  Upsert theo save của JPA đối với moderation_admin_user (key user_id).
  3.  Set isActive=true cho bản ghi tạo/cập nhật.
- Postconditions:
  - User mục tiêu có quyền MODERATOR hoặc ADMIN ở trạng thái active.
- Lỗi chính:
  - 403 nếu không phải admin hiệu lực.

## Quản trị chuyển trạng thái

- Mọi thao tác mutate chính cần có audit event tương ứng.
- Rule chuyển trạng thái hiện được thực thi một phần ở service layer; chưa có state machine guard đầy đủ cho mọi transition bị cấm.
- Các mã lỗi transition (ví dụ MODERATION_INVALID_STATUS_TRANSITION) đã được định nghĩa nhưng chưa được sử dụng nhất quán trong service hiện tại.

## Edge case cần giữ vững

- Chống report trùng trong cửa sổ thời gian bảo vệ.
- User không đủ quyền gọi endpoint moderation/admin.
- User moderation không active cố truy cập thao tác đặc quyền.
- Resolve appeal với trạng thái PENDING cần được cân nhắc chặn ở phiên bản kế tiếp.
- Lỗi không tìm thấy appeal hiện chưa chuẩn hóa về domain error thống nhất.

## Kiểm thử trọng yếu theo workflow

1. Report creation:
   - happy path tạo report + case + evidence + audit.
   - duplicate 24h phải fail 400.
2. Guard enforcement:
   - USER bị chặn khỏi moderation/admin endpoints.
   - MODERATOR bị chặn khỏi admin users endpoint.
   - is_active=false bị chặn đúng 403.
3. Case workflow:
   - assign case cập nhật assignee + status ASSIGNED.
   - resolve case cập nhật decision + RESOLVED + resolvedAt.
4. Action workflow:
   - tạo action thành công khi case tồn tại.
5. Appeal workflow:
   - create appeal set PENDING.
   - resolve appeal cập nhật status/response/moderatorId.

## Hướng cải tiến

- Bổ sung bảng chuyển trạng thái tường minh cho từng entity.
- Bổ sung guard transition bị cấm (đặc biệt appeal và report status lifecycle).
- Bổ sung phiên bản 2 cho luồng escalation.
- Chuẩn hóa error handling cho appeal not found và status transition invalid.

## Tài liệu liên quan

- 02-architecture-overview.md
- 04-authn-authz-role-matrix.md
- 05-data-model-and-schema.md
- ../../moderation-service-analysis.md
- 03-api-spec-and-catalog.md
- ../../checklists/moderation-backend-dod.md
