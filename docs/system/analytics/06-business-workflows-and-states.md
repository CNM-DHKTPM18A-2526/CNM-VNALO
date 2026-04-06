# Analytics Business Workflows And States

## 1. Internal Event Ingestion Workflow

1. Service noi bo goi `POST /internal/events` voi API key.
2. Service validate payload + auth.
3. Event luu vao `analytics_event`.
4. Metric tong hop duoc cap nhat theo scheduler/backfill.

## 2. Daily Aggregation Workflow

1. Scheduler chay moi ngay (UTC yesterday).
2. Tinh metric theo ngay cho users/conversations/messages/reports/actions.
3. Upsert vao `analytics_daily_metric`.
4. Sau khi xong, clear read caches de dong bo du lieu query.

## 3. Backfill Workflow

1. Admin goi `POST /api/v1/analytics/backfill` voi from/to.
2. He thong load hoac tao `analytics_backfill_job` theo range.
3. Neu job FAILED: reopen va resume tu ngay chua xu ly.
4. Neu job COMPLETED: reuse ket qua (idempotent by range).
5. Trong khi chay: cap nhat progress, log, metrics.
6. Ket thuc: mark COMPLETED/FAILED + clear read caches.

## 4. Retention Workflow

1. `AnalyticsRetentionScheduler` chay theo cron.
2. Xoa du lieu qua han o 3 bang analytics.
3. Ghi log ket qua purge (so ban ghi da xoa).

## 5. Backfill Job States

1. RUNNING
2. COMPLETED
3. FAILED

Transition chinh:

1. RUNNING -> COMPLETED khi xu ly het ngay.
2. RUNNING -> FAILED khi exception runtime.
3. FAILED -> RUNNING khi retry/resume.

## 6. References

1. `docs/system/analytics/analytics-service-complete-requirements.md`
2. `docs/system/analytics/analytics-wave2-operational-plan.md`
