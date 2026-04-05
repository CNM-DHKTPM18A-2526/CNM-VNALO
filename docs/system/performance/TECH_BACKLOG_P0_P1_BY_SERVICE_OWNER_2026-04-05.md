# Technical Backlog P0/P1 by Service and Owner

Date: 2026-04-05
Owner mapping source: docs/project/team-assignment.md

## P0 - Must Fix Immediately

### core-service (Owner: Dev 1)
- [ ] Optimize POST /auth/login critical path (password verify + token issue + refresh token persistence).
- [ ] Optimize POST /auth/register by separating critical path from non-critical setup steps.
- [ ] Add endpoint timing spans for auth endpoints and export p50/p95/p99.
- [ ] Verify DB indexes for auth lookup/write paths (phone, token hash, device-scoped token revoke).

### message-service (Owner: Dev 1)
- [ ] Optimize GET /conversations/{id}/messages query plan and pagination strategy.
- [ ] Remove N+1 style hydration in message history path if present.
- [ ] Add/verify index strategy for conversation_id + created_at and search path.

### media-service (Owner: Dev 2)
- [ ] Reduce POST /media/upload tail latency by deferring non-critical post-processing.
- [ ] Add metrics on upload phases (receive, persist, transform, response).

## P1 - High Priority Next

### core-service (Owner: Dev 1)
- [ ] Add benchmark suite (30 iterations) for /auth/login and /auth/register in warm/cold modes.
- [ ] Define auth SLO and regression gate in CI report artifacts.

### message-service (Owner: Dev 1)
- [ ] Add load test scenarios for large conversations and long history windows.
- [ ] Add route-level cache strategy for recent message windows where safe.

### realtime-gateway (Owner: Dev 2)
- [ ] Correlate websocket auth/room join latency with core/message service bottlenecks.
- [ ] Add stricter room authorization regression tests under load.

### media-service (Owner: Dev 2)
- [ ] Introduce adaptive image processing profile based on file size and category.
- [ ] Add object-storage client tuning and retry budget audit.

### content-service + notification-service (Owner: Dev 3)
- [ ] Ensure future content/notification endpoints have p95 instrumentation from day one.
- [ ] Add anti-regression checklist for auth, CORS, and latency budgets.

### moderation-service + analytics-service + ai-service (Owner: Dev 4)
- [ ] Add centralized latency dashboard integration for admin and analytics endpoints.
- [ ] Add periodic endpoint percentile report job and team alerting thresholds.

## Done in This Iteration

- [x] Mobile auth UX loading-state split and skip timeout UX improvement.
- [x] Strict endpoint performance review report published for team.
- [x] Auth/message percentile metrics report (p95/p99) published.
