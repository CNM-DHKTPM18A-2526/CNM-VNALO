# Auth Login Optimization Benchmark (Post-Change)

Date: 2026-04-05
Branch: nguyenvu

## Scope
- Code optimization: removed redundant Spring Security authenticate step in core-service login path and used direct password hash validation on preloaded account.
- File: `backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/service/AuthService.java`
- Validation: updated unit tests and reran benchmark scripts.

## Build/Test Validation
- `core-service` unit tests: PASS (`43` tests, `0` failures).

## Benchmark Inputs
- Baseline source (before optimization): `docs/system/performance/AUTH_MESSAGE_P95_P99_METRICS_2026-04-05.md` (repeated benchmark subset)
- Post-change source: `docs/feedback/ENTERPRISE_ENDPOINT_IO_2026-04-05.json`

## Login Route Delta (Core-Service)
Route: `POST /auth/login` (8-iteration repeated benchmark)

| Metric | Baseline (ms) | Post-change (ms) | Delta | Improvement |
|---|---:|---:|---:|---:|
| Avg | 428.40 | 328.89 | -99.51 | 23.23% |
| P50 | 375.36 | 292.64 | -82.72 | 22.04% |
| P95 | 612.33 | 508.56 | -103.77 | 16.95% |

## Stability Rerun (Full Enterprise Script)
Source: `docs/feedback/ENTERPRISE_FULL_API_IO_2026-04-05.json`

- Total: 79
- Passed: 77
- Failed: 2
- Average latency: 156.6ms

Residual failures in latest full run:
1. `GET http://localhost:8083/actuator/health`
2. `POST http://localhost:8083/api/v1/media/upload`

Notes:
- Cross-service auth failures (401 cascade in message-service) were resolved by aligning JWT env across containers using the same compose env file.
- Remaining failures are isolated to media-service health/upload and are not part of the core auth/login optimization path.
