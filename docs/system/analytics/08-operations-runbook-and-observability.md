# Analytics Operations Runbook And Observability

## 1. Observability Baseline

Metrics baseline da co:

1. Request counter theo endpoint SLI scope.
2. Error counter theo endpoint.
3. Latency timer theo endpoint/outcome.
4. Backfill job counters + duration timer.
5. Cache invalidation counter theo reason.

## 2. Actuator Exposure

Prod profile expose:

1. health
2. info
3. metrics

## 3. Incident Quick Checks

1. Kiem tra health endpoint.
2. Kiem tra metric endpoint analytics.sli.\*.
3. Kiem tra logs backfill progress/failure.
4. Kiem tra retention cleanup logs.
5. Kiem tra DB query/load neu latency tang.

## 4. Common Runbook Actions

1. Backfill theo range nho de khoi phuc metric.
2. Re-run scheduler hoac trigger aggregate theo ngay (qua service method/ops flow).
3. Dieu chinh cache TTL qua env config khi can.
4. Dieu chinh retention windows theo nhu cau storage.

## 5. Alerting and SLO

SLO/alert baseline chi tiet:

1. `docs/system/analytics/analytics-operations-slo.md`

## 6. References

1. `docs/system/analytics/analytics-wave2-operational-plan.md`
2. `docs/system/analytics/analytics-operations-slo.md`
