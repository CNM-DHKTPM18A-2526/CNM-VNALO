# Tiêu Chí Hoàn Tất Và Cổng Chất Lượng Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team (Dev 4)
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Định nghĩa hoàn tất kỹ thuật và cổng chất lượng trước merge/release cho moderation-service

## Mục tiêu

Chuẩn hóa một bộ tiêu chí có thể kiểm chứng để trả lời 3 câu hỏi trước khi phát hành:

1. Thay đổi đã hoàn tất về mặt chức năng và bảo mật chưa?
2. Cổng chất lượng tự động đã đạt chưa?
3. Bằng chứng vận hành và rollback đã đủ để triển khai an toàn chưa?

## Tham chiếu DoD chính

- Checklist chuẩn: ../../checklists/moderation-backend-dod.md

## Phạm vi áp dụng

- Áp dụng cho mọi thay đổi trong moderation-service, bao gồm:
  - API contract.
  - Business workflows.
  - Authorization/security behavior.
  - Entity/repository/schema/migration.
  - CI/CD, release, rollback quy trình liên quan moderation.
- Áp dụng cho cả pull request thường, merge queue và release branch vào main.

## Định nghĩa hoàn tất (Definition of Done)

Một thay đổi được coi là hoàn tất khi thỏa đồng thời các nhóm tiêu chí sau.

### 1) Functional DoD

- Luồng nghiệp vụ bị ảnh hưởng phải hoạt động đúng theo tài liệu workflow hiện hành.
- Không làm giảm coverage của các luồng lõi: report, case, action, appeal, admin moderation user.
- Không phá vỡ tính toàn vẹn side effects: tạo case/evidence/audit tương ứng khi mutate dữ liệu.

### 2) Security DoD

- Boundary USER/MODERATOR/ADMIN phải giữ nguyên hoặc được cập nhật tài liệu và test rõ ràng.
- Guard moderation_admin_user (vai trò + is_active) phải được enforce nhất quán cho endpoint đặc quyền.
- Contract 401/403 không thay đổi ngoài phạm vi đã được review và chấp thuận.

### 3) Contract DoD

- ApiResponse success/error phải giữ cấu trúc ổn định.
- Error code quan trọng (ERR*400/401/403/404/405/500 và MOD*\*) không bị drift ngoài kế hoạch.
- Nếu có thay đổi contract, bắt buộc cập nhật catalog API + test + artifact Postman.

### 4) Data/Migration DoD

- Mọi thay đổi model/entity/repository đi kèm migration tương ứng khi cần.
- Migration phải pass migration guard workflow.
- Tài liệu migration/release/rollback phải phản ánh đúng rủi ro dữ liệu.

### 5) Documentation DoD

- Bộ tài liệu core moderation liên quan phải được đồng bộ.
- Checklist backend DoD và changelog phải phản ánh đúng phạm vi thay đổi trước khi release.

## Cổng bắt buộc

### Cổng kỹ thuật trước merge

1. Test gate pass
   - Workflow: `.github/workflows/moderation-test-ci.yml`
   - Job bắt buộc: `moderation-tests-required`
2. Migration governance pass khi có thay đổi model/repository
   - Workflow: `.github/workflows/moderation-migration-required.yml`
3. Production runtime guard pass cho thay đổi ảnh hưởng runtime/deploy
   - Workflow: `.github/workflows/moderation-production-guard.yml`
4. Không có lỗi blocker trong test suite moderation (unit/integration/regression).
5. Tài liệu liên quan được cập nhật đồng bộ (03/04/05/06/07/08/09/10 khi có tác động).

### Cổng phát hành trước production

1. Toàn bộ gate kỹ thuật đã xanh trên commit/release candidate cuối cùng.
2. Smoke flow moderation cốt lõi pass.
3. Đủ bằng chứng rollback/mitigation tương ứng với phạm vi thay đổi.
4. Go/no-go được ký nhận bởi owner bắt buộc.

## Bằng chứng phát hành bắt buộc

1. Snapshot CI pass mới nhất:
   - moderation-tests-required
   - migration guard (nếu áp dụng)
   - production guard
2. Bằng chứng health moderation sau deploy thử nghiệm.
3. Bằng chứng smoke (ví dụ: `scripts/moderation-e2e-15.ps1` hoặc bộ tương đương).
4. Trạng thái checklist DoD moderation backend không còn blocker.
5. Ghi nhận thay đổi nghiệp vụ trong `docs/project/changelog.md` nếu hành vi thay đổi.
6. Nếu có migration:
   - danh sách migration mới;
   - đánh giá tương thích ngược;
   - phương án rollback/mitigation dữ liệu.

## Tiêu chí Go/No-Go

### GO

- Tất cả cổng bắt buộc đạt.
- Không còn blocker mở ở DoD checklist.
- Bằng chứng phát hành đầy đủ và có người chịu trách nhiệm xác nhận.

### CONDITIONAL GO

- Cổng bắt buộc đạt, nhưng có rủi ro đã biết chưa loại bỏ hoàn toàn.
- Có risk acceptance bằng văn bản kèm owner và thời hạn khắc phục.

### NO-GO

- Bất kỳ cổng bắt buộc nào fail.
- Thiếu bằng chứng bắt buộc cho release.
- Phát hiện rủi ro dữ liệu/rollback chưa có phương án chấp nhận được.

## Quy tắc sở hữu

1. Owner backend:
   - xác nhận triển khai, test pass, migration/release notes đầy đủ.
2. Owner QA:
   - xác nhận độ đầy đủ kịch bản tự động/thủ công và kết quả smoke.
3. Owner DevOps:
   - xác nhận readiness deploy, health, rollback playbook khả thi.
4. Reviewer kỹ thuật:
   - xác nhận đồng bộ tài liệu và tuân thủ quality gate.

## Quy tắc ngoại lệ

- Không bypass required checks cho release production trừ khi có phê duyệt khẩn cấp theo quy trình sự cố.
- Mọi ngoại lệ phải có:
  - lý do rõ ràng;
  - phạm vi ảnh hưởng;
  - người phê duyệt;
  - kế hoạch hậu kiểm.

## Truy vết và kiểm toán

- Mỗi release moderation cần truy vết được:
  - commit/release id;
  - workflow runs liên quan;
  - kết quả smoke;
  - quyết định go/no-go;
  - nếu có rollback: postmortem + corrective actions.

## Chu kỳ review định kỳ

- Review tài liệu quality gates tối thiểu mỗi quý.
- Review sớm ngay khi có thay đổi lớn ở:
  - security model,
  - migration policy,
  - test gate/CI pipeline,
  - release/rollback strategy.

## Hướng cải tiến

1. Bổ sung ngưỡng phi chức năng rõ hơn theo endpoint (latency/error budget).
2. Chuẩn hóa bài diễn tập rollback định kỳ cho môi trường gần production.
3. Tự động hóa kiểm tra drift giữa tài liệu và workflow/endpoint thực tế.

## Tài liệu liên quan

- ../../checklists/moderation-backend-dod.md
- 03-api-spec-and-catalog.md
- 07-testing-strategy-and-quality.md
- 08-operations-runbook-and-observability.md
- 09-cicd-release-and-rollback.md
