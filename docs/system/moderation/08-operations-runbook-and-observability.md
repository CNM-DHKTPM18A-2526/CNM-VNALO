# Runbook Vận Hành Và Quan Sát Hệ Thống Của Moderation

## Thông tin tài liệu

- Phụ trách: Backend Team + DevOps
- Trạng thái: Sẵn sàng
- Cập nhật lần cuối: 2026-03-25
- Phạm vi: Vận hành runtime, quan sát hệ thống, xử lý sự cố và phục hồi dịch vụ moderation-service

## Mục tiêu

Cung cấp runbook thực thi được cho đội Backend/DevOps trong toàn bộ vòng đời vận hành moderation-service: khởi động, kiểm tra sẵn sàng, theo dõi tín hiệu, ứng phó sự cố và khôi phục sau sự cố.

## Bối cảnh vận hành

- Service: moderation-service
- Port mặc định: 8082
- Context path: /api/v1
- Health endpoint:
  - /api/v1/actuator/health
  - /actuator/health (tùy cấu hình route/proxy)
- Runtime profile chính:
  - dev: flyway baseline-on-migrate=true, baseline-version=2
  - prod: flyway baseline-on-migrate=false
- Phụ thuộc hạ tầng chính:
  - PostgreSQL
  - Redis
  - JWT_SECRET bắt buộc ở mọi profile

## Quy trình khởi động dịch vụ

### Phương án A: Chạy full stack bằng Docker Compose

1. Đảm bảo biến môi trường JWT_SECRET đã được set.
2. Chạy stack:

```powershell
docker compose -f docker/docker-compose.yml up -d --build postgres redis moderation-service
```

3. Chờ container healthy:

```powershell
docker compose -f docker/docker-compose.yml ps moderation-service
```

4. Kiểm tra health endpoint:

```powershell
Invoke-WebRequest -Method GET -Uri http://localhost:8082/api/v1/actuator/health
```

### Phương án B: Chạy local service + infra Docker

1. Khởi động infra:

```powershell
docker compose -f docker/docker-compose.infra.yml up -d
```

2. Chạy moderation-service local:

```powershell
cd backend/java-services/services/moderation-service
./mvnw spring-boot:run
```

3. Health check như phương án A.

## Checklist sẵn sàng vận hành (pre-flight)

- PostgreSQL và Redis đang healthy.
- JWT_SECRET có giá trị hợp lệ.
- moderation-service trả về health 200.
- Flyway migration chạy thành công (không lỗi schema validation).
- Không có lỗi startup nghiêm trọng trong log (bean creation, datasource, flyway, security config).

## Quan sát hệ thống (observability)

### Tín hiệu bắt buộc theo dõi

- Availability:
  - Health endpoint thành công ổn định.
- Reliability:
  - Tỷ lệ 5xx theo endpoint.
  - Tỷ lệ 4xx bất thường (đặc biệt 401/403 tăng đột biến).
- Business flow health:
  - Throughput report creation.
  - Throughput case/action/appeal operations.
  - Backlog appeal pending.
- Data health:
  - Lỗi DB connection pool.
  - Lỗi Flyway/migration validation.

## Mốc chuẩn theo dõi

- Health endpoint.
- Tỷ lệ lỗi theo endpoint (xu hướng 4xx/5xx).
- Throughput của moderation action.
- Backlog appeal và độ trễ xử lý.

## Log cần quan sát

- Security/authn/authz logs:
  - Unauthorized/Access denied tăng bất thường.
  - Token parsing/validation failures.
- Startup logs:
  - datasource init,
  - flyway migrate/validate,
  - security filter chain init.
- Domain mutation logs:
  - CASE_ASSIGNED,
  - CASE_RESOLVED,
  - ACTION_CREATED,
  - APPEAL_CREATED,
  - APPEAL_RESOLVED.
- Error logs:
  - stacktrace lỗi 500,
  - sql/constraint violations,
  - jsonb persistence issues.

## Mốc chuẩn log

- Từ chối bảo mật kèm ngữ cảnh principal (không rò rỉ thông tin nhạy cảm).
- Chuyển trạng thái của case/action/appeal.
- Log chẩn đoán migration và startup.

## Smoke check sau deploy hoặc sau rollback

1. Health moderation endpoint.
2. Report create + my reports.
3. Ít nhất một endpoint moderation đặc quyền với token hợp lệ.
4. Appeal flow cơ bản.
5. So sánh tỷ lệ lỗi 5xx trước/sau deploy.

Khuyến nghị dùng script:

- scripts/moderation-e2e-15.ps1

## Ma trận mức độ sự cố

