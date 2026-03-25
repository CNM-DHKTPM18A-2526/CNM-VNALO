# CI/CD, Phát Hành Và Rollback Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team + DevOps
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Pipeline triển khai, cổng merge, quy trình phát hành và rollback

## Mục tiêu

Định nghĩa cơ chế kiểm soát thay đổi moderation-service từ pull request đến phát hành production, bao gồm:

1. Các cổng kiểm tra bắt buộc trước merge.
2. Checklist phát hành theo bằng chứng kỹ thuật có thể audit.
3. Quy trình rollback theo mức độ ảnh hưởng ứng dụng và dữ liệu.

Tài liệu này chuẩn hóa theo các workflow CI hiện có trong repository và đồng bộ với quality gates ở tài liệu 10.

## Kiến trúc pipeline hiện tại

### 1) Test gate bắt buộc

- Workflow: `.github/workflows/moderation-test-ci.yml`
- Job bắt buộc: `moderation-tests-required`
- Trigger:
  - `pull_request` với thay đổi trong moderation-service.
  - `merge_group` để bảo vệ merge queue.
  - `push` vào `main` cho thay đổi moderation-service.
- Thực thi chính:
  - Java 21 (Temurin), Maven cache.
  - Chạy full test suite: `./mvnw -B test` tại moderation-service.

### 2) Migration governance gate

- Workflow: `.github/workflows/moderation-migration-required.yml`
- Mục tiêu: ép kỷ luật migration khi thay đổi `entity/repository`.
- Cơ chế:
  - Nếu phát hiện thay đổi Java model/repository nhưng không có file Flyway migration mới dạng `V<version>__*.sql` được thêm vào, workflow fail.
- Ý nghĩa vận hành:
  - Giảm rủi ro drift giữa code và schema khi merge.

### 3) Production runtime guard

- Workflow: `.github/workflows/moderation-production-guard.yml`
- Mục tiêu: xác nhận service có thể khởi động profile production trong môi trường compose tối thiểu.
- Cơ chế:
  - Build + up stack `postgres`, `redis`, `moderation-service`.
  - Chờ health tới 36 lần, mỗi lần 5 giây.
  - Nếu không healthy: in log service và fail.
  - Luôn dọn môi trường (`down -v`) sau kiểm tra.

## Yêu cầu cổng merge

1. `moderation-tests-required` phải pass.
2. Migration guard phải pass khi có thay đổi model/repository.
3. Không merge khi production guard fail health check.
4. Các thay đổi API/security/data model phải đồng bộ tài liệu liên quan (03/04/05/06/07/08/10).
5. Checklist DoD moderation backend không còn mục mở mức blocker.

## Bằng chứng bắt buộc trước phát hành

Trước khi phát hành production, release owner cần tập hợp tối thiểu các bằng chứng sau:

1. Kết quả CI pass cho:
   - moderation tests required
   - migration guard (nếu áp dụng)
   - production guard
2. Bằng chứng migration review:
   - Danh sách migration mới.
   - Đánh giá backward compatibility và phương án rollback/mitigation dữ liệu.
3. Bằng chứng smoke:
   - Kết quả chạy script `scripts/moderation-e2e-15.ps1` hoặc bộ smoke tương đương.
4. Cập nhật thay đổi nghiệp vụ:
   - Mục tương ứng trong `docs/project/changelog.md` cho scope moderation (nếu có thay đổi hành vi).
5. Xác nhận vận hành:
   - Health endpoint đạt trạng thái ổn định sau deploy.

## Quy trình phát hành chuẩn

1. Chốt release scope
   - Khóa danh sách PR/commit thuộc release.
   - Xác định có hay không thay đổi schema.
2. Xác nhận chất lượng
   - Đảm bảo toàn bộ gate bắt buộc đã pass.
   - Kiểm tra checklist DoD moderation.
3. Chuẩn bị migration
   - Review thứ tự migration và tính an toàn dữ liệu.
   - Xác nhận backup/restore point theo quy trình môi trường.
4. Thực thi deploy
   - Deploy artifact moderation-service theo chuẩn môi trường.
   - Quan sát health, startup log, và lỗi kết nối phụ thuộc (DB/Redis/JWT).
5. Hậu kiểm sau deploy
   - Chạy smoke flow trọng yếu: report -> assign -> resolve -> appeal.
   - Ghi nhận kết quả và người xác nhận.

## Chiến lược rollback

### Phân loại tình huống

1. Lỗi ứng dụng không liên quan schema
   - Rollback nhanh về artifact/version trước đó.
2. Lỗi liên quan schema đã migrate
   - Ưu tiên forward-fix nếu rollback migration có rủi ro dữ liệu.
   - Chỉ rollback schema khi đã có script và được phê duyệt kỹ thuật.
3. Lỗi tích hợp hạ tầng tạm thời
   - Khôi phục cấu hình/secret hoặc dependency trước khi rollback artifact.

### Playbook rollback

1. Kích hoạt incident và chỉ định incident owner.
2. Đóng băng deploy mới cho moderation-service.
3. Xác định commit/release gây lỗi và phạm vi ảnh hưởng.
4. Quyết định chiến lược:
   - rollback artifact;
   - forward-fix nóng;
   - rollback/mitigation dữ liệu.
5. Thực thi phương án đã chọn và xác minh:
   - service healthy;
   - smoke test pass;
   - không phát sinh lỗi 5xx bất thường sau phục hồi.
6. Cập nhật changelog và biên bản sự cố.

## Ma trận quyết định rollback nhanh

| Tình huống                                   | Dấu hiệu                                          | Hành động ưu tiên                                         | Yêu cầu phê duyệt                |
| -------------------------------------------- | ------------------------------------------------- | --------------------------------------------------------- | -------------------------------- |
| Crash/health fail sau deploy                 | Container không healthy, startup error            | Rollback artifact ngay                                    | Incident owner + on-call backend |
| Sai logic nghiệp vụ nhưng schema tương thích | Endpoint trả kết quả sai, không mất dữ liệu       | Rollback artifact hoặc hotfix nhanh                       | Backend lead                     |
| Migration gây lỗi dữ liệu                    | Lỗi SQL/runtime sau migration, data inconsistency | Forward-fix có kiểm soát; rollback schema chỉ khi an toàn | Backend lead + DBA/DevOps        |
| Sự cố phụ thuộc DB/Redis/secret              | Timeout kết nối, auth fail hạ tầng                | Khôi phục dependency/config trước                         | DevOps on-call                   |

## Kiểm toán và truy vết phát hành

- Mỗi release cần có tối thiểu:
  - mã release hoặc commit hash;
  - danh sách workflow run liên quan;
  - kết quả smoke;
  - quyết định go/no-go và người phê duyệt.
- Nếu có incident/rollback, phải ghi liên kết postmortem và corrective actions.

## Hướng cải tiến

1. Bổ sung release template dạng checklist có trường sign-off chuẩn cho Backend/QA/DevOps.
2. Bổ sung automation tạo release notes moderation từ PR labels.
3. Nghiên cứu chiến lược canary/blue-green cho moderation-service khi lưu lượng tăng.
4. Chuẩn hóa dashboard lỗi 4xx/5xx theo endpoint moderation để rút ngắn MTTR.

## Tài liệu liên quan

- ../../checklists/moderation-backend-dod.md
- ../../project/changelog.md
- ./10-definition-of-done-and-quality-gates.md
