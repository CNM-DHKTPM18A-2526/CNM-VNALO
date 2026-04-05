# Chiến Lược Kiểm Thử Và Chất Lượng Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team + QA Team
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Chiến lược kiểm thử tự động/thủ công, cổng chất lượng CI và bằng chứng release của moderation-service

## Mục tiêu

Chuẩn hóa cách bảo đảm chất lượng moderation-service theo mô hình có thể kiểm chứng: lớp test, phạm vi coverage, quality gate, bằng chứng CI và tiêu chí go/no-go trước khi release.

## Nguyên tắc chất lượng

1. Security-first:
   mọi endpoint đặc quyền phải được kiểm chứng boundary USER/MODERATOR/ADMIN và trạng thái is_active.
2. Contract stability:
   mã lỗi 400/401/403/404/405/500 và cấu trúc ApiResponse phải ổn định qua regression tests.
3. Workflow integrity:
   luồng report -> case -> action -> appeal -> admin management cần có test coverage tối thiểu ở mức integration/functional.
4. Regression prevention:
   lỗi đã từng gặp (null principal, SQL drift, JSONB persistence) phải có regression guard cố định.

## Mô hình kiểm thử

### 1) Unit tests

- Mục tiêu: xác minh business logic service-level và hành vi xử lý dữ liệu cục bộ.
- Điển hình:
  - ReportService duplicate guard + create flow logic.
  - AppealService create/resolve + audit JSON payload.
  - SharedUserQueryService behavior.

### 2) Integration tests

- Mục tiêu: kiểm chứng controller contract, security boundary, persistence behavior trên ngữ cảnh Spring Boot thực.
- Điển hình:
  - SecurityAndErrorContractIntegrationTest.
  - ReportServiceIntegrationTest.
  - FunctionalCoverageIntegrationTest.

### 3) Regression tests

- Mục tiêu: cố định các bug đã xảy ra để tránh tái phát.
- Điển hình:
  - ControllerAuthenticationRegressionTest.
  - RegressionGuardIntegrationTest (NPE, SQL join safety, JSONB).

## Inventory test suite hiện hành

| Test class                              | Loại                   | Trọng tâm                                       | Số test hiện có |
| --------------------------------------- | ---------------------- | ----------------------------------------------- | --------------- |
| ReportServiceTest                       | Unit                   | duplicate guard + report create logic           | 2               |
| AppealServiceTest                       | Unit                   | create/resolve appeal + audit logging           | 2               |
| SharedUserQueryServiceTest              | Unit                   | query user dữ liệu tham chiếu                   | 2               |
| ReportServiceIntegrationTest            | Integration            | create report với DB context                    | 1               |
| SecurityAndErrorContractIntegrationTest | Integration            | authz + error contracts 400/401/403/404/405/500 | 13              |
| FunctionalCoverageIntegrationTest       | Integration/Functional | 9 luồng nghiệp vụ chính moderation              | 9               |
| ControllerAuthenticationRegressionTest  | Regression             | xử lý principal/authentication ở controller     | 2               |
| RegressionGuardIntegrationTest          | Regression             | NPE + SQL drift + JSONB persistence             | 7               |
| ModerationServiceApplicationTests       | Smoke                  | context load                                    | 1               |

Ghi chú tổng quan:

- Tổng số test hiện tại: 39.
- Tập test chạy qua Maven command: mvn test.

## Kiểm thử thủ công

- Postman collections:
  - docs/system/postman/moderation-e2e.postman_collection.json
  - docs/system/postman/moderation-local.postman_environment.json
- Script smoke local:
  - scripts/moderation-e2e-15.ps1 (15 request theo expected status hiện tại).
- Kịch bản bắt buộc:
  - health check trước/sau run.
  - auth bootstrap và seed role khi cần.
  - kiểm chứng cả happy path và access-denied path cho endpoint đặc quyền.

## Cổng chất lượng bắt buộc (hiện tại)

