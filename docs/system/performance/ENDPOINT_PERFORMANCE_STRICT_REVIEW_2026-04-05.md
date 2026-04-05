# Endpoint Performance Strict Review

Date: 2026-04-05
Scope: core-service, message-service, media-service runtime endpoints
Data source:
- docs/feedback/ENTERPRISE_FULL_API_IO_2026-04-05.json (79/79 successful run)
- docs/feedback/ENTERPRISE_ENDPOINT_IO_2026-04-05.json (repeated benchmark subset)

## TL;DR

- Functional quality is strong (79/79 pass), but latency profile is not yet realtime-grade.
- 12/79 successful calls exceed 200 ms.
- Auth endpoints are the most urgent bottleneck.

## Strict SLA Bands

- Excellent: <= 100 ms
- Acceptable: 101-200 ms
- Needs improvement: 201-400 ms
- Critical: > 400 ms or p95 > 500 ms

## Aggregated Results (Latest Full Run)

- Total endpoints: 79
- Passed: 79
- Average latency: 126.75 ms
- > 200 ms: 12 endpoints
- > 400 ms: 8 endpoints
- > 600 ms: 4 endpoints

## Priority Ranking (Strict)

P0 - Immediate
1. core-service: POST /api/v1/auth/login
- grouped avg: 541.25 ms
- max: 796 ms
- repeated benchmark: avg 428.4 ms, p95 612.33 ms
- verdict: Critical

2. core-service: POST /api/v1/auth/register
- grouped avg: 301.0 ms
- max: 549 ms (success-path samples); separate functional sample observed at 771.44 ms
- verdict: Needs improvement -> Critical under variance

3. message-service: GET /api/v1/conversations/{id}/messages
- grouped avg: 625.5 ms
- max: 1194 ms
- verdict: Critical

P1 - Near-term
1. media-service: POST /api/v1/media/upload
- sample: 783 ms
- verdict: Needs improvement

2. message-service: POST /api/v1/conversations/direct
- grouped avg: 129.0 ms
- p95-like estimate from run: > 200 ms at tail
- verdict: Borderline

P2 - Monitor
- core-service: GET /api/v1/users/me and PATCH /api/v1/users/me
- health endpoints single-shot warmup outliers

## Why Performance Is Degrading (Likely Root Causes)

1. Auth path is compute + IO heavy on hot path
- password hash verification + token generation + user/session persistence are likely serialized.
- synchronous side effects in login/register may be adding latency.

2. Message history endpoint likely query/index mismatch
- GET /conversations/{id}/messages tail latency suggests expensive sorting/filtering and/or hydration.
- potential N+1 payload enrichment in message retrieval pipeline.

3. Register flow potentially doing too much before returning
- uniqueness checks + user creation + token issue + profile init in one request.

4. Media upload response is likely coupled to storage completion
- if the API waits for all post-upload steps synchronously, tail latency will spike.

## Remediation Plan

P0 Actions (this sprint)
1. auth/login profiling
- capture breakdown: DB lookup, password verify, JWT issue, refresh token write.
- add timing spans around each segment and export metrics.

2. auth/register critical-path split
- return earlier after durable user + token creation.
- defer non-critical setup to async worker/event.

3. message history query optimization
- verify and enforce composite index: (conversation_id, created_at desc).
- check explain plan for cursor query.
- remove N+1 member/user hydration where possible.

P1 Actions
1. media upload pipeline
- return once file is persisted and URL is issued.
- defer thumbnail/extra processing asynchronously.

2. introduce endpoint-level SLO monitors
- p50/p95/p99 for auth/login, auth/register, conversations/{id}/messages.

## Suggested SLO Targets

- auth/login: p50 < 180 ms, p95 < 350 ms
- auth/register: p50 < 220 ms, p95 < 450 ms
- conversations/{id}/messages: p50 < 150 ms, p95 < 300 ms
- media/upload: p50 < 250 ms, p95 < 500 ms
