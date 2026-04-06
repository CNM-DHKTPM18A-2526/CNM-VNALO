# Analytics Testing Strategy And Quality

## 1. Test Layers

1. Unit tests:
   - Example: overview service logic.
2. Integration tests:
   - Security contract.
   - Schema/query regression.
   - Backfill reliability.
   - Retention cleanup.
   - SLI interceptor.
   - Cache strategy/invalidation.
3. API smoke E2E:
   - PowerShell script + Postman collection.

## 2. Quality Gates

1. `./mvnw -B test` pass local.
2. Analytics CI workflow pass tren PR/main.
3. E2E smoke script pass tren local stack.

## 3. Current Verification Snapshot

1. Local test suite: pass (27 tests).
2. Security contract scenarios 401/403/400 da duoc cover.
3. Backfill retry/idempotent + metrics da duoc cover.
4. Wave 2 features (retention, SLI, cache) co test xac nhan.

## 4. Required Test Artifacts

1. Unit/integration test logs trong CI.
2. E2E API smoke output.
3. Checklists dong bo:
   - `docs/system/analytics/analytics-backend-dod.md`
   - `docs/system/analytics/analytics-go-no-go-checklist.md`

## 5. References

1. `docs/system/analytics/analytics-api-test-guide.md`
2. `docs/system/postman/analytics-e2e.postman_collection.json`
3. `scripts/analytics-e2e-14.ps1`