- CI test bắt buộc pass:
  - Workflow: .github/workflows/moderation-test-ci.yml
  - Required job name: moderation-tests-required
- Migration governance pass:
  - Workflow: .github/workflows/moderation-migration-required.yml
  - Rule: thay đổi model/entity/repository phải có migration mới.
- Production health guard pass:
  - Workflow: .github/workflows/moderation-production-guard.yml
  - Rule: service phải đạt healthy trên profile prod trong docker compose.
- Error contract ổn định theo nhóm mã 400/401/403/404/405/500.
- Boundary authorization USER/MODERATOR/ADMIN + moderation_admin_user.is_active phải được verify.

## Quy trình chạy kiểm thử

### Local developer flow

1. Chạy unit + integration:
   - ./mvnw -B test
2. Chạy smoke script thủ công khi cần xác minh luồng end-to-end:
   - scripts/moderation-e2e-15.ps1
3. Kiểm tra health:
   - GET /api/v1/actuator/health

### CI flow

1. PR thay đổi moderation-service sẽ kích hoạt moderation-test-ci.
2. Nếu thay đổi model/entity/repository, migration guard sẽ enforce migration file mới.
3. Khi thay đổi pipeline/compose/service runtime, production guard sẽ xác nhận readiness cơ bản.

## Ưu tiên coverage

- Phân quyền endpoint đặc quyền.
- Side effect của gán/giải quyết case.
- Độ đúng của xử lý appeal.
- Việc tạo audit log ở các thao tác đổi trạng thái.

## Ma trận rủi ro và kiểm thử tương ứng

| Rủi ro                                             | Cách kiểm thử hiện tại                                                      | Tình trạng  |
| -------------------------------------------------- | --------------------------------------------------------------------------- | ----------- |
| Truy cập trái phép endpoint moderation/admin       | SecurityAndErrorContractIntegrationTest + FunctionalCoverageIntegrationTest | Có          |
| Principal null gây NPE ở controller                | ControllerAuthenticationRegressionTest + RegressionGuardIntegrationTest     | Có          |
| Sai lệch schema/truy vấn SQL                       | RegressionGuardIntegrationTest                                              | Có          |
| Lỗi JSONB audit persistence                        | RegressionGuardIntegrationTest                                              | Có          |
| Trôi contract lỗi HTTP                             | SecurityAndErrorContractIntegrationTest                                     | Có          |
| Rule chuyển trạng thái bị cấm chưa enforced đầy đủ | Một phần trong functional tests, chưa có matrix âm đầy đủ                   | Cần bổ sung |

## Bằng chứng release tối thiểu

- Kết quả CI moderation-tests-required pass mới nhất.
- Kết quả migration guard pass (nếu có thay đổi schema/domain model).
- Kết quả production health guard pass hoặc bằng chứng health tương đương.
- Kết quả smoke script moderation-e2e-15.ps1 PASS tại môi trường local staging.
- Checklist DoD moderation được cập nhật đầy đủ.

## Tiêu chí hoàn tất chất lượng trước merge/release

- Không có test fail trong moderation test suite.
- Không có regression test bị skip không lý do.
- Không phá vỡ error contract đã công bố.
- Không bypass migration rule khi thay đổi model/entity/repository.
- Tài liệu API/testing đồng bộ với hành vi endpoint hiện tại.

## Hướng cải tiến

- Bật branch protection/ruleset enforce bắt buộc required check moderation-tests-required.
- Bổ sung matrix âm đầy đủ cho status transition không hợp lệ (case/appeal/report).
- Bổ sung integration tests cho hành vi lỗi domain chưa chuẩn hóa (ví dụ appeal not found).
- Bổ sung báo cáo coverage theo package để theo dõi drift test depth.

## Tài liệu liên quan

- 06-business-workflows-and-states.md
- 10-definition-of-done-and-quality-gates.md
- 03-api-spec-and-catalog.md
- ../../checklists/moderation-backend-dod.md
- ../../moderation-service-analysis.md
