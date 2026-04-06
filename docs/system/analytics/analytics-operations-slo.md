# Analytics Operations SLO

Tai lieu nay dinh nghia SLI/SLO va alert cho analytics-service.

## Scope

- `GET /api/v1/analytics/overview`
- `GET /api/v1/analytics/dashboard`
- `POST /api/v1/analytics/backfill`

## SLI

- Availability = 1 - errors_total / requests_total
- Latency = P95 theo endpoint
- Backfill reliability = ty le job completed

## Targets

- Overview availability >= 99.5%
- Dashboard availability >= 99.5%
- Backfill availability >= 99.0%
- Dashboard P95 <= 1500ms
- Overview P95 <= 800ms

## Alerts

- Error rate > 5% trong 10 phut: critical
- Dashboard P95 > 2500ms trong 15 phut: critical
- Backfill failed >= 3 trong 1 gio: critical

## Runbook

1. Kiem tra health va metrics endpoint
2. Kiem tra log backfill/retention
3. Kiem tra DB slow query neu dashboard cham
4. Retry backfill theo range nho neu can

## Reference

- `docs/system/analytics/08-operations-runbook-and-observability.md`
- `docs/system/analytics/09-cicd-release-and-rollback.md`
