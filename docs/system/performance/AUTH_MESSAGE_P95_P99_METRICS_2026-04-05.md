# Auth + Message P95/P99 Metrics

Date: 2026-04-05

This report focuses on auth and message endpoints using the latest enterprise run.

Data sources:
- docs/feedback/ENTERPRISE_FULL_API_IO_2026-04-05.json
- docs/feedback/ENTERPRISE_ENDPOINT_IO_2026-04-05.json

Method note:
- For routes with multiple samples in the full enterprise run, p50/p95/p99 are estimated from observed samples.
- For routes with only one sample, p50/p95/p99 equal that sample and should be treated as weak-confidence indicators.
- Repeated benchmark values from ENTERPRISE_ENDPOINT_IO are considered stronger evidence where available.

## Core Auth Endpoints

| Service | Route | Calls | Avg (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Max (ms) | Confidence |
|---|---|---:|---:|---:|---:|---:|---:|---|
| core-service | POST /api/v1/auth/login | 4 | 541.25 | 511.50 | 769.60 | 790.72 | 796 | Medium |
| core-service | POST /api/v1/auth/register | 5 | 301.00 | 404.00 | 531.40 | 545.48 | 549 | Medium |

Repeated benchmark subset:
- core-service POST /auth/login (8 iterations): avg 428.4 ms, p50 375.36 ms, p95 612.33 ms, max 612.33 ms.

## Message Endpoints

| Service | Route | Calls | Avg (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Max (ms) | Confidence |
|---|---|---:|---:|---:|---:|---:|---:|---|
| message-service | GET /api/v1/conversations/{id}/messages | 2 | 625.50 | 625.50 | 1137.15 | 1182.63 | 1194 | Low-Medium |
| message-service | POST /api/v1/conversations/direct | 2 | 129.00 | 129.00 | 205.50 | 212.30 | 214 | Low-Medium |
| message-service | POST /api/v1/messages | 8 | 80.00 | 77.00 | 91.80 | 95.16 | 96 | Medium |
| message-service | PATCH /api/v1/messages/{id} | 1 | 110.00 | 110.00 | 110.00 | 110.00 | 110 | Low |
| message-service | GET /api/v1/conversations/{id}/messages/search | 2 | 34.50 | 34.50 | 37.65 | 37.93 | 38 | Low-Medium |

## Strict Interpretation

1. Login is currently above acceptable thresholds and should be treated as Critical.
2. Register latency is unstable and needs path simplification.
3. Message history endpoint has severe tail-latency risk.
4. Basic message send path is healthy and can be considered a relative strength.

## Immediate Follow-up Benchmark Plan

1. Run dedicated 30-iteration tests for:
- POST /auth/login
- POST /auth/register
- GET /conversations/{id}/messages (multiple conversation sizes)

2. Store benchmark output with fixed environment tags:
- warmup count
- payload size
- DB row cardinality snapshot
- cache state
