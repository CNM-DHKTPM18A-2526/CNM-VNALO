# API REFERENCE CATALOG

> [!IMPORTANT]
> This catalog is generated from controller and gateway source annotations, global prefixes, and service security configs.

## Service Base URL Matrix

| Service | Port | Canonical Prefix |
| --- | --- | --- |
| core-service | 8081 | /api/v1 |
| message-service | 3000 | /api/v1 |
| media-service | 8083 | none global, controller paths already include /api/v1/* |
| moderation-service | 8082 | /api/v1 |
| content-service | 8086 | /api/v1 |
| notification-service | 8087 | /api/v1 |
| ai-service | 8094 | none global, controller paths already include /api/v1/* |
| analytics-service | 8084 | none global, controller paths already include /api/v1/* |
| realtime-gateway | 8085 | no REST prefix, health endpoint only |

## Auth Model Matrix

| Service | Auth Mode |
| --- | --- |
| core-service | JWT bearer, selected auth endpoints public |
| message-service | JWT bearer for conversations/messages/inbox controllers |
| media-service | JWT bearer for protected endpoints, /api/v1/media/public/* is public |
| moderation-service | JWT bearer with role checks for reports and moderation paths |
| content-service | JWT bearer (JwtAuthenticationFilter enforced) |
| notification-service | JWT bearer (JwtAuthenticationFilter enforced) |
| ai-service | JWT bearer required for application endpoints |
| analytics-service | JWT bearer for /api/v1/analytics/* and internal authority for /internal/events |
| realtime-gateway | WS handshake JWT on /realtime namespace; REST health is open |



---

## core-service Endpoints

### Auth

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/auth/register/send-otp | Public | register OTP send |
| POST | /api/v1/auth/register | Public | register account |
| POST | /api/v1/auth/login | Public | issue tokens |
| POST | /api/v1/auth/refresh | Public | refresh tokens |
| POST | /api/v1/auth/logout | Public by route config | revokes current refresh token |
| POST | /api/v1/auth/logout-all | JWT | revoke all sessions |
| GET | /api/v1/auth/login-devices | JWT | list active login devices |
| GET | /api/v1/auth/session-audit | JWT | session audit |
| GET | /api/v1/auth/otp/status | Public | OTP feature status |
| POST | /api/v1/auth/change-password | JWT | change password |
| POST | /api/v1/auth/password/change | JWT | alias path |
| POST | /api/v1/auth/forgot-password | Public | forgot password |
| POST | /api/v1/auth/password/forgot/send-otp | Public | alias path |
| POST | /api/v1/auth/reset-password | Public | reset password |
| POST | /api/v1/auth/password/reset | Public | alias path |

### Auth QR

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/auth/qr/sessions | Public | create QR login session |
| GET | /api/v1/auth/qr/sessions/{token} | Public | get session status |
| GET | /api/v1/auth/qr/sessions/{token}/preview | Public | preview session |
| POST | /api/v1/auth/qr/sessions/{token}/approve | JWT | approve login |

### Users

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| GET | /api/v1/users/me | JWT | current user |
| GET | /api/v1/users/{userId} | JWT | user by id |
| PATCH | /api/v1/users/me | JWT | update profile |
| GET | /api/v1/users/search | JWT | search users |
| GET | /api/v1/users/phone/{phoneNumber} | JWT | phone lookup |
| GET | /api/v1/users/search-by-phone | JWT | query-param phone lookup |
| GET | /api/v1/users/me/privacy | JWT | read privacy settings |
| PUT | /api/v1/users/me/privacy | JWT | update privacy settings |
| GET | /api/v1/users/me/settings/sync | JWT | read sync settings |
| PUT | /api/v1/users/me/settings/sync | JWT | update sync settings |

### Friends

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/friends/requests | JWT | send request |
| GET | /api/v1/friends/requests/incoming | JWT | incoming requests |
| GET | /api/v1/friends/requests/sent | JWT | sent requests |
| POST | /api/v1/friends/requests/{requestId}/accept | JWT | accept |
| POST | /api/v1/friends/requests/{requestId}/decline | JWT | decline |
| DELETE | /api/v1/friends/requests/{requestId} | JWT | cancel |
| GET | /api/v1/friends | JWT | list friends |
| DELETE | /api/v1/friends/{friendId} | JWT | unfriend |
| GET | /api/v1/friends/{userId}/status | JWT | relationship status |
| GET | /api/v1/friends/stats | JWT | counts |

### Blocks

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/blocks/{userId} | JWT | block user |
| DELETE | /api/v1/blocks/{userId} | JWT | unblock user |
| GET | /api/v1/blocks | JWT | list blocked users |
| GET | /api/v1/blocks/{userId}/status | JWT | block status |

### Contacts and QR social

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/contacts/sync | JWT | sync contacts |
| GET | /api/v1/contacts/matched | JWT | matched contacts |
| GET | /api/v1/contacts | JWT | all synced contacts |
| DELETE | /api/v1/contacts | JWT | clear sync data |
| GET | /api/v1/qr/generate | JWT | generate QR payload |
| POST | /api/v1/qr/scan | JWT | scan QR |
| POST | /api/v1/qr/scan/add-friend | JWT | scan and add friend |

### Core test utility

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/test/fcm/send | JWT | send test push payload |
| POST | /api/v1/test/fcm/send-otp | JWT | send OTP-style test push payload |

---

## message-service Endpoints

### Conversation

| Method | Full Path | Auth |
| --- | --- | --- |
| POST | /api/v1/conversations/direct | JWT |
| POST | /api/v1/conversations/group | JWT |
| GET | /api/v1/conversations/{id} | JWT |
| PATCH | /api/v1/conversations/{id} | JWT | Body: {title, description, avatarUrl, joinMode, onlyAdminCanPost, allowMemberInvite, allowMemberPin, allowMemberEditInfo, highlightAdminMessages, showHistoryToNewMembers, allowMemberCreateNote, allowMemberCreatePoll} |
| POST | /api/v1/conversations/{id}/members | JWT | |
| DELETE | /api/v1/conversations/{id}/members/{userId} | JWT | |
| GET | /api/v1/conversations/{id}/members | JWT | |
| POST | /api/v1/conversations/{id}/join | JWT | |
| GET | /api/v1/conversations/{id}/join-requests | JWT | |
| POST | /api/v1/conversations/{id}/join-requests/{userId}/approve | JWT | |
| DELETE | /api/v1/conversations/{id}/join-requests/{userId} | JWT | |
| PATCH | /api/v1/conversations/{id}/member/{targetUserId} | JWT | |
| PATCH | /api/v1/conversations/{id}/wallpaper | JWT | |
| PATCH | /api/v1/conversations/{id}/members/{userId}/nickname | JWT | |
| POST | /api/v1/conversations/{id}/leave | JWT | |
| DELETE | /api/v1/conversations/{id} | JWT | disband group |
| GET | /api/v1/users/me/settings/sync | JWT | getSyncPolicy — sync settings for restrictedWebMode |

### Message

| Method | Full Path | Auth |
| --- | --- | --- |
| POST | /api/v1/messages | JWT |
| GET | /api/v1/conversations/{id}/messages | JWT |
| GET | /api/v1/conversations/{id}/messages/search | JWT |
| PATCH | /api/v1/messages/{id} | JWT |
| DELETE | /api/v1/messages/{id} | JWT |
| DELETE | /api/v1/messages/{id}/for-me | JWT |
| POST | /api/v1/messages/{id}/reactions | JWT |
| DELETE | /api/v1/messages/{id}/reactions | JWT |
| GET | /api/v1/messages/{id}/reactions | JWT |
| POST | /api/v1/conversations/{id}/pin/{messageId} | JWT |
| DELETE | /api/v1/conversations/{id}/pin/{messageId} | JWT |
| GET | /api/v1/conversations/{id}/pins | JWT |
| POST | /api/v1/conversations/{id}/read | JWT |

### Inbox and Health

| Method | Full Path | Auth |
| --- | --- | --- |
| GET | /api/v1/inbox | JWT |
| GET | /api/v1/inbox/unread-count | JWT |
| PATCH | /api/v1/inbox/{conversationId} | JWT |
| DELETE | /api/v1/inbox/{conversationId}/history | JWT |
| GET | /api/v1/health | Public |

---

## media-service Endpoints

### Media

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/media/upload | JWT | multipart upload |
| POST | /api/v1/media/initiate-upload | JWT | initiate upload |
| POST | /api/v1/media/{id}/complete | JWT | complete upload |
| GET | /api/v1/media/{id} | JWT | metadata |
| GET | /api/v1/media | JWT | list own media |
| DELETE | /api/v1/media/{id} | JWT | delete |
| PATCH | /api/v1/media/{id} | JWT | update metadata |
| PUT | /api/v1/media/{id}/replace | JWT | replace file |
| GET | /api/v1/media/{id}/download | JWT | download |
| GET | /api/v1/media/{id}/save | JWT | save action |
| GET | /api/v1/media/{id}/thumbnail | JWT | thumbnail |
| GET | /api/v1/media/{id}/status | JWT | processing status |
| POST | /api/v1/media/{id}/access | JWT | grant access |
| DELETE | /api/v1/media/{id}/access | JWT | revoke access |
| GET | /api/v1/media/{id}/access | JWT | access list |
| GET | /api/v1/media/public/{id} | Public | public retrieval |
| GET | /api/v1/media/public-file | Public | public file retrieval |

### Stickers

| Method | Full Path | Auth |
| --- | --- | --- |
| GET | /api/v1/stickers/packs | JWT |
| GET | /api/v1/stickers/packs/{packId} | JWT |
| POST | /api/v1/stickers/packs | JWT |
| PATCH | /api/v1/stickers/packs/{packId} | JWT |
| DELETE | /api/v1/stickers/packs/{packId} | JWT |
| POST | /api/v1/stickers/packs/{packId}/stickers | JWT |
| GET | /api/v1/stickers/{stickerId} | JWT |
| DELETE | /api/v1/stickers/{stickerId} | JWT |
| GET | /api/v1/stickers/search | JWT |
| POST | /api/v1/stickers/packs/{packId}/download | JWT |
| DELETE | /api/v1/stickers/packs/{packId}/download | JWT |
| GET | /api/v1/stickers/my-packs | JWT |
| POST | /api/v1/stickers/{stickerId}/use | JWT |
| GET | /api/v1/stickers/recent | JWT |

---

## moderation-service Endpoints

| Method | Full Path | Auth |
| --- | --- | --- |
| POST | /api/v1/reports | JWT role USER or MODERATOR or ADMIN |
| GET | /api/v1/reports/me | JWT role USER or MODERATOR or ADMIN |
| GET | /api/v1/moderation/reports | JWT |
| GET | /api/v1/moderation/reports/{reportId} | JWT |
| POST | /api/v1/moderation/reports/{reportId}/assign | JWT |
| POST | /api/v1/moderation/cases/{caseId}/resolve | JWT |
| POST | /api/v1/moderation/actions | JWT |
| POST | /api/v1/moderation/cases/{caseId}/appeal | JWT |
| GET | /api/v1/moderation/appeals | JWT |
| POST | /api/v1/moderation/appeals/{appealId}/resolve | JWT |
| POST | /api/v1/admin/users | JWT |

---

## content-service Endpoints

| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/stories | No JWT guard (permitAll) | requires X-User-Id header |
| GET | /api/v1/stories | No JWT guard (permitAll) | public read |
| DELETE | /api/v1/stories/{storyId} | No JWT guard (permitAll) | requires X-User-Id header |
| POST | /api/v1/stories/{storyId}/view | No JWT guard (permitAll) | requires X-User-Id header |
| GET | /api/v1/stories/{storyId}/views | No JWT guard (permitAll) | public read |
| POST | /api/v1/posts | No JWT guard (permitAll) | requires X-User-Id header |
| GET | /api/v1/posts/timeline | No JWT guard (permitAll) | public read |
| GET | /api/v1/posts/{postId} | No JWT guard (permitAll) | public read |
| PUT | /api/v1/posts/{postId} | No JWT guard (permitAll) | requires X-User-Id header |
| DELETE | /api/v1/posts/{postId} | No JWT guard (permitAll) | requires X-User-Id header |
| POST | /api/v1/posts/{postId}/like | No JWT guard (permitAll) | requires X-User-Id header |
| DELETE | /api/v1/posts/{postId}/like | No JWT guard (permitAll) | requires X-User-Id header |
| POST | /api/v1/posts/{postId}/comments | No JWT guard (permitAll) | requires X-User-Id header |
| GET | /api/v1/posts/{postId}/comments | No JWT guard (permitAll) | public read |
| PUT | /api/v1/comments/{commentId} | No JWT guard (permitAll) | requires X-User-Id header |
| DELETE | /api/v1/comments/{commentId} | No JWT guard (permitAll) | requires X-User-Id header |

---

## notification-service Endpoints

| Method | Full Path | Auth |
| --- | --- | --- |
| POST | /api/v1/notifications/devices | X-User-Id header required by controller |
| GET | /api/v1/notifications | X-User-Id header required by controller |
| GET | /api/v1/notifications/unread-count | X-User-Id header required by controller |
| PATCH | /api/v1/notifications/{id}/read | X-User-Id header required by controller |
| POST | /api/v1/notifications/test | No explicit auth in controller |
| GET | /api/v1/healthz | Public |

---

## ai-service Endpoints

| Method | Full Path | Auth |
| --- | --- | --- |
| Method | Full Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | /api/v1/ai/chat | JWT | mascot interaction |
| POST | /api/v1/ai/history/backup | JWT | cloud history sync |
| POST | /api/v1/chat/ask | JWT | legacy/direct prompt |
| GET | /api/v1/chat/history | JWT | fetch history |
| DELETE | /api/v1/chat/history | JWT | clear history |

---

## analytics-service Endpoints

| Method | Full Path | Auth |
| --- | --- | --- |
| GET | /api/v1/analytics/overview | JWT |
| GET | /api/v1/analytics/users/trend | JWT |
| GET | /api/v1/analytics/conversations/trend | JWT |
| GET | /api/v1/analytics/messages/trend | JWT |
| GET | /api/v1/analytics/media/trend | JWT |
| GET | /api/v1/analytics/groups/trend | JWT |
| GET | /api/v1/analytics/users/active-summary | JWT |
| GET | /api/v1/analytics/users/top-active | JWT |
| GET | /api/v1/analytics/dashboard | JWT |
| GET | /api/v1/analytics/reports/trend | JWT |
| GET | /api/v1/analytics/actions/trend | JWT |
| GET | /api/v1/analytics/reports/reasons | JWT |
| GET | /api/v1/analytics/reports/target-types | JWT |
| GET | /api/v1/analytics/messages/types | JWT |
| GET | /api/v1/analytics/conversations/types | JWT |
| POST | /api/v1/analytics/backfill | JWT |
| POST | /internal/events | INTERNAL_SERVICE authority |

---

## realtime-gateway REST Endpoint

| Method | Full Path | Auth |
| --- | --- | --- |
| GET | /health | Public |

## Evidence

- backend/node-services/apps/message-service/src/main.ts
- backend/node-services/apps/message-service/src/conversation/conversation.controller.ts
- backend/node-services/apps/message-service/src/message/message.controller.ts
- backend/node-services/apps/message-service/src/inbox/inbox.controller.ts
- backend/java-services/services/core-service/src/main/resources/application.yml
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/config/SecurityConfig.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/FcmTestController.java
- backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/config/SecurityConfig.java
- backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/controller/PostController.java
- backend/java-services/services/content-service/src/main/java/iuh/cnm/vnalo/content_service/controller/StoryController.java
- backend/java-services/services/media-service/src/main/java/iuh/cnm/vnalo/mediaservice/config/SecurityConfig.java
- backend/java-services/services/moderation-service/src/main/java/iuh/cnm/vnalo/moderation_service/config/SecurityConfig.java
- backend/java-services/services/notification-service/src/main/java/iuh/cnm/vnalo/notification_service/controller/NotificationController.java
- backend/java-services/services/ai-service/src/main/java/iuh/cnm/vnalo/aiservice/config/SecurityConfig.java
- backend/java-services/services/analytics-service/src/main/java/iuh/cnm/vnalo/analytics_service/config/SecurityConfig.java
