# Analytics API Catalog

Tai lieu nay tong hop danh muc endpoint analytics-service.

## Base

- Local base URL: `http://localhost:8084/api/v1`
- Health: `GET /actuator/health`
- Swagger: `/swagger-ui/index.html`, `/v3/api-docs`

## Auth

- Bearer JWT cho cac endpoint analytics
- `moderation_admin_user` phai co record active
- `MODERATOR` va `ADMIN` duoc goi GET analytics
- `ADMIN` duoc goi `POST /api/v1/analytics/backfill`

## Endpoint groups

1. Overview

- `GET /api/v1/analytics/overview?from=YYYY-MM-DD&to=YYYY-MM-DD`

2. Trends

- `GET /api/v1/analytics/users/trend`
- `GET /api/v1/analytics/conversations/trend`
- `GET /api/v1/analytics/messages/trend`
- `GET /api/v1/analytics/reports/trend`
- `GET /api/v1/analytics/actions/trend`

3. Breakdown

- `GET /api/v1/analytics/reports/reasons`
- `GET /api/v1/analytics/reports/target-types`
- `GET /api/v1/analytics/messages/types`
- `GET /api/v1/analytics/conversations/types`

4. Dashboard

- `GET /api/v1/analytics/dashboard`
- `GET /api/v1/analytics/users/active-summary`
- `GET /api/v1/analytics/users/top-active`

5. Admin

- `POST /api/v1/analytics/backfill?from=...&to=...`

6. Internal

- `POST /internal/events`

## Error codes

- `ANA_001`: Access forbidden
- `ANA_002`: Invalid date range
- `ERR_401`: Unauthorized
- `ERR_403`: Access denied

## Reference

- [Analytics API Test Guide](analytics-api-test-guide.md)
- [Analytics Service Complete Requirements](analytics-service-complete-requirements.md)
