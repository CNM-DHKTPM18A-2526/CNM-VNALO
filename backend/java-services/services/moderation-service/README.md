# Moderation Service

Moderation Service la backend xu ly kiem duyet noi dung cho he thong VNALO.

Tai lieu nay la README portal chi tiet cho dev, QA, DevOps va reviewer khi can:

1. Hieu dung pham vi service.
2. Chay local nhanh va test dung.
3. Truy cap dung bo tai lieu moderation core.
4. Release an toan theo quality gates.

## 1) Service Overview

### Muc tieu nghiep vu

Moderation Service giai quyet tron vong doi moderation:

1. User tao report vi pham.
2. Moderator triage report va xu ly case.
3. He thong tao moderation action va audit trail.
4. User tao appeal, moderator/admin resolve appeal.
5. Admin quan tri role MODERATOR/ADMIN bang endpoint rieng.

### Capability chinh

- Report intake va duplicate protection theo cua so 24h.
- Case assignment va case resolution.
- Moderation action creation.
- Appeal lifecycle management.
- Runtime authorization guard bang moderation_admin_user.
- Audit log cho cac hanh dong quan trong.

## 2) Tech Stack va Runtime

### Cong nghe chinh

- Java 21
- Spring Boot 3.x
- Spring Security
- Spring Data JPA
- Flyway
- PostgreSQL
- Redis (phu thuoc runtime)

### Runtime defaults

- Port: 8082
- Context path: /api/v1
- Health endpoint:
  - /api/v1/actuator/health
  - /actuator/health

## 3) Cac profile cau hinh

### dev (mac dinh)

- ddl-auto = validate
- Flyway table = flyway_schema_history_moderation
- baseline-on-migrate = true
- baseline-version = 2

### prod

- ddl-auto = validate
- Flyway table = flyway_schema_history_moderation
- baseline-on-migrate = false

## 4) Environment Variables quan trong

Bien quan trong nhat:

- JWT_SECRET (bat buoc)
- JWT_ISSUER (khuyen nghi set ro)

Bien ket noi DB:

- DB_HOST
- DB_PORT
- DB_NAME
- DB_USER
- DB_PASS

Bien khac:

- SERVER_PORT
- SPRING_PROFILES_ACTIVE
- REDIS_HOST
- REDIS_PORT
- KAFKA_SERVERS

Neu thieu JWT_SECRET, service co the khong khoi dong dung security context.

## 5) Quick Start cho Developer

### Prerequisites

- Java 21
- Docker + Docker Compose
- Maven Wrapper (da co trong repo)

### Cach 1: Chay service truc tiep

1. Di chuyen vao folder service:

```bash
cd backend/java-services/services/moderation-service
```

2. Chay service:

```bash
./mvnw spring-boot:run
```

3. Health check:

```bash
curl http://localhost:8082/api/v1/actuator/health
```

### Cach 2: Chay bang docker compose

```bash
docker compose -f docker/docker-compose.yml up -d --build postgres redis moderation-service
```

Kiem tra:

```bash
docker compose -f docker/docker-compose.yml ps moderation-service
```

## 6) Security Model tom tat

### Authentication

- Tat ca endpoint nghiep vu dung Bearer JWT.
- Health va swagger co the cho phep public theo config.

### Authorization hai lop

1. Lop endpoint policy trong SecurityFilterChain.
2. Lop runtime guard bang moderation_admin_user:
   - requireModerator: MODERATOR hoac ADMIN, is_active = true
   - requireAdmin: chi ADMIN, is_active = true

### He qua quan trong

- Co role trong JWT la dieu kien can.
- Co record moderation_admin_user active la dieu kien du cho endpoint dac quyen.

## 7) API Groups (high-level)

### User report APIs

- POST /reports
- GET /reports/me

### Moderation APIs

- GET /api/v1/moderation/reports
- GET /api/v1/moderation/reports/{reportId}
- POST /api/v1/moderation/reports/{reportId}/assign
- POST /api/v1/moderation/cases/{caseId}/resolve
- POST /api/v1/moderation/actions
- POST /api/v1/moderation/cases/{caseId}/appeal
- GET /api/v1/moderation/appeals
- POST /api/v1/moderation/appeals/{appealId}/resolve

