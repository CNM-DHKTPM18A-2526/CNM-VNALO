# Analytics Architecture Overview

## 1. High-Level Architecture

Analytics service la Spring Boot service doc/ghi tren schema analytics rieng trong PostgreSQL dung chung cluster.

Luong du lieu:

1. Internal events vao qua `/internal/events`.
2. Aggregation tinh metric theo ngay.
3. Query services doc schema chung (auth, message, moderation) va bang tong hop analytics.
4. API layer tra ve du lieu cho dashboard.

## 2. Main Components

1. Controllers:
   - `AnalyticsController`
   - `InternalEventController`
2. Domain services:
   - `AnalyticsOverviewService`, `AnalyticsTrendService`, `AnalyticsBreakdownService`, `AnalyticsDashboardService`
   - `BackfillJobService`, `AnalyticsDataRetentionService`
3. Query services:
   - Shared query services cho user/conversation/message/moderation data.
4. Schedulers:
   - `DailyAggregationScheduler`
   - `AnalyticsRetentionScheduler`
5. Observability + cache:
   - `AnalyticsSliMetricsInterceptor`
   - Caffeine cache manager + invalidation service.

## 3. Data Flow Notes

1. Daily aggregation chay UTC yesterday.
2. Backfill chay theo ngay, co tracking va retry/resume.
3. Khi aggregation/backfill cap nhat du lieu, read caches bi clear de tranh stale data.

## 4. Operational Concerns

1. Retention cleanup theo cron + so ngay theo property.
2. Actuator metrics/health/info expose trong prod profile.
3. SLI metric co request/error/latency cho endpoint trong scope.

## 5. Reference

1. `docs/system/analytics/analytics-api-catalog.md`
2. `docs/system/analytics/analytics-operations-slo.md`
3. `docs/system/database-schema.md`
