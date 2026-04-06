# Analytics CI CD Release And Rollback

## 1. CI Workflows

1. Analytics test CI:
   - `.github/workflows/analytics-test-ci.yml`
2. Analytics production guard:
   - `.github/workflows/analytics-production-guard.yml`

## 2. Required Release Checks

1. Local test pass:
   - `./mvnw -B test`
2. CI pass cho analytics workflows.
3. Health check pass trong prod profile/container context.
4. Docs/checklist duoc cap nhat day du.

## 3. Branch Protection Recommendation

1. Bat required status check `analytics-tests-required` tren main.
2. Khong merge neu test/check bat buoc fail.

## 4. Release Procedure (Suggested)

1. Rebase branch va chay test local.
2. Tao PR, doi analytics CI xanh.
3. Verify changelog/status/wave evidence docs.
4. Merge khi required checks pass.

## 5. Rollback Strategy

1. Neu issue o runtime logic:
   - rollback commit/release artifact ve version truoc.
2. Neu issue o schema/migration:
   - thuc hien plan rollback theo migration review checklist.
3. Neu issue o cache/retention config:
   - tat hoac dieu chinh qua env vars va redeploy.

## 6. Post-Release Validation

1. Verify health + metrics endpoints.
2. Chay smoke APIs (overview/dashboard/backfill).
3. Theo doi error rate + latency trong 24h dau.

## 7. References

1. `docs/system/analytics/analytics-wave1-evidence.md`
2. `docs/system/analytics/analytics-backend-dod.md`
3. `docs/system/analytics/analytics-migration-review.md`
