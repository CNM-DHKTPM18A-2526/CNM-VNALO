# Analytics API Spec And Catalog

Tai lieu nay la ban dong bo theo format moderation core docs.

## 1. Canonical Source

Noi dung chi tiet API va contract duoc quan ly tai:

1. `docs/system/analytics/analytics-api-catalog.md`

Tai lieu hien tai giu vai tro entrypoint de doi ngu tim nhanh theo bo 10 tai lieu core.

## 2. API Groups

1. System:
   - `GET /actuator/health`
2. Query APIs:
   - overview, trend, breakdown, dashboard bundle, active summary, top active
3. Admin API:
   - `POST /api/v1/analytics/backfill`
4. Internal API:
   - `POST /internal/events`

## 3. Contract Highlights

1. Date range validation: from <= to, max 366 days.
2. Error contract: ANA_001, ANA_002, ERR_401, ERR_403.
3. Backfill: admin-only, job tracking, retry/resume by range.

## 4. Testing References

1. `docs/system/analytics/analytics-api-test-guide.md`
2. `docs/system/postman/analytics-e2e.postman_collection.json`
3. `docs/system/postman/analytics-local.postman_environment.json`
