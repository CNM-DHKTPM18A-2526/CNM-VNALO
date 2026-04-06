# Analytics Service

Analytics and reporting service for VNALO platform.

## Features

- **Event Ingestion**: Collect events from all services
- **Daily Aggregation**: Automated daily metric calculation
- **Overview Reports**: Summary statistics (users, conversations, messages, reports, actions)
- **Trend Analysis**: Daily trends for key metrics
- **Breakdown Reports**: Detailed breakdowns by categories
- **Active User Metrics**: DAU/WAU/MAU summary
- **Admin Dashboard API**: Single endpoint for chart/table data with time filters
- **Backfill Support**: Re-aggregate historical metrics

## API Endpoints

### Overview

- `GET /api/v1/analytics/overview?from=2026-03-01&to=2026-03-18` - Get overview stats

### Trends

- `GET /api/v1/analytics/users/trend` - User growth trend
- `GET /api/v1/analytics/conversations/trend` - Conversation trend
- `GET /api/v1/analytics/messages/trend` - Message volume trend
- `GET /api/v1/analytics/media/trend` - Media volume trend
- `GET /api/v1/analytics/groups/trend` - Group creation trend
- `GET /api/v1/analytics/reports/trend` - Report trend
- `GET /api/v1/analytics/actions/trend` - Moderation action trend

### Activity

- `GET /api/v1/analytics/users/active-summary` - DAU/WAU/MAU
- `GET /api/v1/analytics/users/top-active` - Top active users by message count
- `GET /api/v1/analytics/dashboard` - Dashboard bundle (overview + trends + top users)

### Breakdowns

- `GET /api/v1/analytics/reports/reasons` - Report reasons breakdown
- `GET /api/v1/analytics/reports/target-types` - Report target types
- `GET /api/v1/analytics/messages/types` - Message types
- `GET /api/v1/analytics/conversations/types` - Conversation types

### Ingestion

- `POST /internal/events` - Ingest analytics event

### Backfill

- `POST /api/v1/analytics/backfill?from=2026-03-01&to=2026-03-18` - Re-aggregate metrics

## Metric Definitions

### User Metrics

- **totalUsers**: Total registered users
- **activeUsers**: Users with activity in period
- **DAU**: Distinct active users in latest day of selected range
- **WAU**: Distinct active users in latest 7 days of selected range
- **MAU**: Distinct active users in latest 30 days of selected range

### Conversation Metrics

- **totalConversations**: Total conversations created
- **directConversations**: 1:1 conversations
- **groupConversations**: Group conversations

### Message Metrics

- **totalMessages**: Total messages sent
- **textMessages**: Text-only messages
- **mediaMessages**: Messages with attachments

### Moderation Metrics

- **totalReports**: Total reports submitted
- **resolvedReports**: Reports with resolution
- **totalActions**: Moderation actions taken

## Setup

1. Ensure PostgreSQL is running
2. Start service in dev profile: `mvn spring-boot:run`

## Profiles

- `dev` (default):
  - `ddl-auto=validate`
  - Flyway `baseline-on-migrate=true`, `baseline-version=0`
  - Safe for local onboarding with existing shared schema
- `prod`:
  - `ddl-auto=validate`
  - Flyway `baseline-on-migrate=false`
  - Fails fast when schema is unmanaged or drifted

## Production Guardrail

- CI workflow: `.github/workflows/analytics-production-guard.yml`
- The workflow starts `postgres`, `redis`, and `analytics-service` with `SPRING_PROFILES_ACTIVE=prod`.
- Build fails if analytics health check never becomes `healthy`, which catches migration/schema drift early.

## Environment Variables

- `JWT_SECRET`: HS512 secret key
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`: PostgreSQL connection settings

## Known Limitations

- Metrics calculated daily; no real-time updates
- Aggregation is synchronous; may be slow for large date ranges
- No data retention policy defined
- Backfill is basic; no incremental updates
