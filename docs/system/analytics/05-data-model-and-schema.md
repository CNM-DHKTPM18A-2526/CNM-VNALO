# Analytics Data Model And Schema

## 1. Schema Scope

Analytics service su dung migration track rieng:

1. `V1__init_analytics_schema.sql`
2. Flyway history table: `flyway_schema_history_analytics`

## 2. Core Tables

1. `analytics_event`
   - Luu raw/internal events.
2. `analytics_daily_metric`
   - Luu metric tong hop theo ngay + dimension.
3. `analytics_backfill_job`
   - Luu thong tin job backfill, status, progress, error.

## 3. Key Constraints

1. Daily metric unique theo metric_date + metric_key + dimension.
2. Backfill job unique theo date range (from_date, to_date) de ho tro idempotent retry/resume.

## 4. Retention Strategy

Retention cleanup da duoc implement:

1. Event retention by occurredAt cutoff.
2. Daily metric retention by metricDate cutoff.
3. Backfill job retention by finishedAt cutoff.

Config qua `analytics.retention.*` trong application properties.

## 5. Query/Index Considerations

1. Index cho event type/time, source/time, actor/time.
2. Index cho metric date + key.
3. Index cho backfill status + started.

## 6. References

1. `docs/system/database-schema.md`
2. `docs/system/analytics/analytics-migration-review.md`
