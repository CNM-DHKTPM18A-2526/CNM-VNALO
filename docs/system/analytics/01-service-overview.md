# Analytics Service Overview

## 1. Service Mission

Analytics service cung cap du lieu tong hop cho dashboard van hanh va moderation governance.

Muc tieu:

1. Thu nhan su kien noi bo va tong hop metric theo ngay.
2. Cung cap API query cho dashboard admin/moderator.
3. Ho tro backfill de sua du lieu lich su co kiem soat.
4. Dam bao quan sat duoc qua metric/SLI/SLO.

## 2. Current Scope

In scope:

1. Overview, trend, breakdown, dashboard bundle APIs.
2. Internal ingestion endpoint `/internal/events`.
3. Daily aggregation scheduler + retention cleanup scheduler.
4. Backfill job tracking, retry/resume, progress metric/log.
5. Dashboard cache strategy + invalidation hooks.

Out of scope:

1. Realtime analytics cap giay.
2. BI ad-hoc query cho end-user.

## 3. Core Capabilities

1. Query APIs cho analytics dashboards.
2. Access control qua JWT + moderation role guard.
3. Internal API-key auth cho ingestion service-to-service.
4. Operational safeguards: retention, cache, SLI/SLO baseline.

## 4. Release State

1. Wave 1 release gate: GO.
2. Wave 2 operational hardening: Done (W2-01, W2-02, W2-03).
3. Local verification gan nhat: `./mvnw -B test` pass (27 tests).

## 5. Key References

1. `docs/system/analytics/analytics-service-complete-requirements.md`
2. `docs/system/analytics/analytics-wave1-evidence.md`
3. `docs/system/analytics/analytics-wave2-operational-plan.md`
4. `docs/system/analytics/analytics-go-no-go-checklist.md`
