# ERROR CODE MATRIX

> [!IMPORTANT]
> This matrix is extracted from current exception classes, enum contracts, and gateway return payloads in source.

## Error Envelope Contracts

| Surface | Envelope | Example |
|---|---|---|
| Core and Moderation (Java) | `ApiResponse.error(code, message, details?)` | `{ "success": false, "error": { "code": "AUTH_001", "message": "Invalid credentials" } }` |
| Content (Java) | map with `timestamp`, `code`, `message`, optional `errors` | `{ "code": "CONTENT_001", "message": "Post not found" }` |
| Analytics (Java) | `ApiResponse.error(message, code)` | `{ "success": false, "code": "ANA_002", "message": "Invalid date range" }` |
| AI and Media (Java) | `ApiResponse.error(httpCodeNumber, message)` | `{ "code": 429, "message": "Rate limited" }` |
| Message REST (Node) | Nest default error body | `{ "statusCode": 403, "message": "You are not a member of this conversation", "error": "Forbidden" }` |
| Socket chat (Node) | ACK object with `event` and `data.error` | `{ "event": "message.error", "data": { "error": "Cannot recall messages older than 24 hours" } }` |

## Java Service Error Catalog

### core-service

| Category | Codes | Primary HTTP Mapping |
|---|---|---|
| Generic | `ERR_500`, `ERR_400`, `ERR_404`, `ERR_403`, `ERR_401` | 500, 400, 404, 403, 401 |
| Auth | `AUTH_001` to `AUTH_024` | 401, 403, 409, 400 depending on case |
| User | `USER_001` to `USER_004` | mostly 404 and 400 |
| Social | `SOCIAL_001` to `SOCIAL_012` | 403, 404, 409, 400 |

`ApiException.resolveStatus` rules:
- 500: `INTERNAL_ERROR`.
- 404: `RESOURCE_NOT_FOUND`, `USER_NOT_FOUND`, `USER_PROFILE_NOT_FOUND`, `SOCIAL_REQUEST_NOT_FOUND`.
- 403: `ACCESS_DENIED`, `SOCIAL_NOT_REQUEST_RECIPIENT`, `SOCIAL_PRIVACY_RESTRICTION`, `SOCIAL_USER_BLOCKED`, `SOCIAL_BLOCKED_BY_USER`, plus disabled or locked auth accounts.
- 401: credential/token errors.
- 409: existing phone, already friend, already sent request, already blocked.
- 400 default: all unmatched enum values.

### content-service

| Code | Meaning | HTTP |
|---|---|---|
| `CONTENT_001` | Post not found | 404 |
| `CONTENT_002` | Comment not found | 404 |
| `CONTENT_003` | Invalid request | 400 |
| `CONTENT_004` | Forbidden | 403 |
| `CONTENT_005` | Story not found | 404 |
| `CONTENT_999` | Internal error | 500 |

### moderation-service

| Code | Meaning | HTTP |
|---|---|---|
| `ERR_500` | Internal server error | 500 |
| `ERR_400` | Validation failed | 400 |
| `ERR_404` | Resource not found | 404 |
| `ERR_403` | Access denied | 403 |
| `ERR_401` | Unauthorized | 401 |
| `MOD_001` | Report not found | 404 |
| `MOD_002` | Moderation case not found | 404 |
| `MOD_003` | Moderation action not found | 404 |
| `MOD_004` | Invalid target type | 400 |
| `MOD_005` | Case already assigned | 400 |
| `MOD_006` | Insufficient permissions | 403 |
| `MOD_007` | Report already resolved | 400 |
| `MOD_008` | Invalid status transition | 400 |
| `MOD_009` | Moderation target not found | 404 |
| `MOD_010` | Moderation forbidden | 403 |

### analytics-service

| Code | Meaning | HTTP |
|---|---|---|
| `ANA_001` | Analytics forbidden | 403 |
| `ANA_002` | Invalid date range | 400 |
| `ANA_002_A` | Missing parameter | 400 |
| `ANA_002_B` | Date range too large | 400 |
| `ANA_003` | Event ingestion failed | 400 |
| `INTERNAL_ERROR` (literal) | Generic fallback | 500 |

### media-service

