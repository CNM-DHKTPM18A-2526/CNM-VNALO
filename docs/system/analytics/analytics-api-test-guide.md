# Analytics API Test Guide

Huong dan test analytics-service trong local.

## Nhanh nhat

- Run `scripts/analytics-e2e-14.ps1`
- Script se:
  1. Register user
  2. Login lay JWT
  3. Seed quyen analytics vao `moderation_admin_user`
  4. Goi 14 request smoke

## Postman

Import 2 file:

- `docs/system/postman/analytics-e2e.postman_collection.json`
- `docs/system/postman/analytics-local.postman_environment.json`

## Thu tu test

1. Health
2. Register
3. Login
4. Overview
5. Users trend
6. Conversations trend
7. Messages trend
8. Reports trend
9. Actions trend
10. Reports reasons
11. Reports target-types
12. Messages types
13. Conversations types
14. Backfill

## Bootstrap quyen

```powershell
$USER_ID = "<userId>"

docker exec -it vnalo-postgres psql -U postgres -d vnalo_core -c "
INSERT INTO moderation_admin_user(user_id, role, is_active, created_at, updated_at)
VALUES ('$USER_ID', 'ADMIN', true, now(), now())
ON CONFLICT (user_id)
DO UPDATE SET role='ADMIN', is_active=true, updated_at=now();
"
```

## Loi thuong gap

- 401: thieu token hoac token sai
- 403: chua seed `moderation_admin_user` hoac role/active sai
- 400: ngay sai format hoac from > to
- 404: sai path endpoint

## Reference

- [Analytics API Catalog](analytics-api-catalog.md)
- [Analytics Service Complete Requirements](analytics-service-complete-requirements.md)