### Admin APIs

- POST /api/v1/admin/users

Contract day du va payload chi tiet xem tai:

- ../../../../docs/system/moderation/03-api-spec-and-catalog.md

## 8) Data model tom tat

Bang domain chinh:

- moderation_report
- moderation_report_evidence
- moderation_case
- moderation_action
- moderation_appeal
- moderation_admin_user
- moderation_audit_log

Migration hien tai:

- V1\_\_init_moderation_schema.sql
- V2\_\_add_appeal_table.sql

Tham chieu day du:

- ../../../../docs/system/moderation/05-data-model-and-schema.md

## 9) Testing Strategy

### Chay test local

```bash
./mvnw -B test
```

### Nhom test quan trong

- Security and error contract integration tests.
- Functional coverage integration tests.
- Regression guard tests (principal null, SQL drift, JSONB).
- Service-level unit tests.

### E2E smoke script

- ../../../../scripts/moderation-e2e-15.ps1

Tham chieu quality strategy:

- ../../../../docs/system/moderation/07-testing-strategy-and-quality.md

## 10) CI/CD va Release Gates

Workflow moderation:

- ../../../../.github/workflows/moderation-test-ci.yml
- ../../../../.github/workflows/moderation-migration-required.yml
- ../../../../.github/workflows/moderation-production-guard.yml

Gate merge/release can dam bao:

1. moderation-tests-required pass.
2. Migration guard pass khi co thay doi model/repository.
3. Production guard pass health runtime.

Tham chieu quy trinh release/rollback:

- ../../../../docs/system/moderation/09-cicd-release-and-rollback.md
- ../../../../docs/system/moderation/10-definition-of-done-and-quality-gates.md

## 11) Documentation Portal moderation

Bo 10 tai lieu core:

1. ../../../../docs/system/moderation/01-service-overview.md
2. ../../../../docs/system/moderation/02-architecture-overview.md
3. ../../../../docs/system/moderation/03-api-spec-and-catalog.md
4. ../../../../docs/system/moderation/04-authn-authz-role-matrix.md
5. ../../../../docs/system/moderation/05-data-model-and-schema.md
6. ../../../../docs/system/moderation/06-business-workflows-and-states.md
7. ../../../../docs/system/moderation/07-testing-strategy-and-quality.md
8. ../../../../docs/system/moderation/08-operations-runbook-and-observability.md
9. ../../../../docs/system/moderation/09-cicd-release-and-rollback.md
10. ../../../../docs/system/moderation/10-definition-of-done-and-quality-gates.md

## 12) Operational Checklist nhanh

Truoc khi push merge:

1. mvn test xanh.
2. Khong vo error contract 400/401/403/404/405/500.
3. Neu doi entity/repository, da co migration hop le.
4. Docs lien quan da cap nhat dong bo.

Truoc khi release:

1. CI moderation gates xanh.
2. Smoke script moderation pass.
3. Health service on dinh sau deploy.
4. Co rollback/mitigation plan neu co doi schema.

## 13) Troubleshooting nhanh

### 401 Unauthorized

- Kiem tra Authorization header Bearer token.
- Kiem tra token het han/sai secret/issuer.

### 403 Forbidden

- Kiem tra user co record trong moderation_admin_user chua.
- Kiem tra role va is_active = true.
- Kiem tra endpoint co yeu cau ADMIN-only khong.

### Service startup fail

- Kiem tra JWT_SECRET da set chua.
- Kiem tra DB connection vars.
- Kiem tra Flyway migration/log startup.

### Health fail trong compose

- Xem log moderation-service:

```bash
docker compose -f docker/docker-compose.yml logs --tail 200 moderation-service
```

## 14) Known Limitations

- Appeal flow hien tai chua co escalation tiers.
- Chua co risk scoring/ML moderation.
- Chua co realtime moderator notification pipeline day du.

## 15) Ownership

- Backend owner: Moderation backend team.
- QA owner: Moderation test/contract owner.
- DevOps owner: Pipeline, runtime guard, release safety.