| Mức độ | Điều kiện điển hình                                         | Kỳ vọng phản ứng                                             |
| ------ | ----------------------------------------------------------- | ------------------------------------------------------------ |
| SEV-1  | Health down diện rộng, 5xx tăng mạnh, luồng moderation dừng | Cô lập nhanh, ưu tiên rollback, cập nhật trạng thái liên tục |
| SEV-2  | Một nhóm endpoint chính lỗi liên tục, latency tăng cao      | Khoanh vùng component, áp dụng mitigation tạm thời           |
| SEV-3  | Lỗi cục bộ có workaround, không ảnh hưởng diện rộng         | Theo dõi và xử lý trong giờ làm việc                         |

## Playbook sự cố chi tiết

### Incident A: Health endpoint fail hoặc container unhealthy

1. Xác nhận tình trạng container/service.
2. Kiểm tra log moderation-service 200 dòng gần nhất.
3. Xác minh kết nối DB/Redis.
4. Nếu do config/runtime mới, rollback về bản ổn định gần nhất.
5. Chạy lại smoke check.

### Incident B: 401/403 tăng bất thường

1. Kiểm tra JWT_SECRET/JWT_ISSUER có thay đổi không đồng bộ.
2. Kiểm tra dữ liệu moderation_admin_user (role/is_active) cho nhóm user bị ảnh hưởng.
3. Kiểm tra deploy gần nhất có thay đổi security config/guard logic.
4. Mitigation:
   - khôi phục config chuẩn,
   - seed/correct moderation_admin_user nếu cần.

### Incident C: 5xx tăng ở luồng report/case/action/appeal

1. Xác định endpoint/domain lỗi nhiều nhất.
2. Đối chiếu log exception (validation, DB constraint, null handling).
3. Kiểm tra migration gần nhất và khả năng schema drift.
4. Nếu cần rollback ứng dụng, thực hiện theo runbook release/rollback.
5. Sau rollback, xác nhận lại smoke + health.

### Incident D: Migration lỗi khi startup

1. Đọc log Flyway để xác định migration gây lỗi.
2. Dừng rollout lan rộng.
3. Kiểm tra checklist migration review và note rollback/mitigation.
4. Chọn phương án:
   - sửa migration và redeploy,
   - hoặc rollback app/schema theo kế hoạch đã duyệt.

## Quy trình rollback vận hành

1. Xác định phiên bản lỗi theo commit/tag/deploy window.
2. Rollback artifact moderation-service về bản ổn định.
3. Nếu có thay đổi schema:
   - áp dụng đúng kế hoạch rollback/mitigation đã chuẩn bị.
4. Chạy lại health + smoke checks.
5. Theo dõi thêm ít nhất một chu kỳ ngắn sau phục hồi.

## Truy vấn/command tham khảo nhanh

```powershell
# Xem trạng thái container moderation
docker compose -f docker/docker-compose.yml ps moderation-service

# Xem logs moderation (tail)
docker compose -f docker/docker-compose.yml logs --tail 200 moderation-service

# Health check moderation
Invoke-WebRequest -Method GET -Uri http://localhost:8082/api/v1/actuator/health

# Chạy smoke script moderation
powershell -File scripts/moderation-e2e-15.ps1
```

## Hậu kiểm sự cố (post-incident)

- Ghi nhận timeline sự cố và phạm vi ảnh hưởng.
- Xác định root cause kỹ thuật và yếu tố quy trình.
- Liệt kê hành động phòng ngừa: test, monitor, alert, runbook update.
- Cập nhật changelog/status và tài liệu liên quan nếu có thay đổi hành vi hệ thống.

## Playbook sự cố (mức tối thiểu)

1. Phát hiện qua health hoặc mức 5xx tăng cao.
2. Cô lập endpoint/domain flow bị ảnh hưởng.
3. Kiểm tra thay đổi migration/config gần nhất.
4. Roll back về phiên bản ổn định trước đó nếu cần.
5. Ghi lại sự cố và hành động phòng ngừa.

## Hướng cải tiến

- Bổ sung định nghĩa dashboard và ngưỡng cảnh báo.
- Bổ sung ma trận phản ứng on-call theo mức độ sự cố.
- Bổ sung runbook cho sự cố khóa quyền role-authorization.
- Bổ sung cảnh báo tự động theo ngưỡng 5xx và auth-denied spike.
- Bổ sung canary checks cho moderation-service trước khi rollout rộng.

## Tài liệu liên quan

- 09-cicd-release-and-rollback.md
- 07-testing-strategy-and-quality.md
- ../../checklists/moderation-backend-dod.md
- ../../project/status.md
- ../../../docker/docker-compose.yml
