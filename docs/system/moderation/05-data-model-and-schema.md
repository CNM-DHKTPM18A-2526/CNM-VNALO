# Mô Hình Dữ Liệu Và Schema Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Entity domain, DDL schema, chỉ mục, toàn vẹn dữ liệu và quản trị migration của moderation-service

## Mục tiêu

Chuẩn hóa một nguồn dữ liệu kỹ thuật duy nhất cho backend, QA và review migration: định nghĩa bảng, kiểu dữ liệu, ràng buộc, enum, index, cùng các quy tắc dữ liệu ở runtime.

## Nguồn chuẩn áp dụng

- Entity/JPA: package model.entity trong moderation-service.
- Migration Flyway:
  - V1\_\_init_moderation_schema.sql
  - V2\_\_add_appeal_table.sql
- Enum domain: package model.enums.

## Danh sách bảng hiện hành

1. moderation_report
2. moderation_report_evidence
3. moderation_case
4. moderation_action
5. moderation_appeal
6. moderation_admin_user
7. moderation_audit_log

## Entity cốt lõi

- ModerationReport: dữ liệu tiếp nhận report và metadata.
- ModerationReportEvidence: snapshot bằng chứng tại thời điểm report.
- ModerationCase: vòng đời case và trạng thái quyết định.
- ModerationAction: hành động xử lý gắn với case.
- ModerationAppeal: yêu cầu appeal và kết quả xử lý.
- ModerationAdminUser: gán vai trò moderation có hiệu lực.
- ModerationAuditLog: nhật ký hành động bất biến.

## Từ điển bảng và trường

### 1) moderation_report

- Mục đích: bản ghi gốc của report do user tạo.
- Khóa chính: report_id (UUID).
- Trường:
  - report_id: UUID, PK, default gen_random_uuid().
  - reporter_user_id: UUID, NOT NULL.
  - target_type: VARCHAR(20), NOT NULL, enum ReportTargetType.
  - target_id: UUID, NOT NULL.
  - reason_code: VARCHAR(50), NOT NULL.
  - description: VARCHAR(1000), NULL.
  - status: VARCHAR(20), NOT NULL, enum ReportStatus.
  - priority: VARCHAR(20), NOT NULL, enum ReportPriority.
  - created_at: TIMESTAMPTZ, default now().

### 2) moderation_report_evidence

- Mục đích: lưu snapshot JSONB của đối tượng bị report.
- Khóa chính: evidence_id (UUID).
- Trường:
  - evidence_id: UUID, PK.
  - report_id: UUID, NOT NULL.
  - snapshot_json: JSONB, NOT NULL.
  - created_at: TIMESTAMPTZ, default now().

### 3) moderation_case

- Mục đích: case moderation tương ứng với report.
- Khóa chính: case_id (UUID).
- Ràng buộc đáng chú ý: report_id UNIQUE (một report một case).
- Trường:
  - case_id: UUID, PK.
  - report_id: UUID, NOT NULL, UNIQUE.
  - assigned_moderator_id: UUID, NULL.
  - status: VARCHAR(20), NOT NULL, enum ModerationCaseStatus.
  - decision: VARCHAR(30), NOT NULL, enum ModerationDecision.
  - note: VARCHAR(1000), NULL.
  - created_at: TIMESTAMPTZ, default now().
  - resolved_at: TIMESTAMPTZ, NULL.

### 4) moderation_action

- Mục đích: ghi nhận enforcement action phát sinh từ case.
- Khóa chính: action_id (UUID).
- Trường:
  - action_id: UUID, PK.
  - case_id: UUID, NOT NULL.
  - action_type: VARCHAR(40), NOT NULL, enum ModerationActionType.
  - target_user_id: UUID, NULL.
  - target_message_id: UUID, NULL.
  - target_conversation_id: UUID, NULL.
  - reason: VARCHAR(1000), NULL.
  - created_by: UUID, NOT NULL.
  - created_at: TIMESTAMPTZ, default now().

### 5) moderation_appeal

- Mục đích: lưu vòng đời appeal của user với quyết định moderation.
- Khóa chính: appeal_id (UUID).
- Foreign key hiện có: case_id -> moderation_case(case_id).
- Trường:
  - appeal_id: UUID, PK.
  - case_id: UUID, NOT NULL, FK.
  - user_id: UUID, NOT NULL.
  - reason: VARCHAR(1000), NOT NULL.
  - status: VARCHAR(20), NOT NULL, enum AppealStatus.
  - moderator_response: VARCHAR(1000) ở DDL, entity đang map String không giới hạn length annotation.
  - moderator_id: UUID, NULL.
  - created_at: TIMESTAMPTZ, default now().
  - updated_at: TIMESTAMPTZ, default now().

### 6) moderation_admin_user

- Mục đích: nguồn quyền moderation có hiệu lực ở runtime.
- Khóa chính: user_id (UUID).
- Trường:
  - user_id: UUID, PK.
  - role: VARCHAR(20), NOT NULL, enum ModerationAdminRole.
  - is_active: BOOLEAN, NOT NULL.
  - created_at: TIMESTAMPTZ, default now().
  - updated_at: TIMESTAMPTZ, default now().

