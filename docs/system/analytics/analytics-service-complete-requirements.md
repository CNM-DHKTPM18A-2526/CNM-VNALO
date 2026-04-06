# Analytics Service Complete Requirements

Tai lieu nay la nguon yeu cau chuc nang chinh trong folder analytics.

## Pham vi

- Ingestion su kien noi bo qua `/internal/events`
- Aggregation metric theo ngay
- API dashboard cho moderator/admin
- Backfill theo khoang ngay
- Validation va error contract on dinh
- Auth/authz cho analytics va internal ingestion

## Role

- MODERATOR: duoc goi cac GET analytics APIs
- ADMIN: duoc goi tat ca analytics APIs, gom backfill
- INTERNAL SERVICE CLIENT: duoc goi `/internal/events` bang API key rieng

## FR chinh

1. FR-01: Internal event ingestion
2. FR-02: Daily aggregation
3. FR-03: Query API dashboard
4. FR-04: Validation va error contract
5. FR-05: Backfill du lieu
6. FR-06: Security mo rong cho internal events

## Acceptance

- Tat ca GET analytics tra 200 khi token hop le va role hop le
- Backfill chi ADMIN duoc goi
- Date range validate: from <= to, max 366 ngay
- /internal/events dung auth service-to-service rieng

## Reference

- [Analytics API Catalog](analytics-api-catalog.md)
- [Analytics API Test Guide](analytics-api-test-guide.md)
- [Analytics Operations SLO](analytics-operations-slo.md)
- [Analytics Backend DoD](analytics-backend-dod.md)
