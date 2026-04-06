# Analytics Authn Authz Role Matrix

## 1. Authentication Modes

1. User-facing analytics APIs:
   - JWT Bearer token.
2. Internal ingestion endpoint:
   - `X-Internal-Api-Key`.

## 2. Authorization Rules

1. MODERATOR:
   - Duoc goi GET APIs duoi `/api/v1/analytics/*`.
2. ADMIN:
   - Duoc goi toan bo analytics APIs, gom backfill.
3. USER:
   - Khong duoc truy cap analytics APIs.
4. Internal service principal:
   - Duoc goi `/internal/events` khi API key hop le.

## 3. Enforcement Points

1. Spring Security filter chain enforce authn 401/403 baseline.
2. `AnalyticsAccessGuardService` enforce role ton tai va active trong `moderation_admin_user`.
3. `InternalServiceAuthenticationFilter` enforce API key cho internal route.

## 4. Role x Endpoint Matrix

| Endpoint Group           | USER | MODERATOR | ADMIN | Internal Service |
| ------------------------ | ---- | --------- | ----- | ---------------- |
| GET analytics query APIs | No   | Yes       | Yes   | No               |
| POST analytics backfill  | No   | No        | Yes   | No               |
| POST /internal/events    | No   | No        | No    | Yes              |

## 5. Contract Expectations

1. Missing/invalid JWT -> 401.
2. Authenticated but no permission -> 403.
3. Invalid/missing internal key -> unauthorized/forbidden on internal route.

## 6. References

1. `docs/system/analytics/analytics-api-catalog.md`
2. `docs/system/analytics/analytics-service-complete-requirements.md`