### 7) moderation_audit_log

- Mục đích: audit trail cho thay đổi quan trọng.
- Khóa chính: audit_log_id (UUID).
- Trường:
  - audit_log_id: UUID, PK.
  - report_id: UUID, NULL.
  - case_id: UUID, NULL.
  - action: VARCHAR(50), NOT NULL.
  - old_value_json: JSONB, NULL.
  - new_value_json: JSONB, NULL.
  - performed_by: UUID, NOT NULL.
  - created_at: TIMESTAMPTZ, default now().

## Trạng thái và enum domain

- ReportTargetType: USER, MESSAGE.
- ReportStatus: OPEN, IN_REVIEW, RESOLVED, REJECTED.
- ReportPriority: LOW, MEDIUM, HIGH.
- ModerationCaseStatus: OPEN, ASSIGNED, RESOLVED.
- ModerationDecision: PENDING, DISMISS, WARN, FLAG_MESSAGE, ESCALATE.
- ModerationActionType: WARN_USER, FLAG_MESSAGE, DISMISS_REPORT, ESCALATE_CASE.
- AppealStatus: PENDING, APPROVED, REJECTED.
- ModerationAdminRole: MODERATOR, ADMIN.

## Chỉ mục (index) hiện có

- moderation_report:
  - idx_report_reporter(reporter_user_id)
  - idx_report_target(target_type, target_id)
  - idx_report_status(status)
- moderation_report_evidence:
  - idx_evidence_report(report_id)
- moderation_case:
  - idx_case_report(report_id)
  - idx_case_moderator(assigned_moderator_id)
- moderation_action:
  - idx_action_case(case_id)
- moderation_audit_log:
  - idx_audit_report(report_id)
  - idx_audit_case(case_id)
- moderation_appeal:
  - idx_appeal_case(case_id)
  - idx_appeal_user(user_id)
  - idx_appeal_status(status)

## Quy tắc toàn vẹn dữ liệu (hiện tại)

- Quyền truy cập đặc quyền chỉ hợp lệ khi có moderation_admin_user và is_active=true.
- Mỗi report chỉ có một case theo ràng buộc UNIQUE(report_id) ở moderation_case.
- Tạo report mới luôn tạo đồng thời:
  - moderation_report
  - moderation_report_evidence
  - moderation_case với decision mặc định PENDING
- Chống report trùng trong cửa sổ 24h theo bộ khóa logic:
  - reporter_user_id + target_type + target_id + reason_code + created_at_after
- Case resolve bắt buộc cập nhật decision, status, resolved_at.
- Action/Appeal/Case changes phải sinh audit log tương ứng.

## Quan hệ dữ liệu và cardinality logic

- moderation_report 1 - 1 moderation_case (enforced bằng UNIQUE report_id ở case).
- moderation_report 1 - 1 moderation_report_evidence (logic nghiệp vụ; DDL hiện tại chưa có UNIQUE report_id).
- moderation_case 1 - N moderation_action.
- moderation_case 1 - N moderation_appeal.
- moderation_case 1 - N moderation_audit_log (theo event).

## Điểm cần lưu ý về schema hiện trạng

- DDL chưa khai báo đầy đủ FK cho nhiều cột tham chiếu UUID (ví dụ report_id ở evidence/case, case_id ở action, report_id/case_id ở audit_log).
- Điều này đang được bù bởi kiểm soát ở service/repository; vẫn có rủi ro dữ liệu orphan nếu ghi ngoài service layer.
- Cần cân nhắc roadmap thêm FK theo từng bước để tránh lock/risk khi migrate production.

## Chính sách migration và rollback

- Flyway là cơ chế bắt buộc cho mọi thay đổi schema.
- Không chỉnh tay schema trực tiếp trên môi trường dùng chung.
- Mỗi migration phải có:
  - mô tả mục tiêu thay đổi,
  - đánh giá tác động dữ liệu cũ,
  - phương án rollback hoặc mitigation rõ ràng.
- Review migration bắt buộc qua workflow migration guard và checklist DoD moderation.

## Quản trị migration

- V1 khởi tạo schema moderation lõi.
- V2 bổ sung bảng moderation_appeal và index/FK case_id.
- Mọi thay đổi entity/repository phải đi kèm migration review và pass workflow `.github/workflows/moderation-migration-required.yml`.
- Thay đổi phá hủy phải có ghi chú rollback và phương án giảm thiểu.

## Hướng bổ sung

- Chuẩn hóa đầy đủ foreign key cho các quan hệ UUID quan trọng.
- Bổ sung UNIQUE(report_id) cho moderation_report_evidence nếu tiếp tục giữ cardinality 1-1.
- Bổ sung ERD trực quan trong docs/diagrams để onboarding nhanh.
- Bổ sung retention policy rõ ràng cho audit_log và appeal data.

## Tài liệu liên quan

- 02-architecture-overview.md
- 04-authn-authz-role-matrix.md
- 09-cicd-release-and-rollback.md
- ../../moderation-service-analysis.md
- ../../checklists/moderation-backend-dod.md
