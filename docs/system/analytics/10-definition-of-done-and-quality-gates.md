# Analytics Definition Of Done And Quality Gates

## 1. Functional Done Criteria

1. FR-01..FR-06 dat theo requirements baseline.
2. API catalog va test guide khop implementation hien tai.
3. Backfill reliability co tracking + retry/resume.
4. Wave 2 hardening (retention, cache, SLI/SLO) da complete.

## 2. Test Quality Gates

1. Unit + integration tests pass local.
2. CI analytics tests pass.
3. Security contract scenarios pass (401/403/400).
4. API smoke script pass tren local stack.

## 3. Documentation Gates

1. `docs/project/status.md` cap nhat dung so lieu test/tinh trang.
2. `docs/project/changelog.md` ghi ro thay doi + verification.
3. Wave evidence docs du bang chung release.

## 4. Operational Gates

1. Health endpoint on dinh.
2. SLI metrics co the truy cap qua actuator.
3. Alerting/SLO baseline da duoc tai lieu hoa.

## 5. Remaining External Gates

1. Branch protection required checks can bat tren GitHub.
2. CI evidence run URL can duoc ghi nhan trong release evidence.

## 6. Checklists Of Record

1. `docs/system/analytics/analytics-backend-dod.md`
2. `docs/system/analytics/analytics-go-no-go-checklist.md`
3. `docs/system/analytics/analytics-migration-review.md`