Media service does not use enum symbols; it uses typed exceptions mapped by handler:

| Exception Type | HTTP Code in body | HTTP Status |
|---|---|---|
| `ResourceNotFoundException` | 404 | 404 |
| `UnauthorizedException` | 401 | 401 |
| `AccessDeniedException` | 403 | 403 |
| `RateLimitExceededException` | 429 | 429 |
| `MaxUploadSizeExceededException` | 413 | 413 |
| `IllegalArgumentException` | 400 | 400 |
| `RuntimeException` | 400 | 400 |
| fallback `Exception` | 500 | 500 |

### ai-service

| Exception Type | HTTP Code in body | HTTP Status |
|---|---|---|
| `RateLimitExceededException` | 429 | 429 |
| `AiUnavailableException` | 503 | 503 |
| `MethodArgumentNotValidException` | 400 | 400 |
| `IllegalArgumentException` | 400 | 400 |
| fallback `Exception` | 500 | 500 |

### notification-service

`ErrorCode` and `ApiException` are defined but not actively used in controller/service paths. Current business path throws `IllegalArgumentException("Notification not found")` in `markRead`, which falls back to default Spring error body unless additional handler is added.

## Node Service Error Catalog

### message-service REST

| Scope | Exception Class | HTTP | Typical Messages |
|---|---|---|---|
| Conversation APIs | `BadRequestException` | 400 | cannot create with self, member limit exceeded, group-only operations |
| Conversation APIs | `ForbiddenException` | 403 | not member, admin-owner required, invite-only restrictions |
| Conversation APIs | `NotFoundException` | 404 | conversation, member, or join request not found |
| Message APIs | `BadRequestException` | 400 | invalid content, recalled/pinned constraints, 24h recall window |
| Message APIs | `ForbiddenException` | 403 | not owner/admin, restricted web policy |
| Message APIs | `NotFoundException` | 404 | message, reaction, pin not found |

### message-service socket acknowledgements

| Event Family | Error ACK/Event | Payload |
|---|---|---|
| Conversation join | `conversation.error` | `{ error: string }` |
| Message send/recall/pin/unpin | `message.error` | `{ error: string }` |
| Call signaling | `call.error` | `{ error: string }` |

### realtime-gateway socket behavior

| Scenario | Behavior |
|---|---|
| Missing or invalid JWT in handshake | connection rejected, socket disconnected |
| Join over room cap | returns `{ event: "error", data: { message: "Exceeded max conversation limit" } }` |
| Typing/presence errors | mostly logged and ignored, no unified error envelope |

## Cross-Service Gaps and Drift

> [!WARNING]
> Error handling is not yet normalized across services.

- Mixed code types: string domain codes (`AUTH_001`) and numeric HTTP codes (`429`) coexist.
- Mixed envelope schemas: `ApiResponse.error(...)`, plain maps, and Nest default error body.
- Notification service defines reusable error enums but runtime path currently bypasses them.
- Socket error contracts are event-name based and not aligned with REST code enums.

## Recommended Normalization Target

- Use a common canonical error envelope for REST:
  - `code` as stable string, `message` as user-facing detail, `traceId` optional.
- Preserve numeric status in transport (`HTTP status`) and keep semantic code domain-specific.
- Define socket error mirror:
  - `{ code, message, context }` in all `*.error` events.
- Add explicit exception advice in notification-service and node-services for deterministic contracts.

## Evidence

- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/exception
- backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/exception
- backend/java-services/services/moderation-service/src/main/java/iuh/cnm/vnalo/moderation_service/exception
- backend/java-services/services/analytics-service/src/main/java/iuh/cnm/vnalo/analytics_service/exception
- backend/java-services/services/media-service/src/main/java/iuh/cnm/vnalo/mediaservice/exception
- backend/java-services/services/ai-service/src/main/java/iuh/cnm/vnalo/aiservice/exception
- backend/java-services/services/notification-service/src/main/java/iuh/cnm/vnalo/notification_service
- backend/node-services/apps/message-service/src/conversation
- backend/node-services/apps/message-service/src/message
- backend/node-services/apps/message-service/src/gateway
- backend/node-services/apps/realtime-gateway/src/gateway
