# MODULE SPEC SOCIAL

> [!IMPORTANT]
> Module owner: core-service social domain and Flutter contacts layer.

## Outcomes

- Maintain stable friend, block, contact sync, and QR-assisted social onboarding flows.
- Enforce relationship constraints and privacy policy surfaces.
- Provide low-friction mobile contacts and friend request UX.

## Scope

### In Scope

- core-service endpoints under /friends, /blocks, /contacts, /qr, and user lookup paths.
- Entities: friendship, friend_request, block_list, contact_sync, user_profile, user_privacy_setting.
- Flutter FriendService and ContactProvider usage.

### Out of Scope

- Moderation action policy.
- Timeline social feed ranking.
- External recommendation algorithms.

## Constraints

- JWT auth required for all social endpoints.
- Relationship updates must preserve anti-self and duplicate-request checks.
- Block state must be considered before friend creation.
- Contact sync and phone search must align with privacy settings.

## Decisions

1. Keep friend_request and friendship as separate domain lifecycle tables.
2. Keep bidirectional block model in block_list.
3. Keep QR flow integrated with social add-friend operation.
4. Keep pending badge count surfaced through /friends/stats with fallback list count in mobile.

## Task Breakdown

| Task | Status | Notes |
| --- | --- | --- |
| Normalize mobile friend request APIs to core-service contracts | Done | FriendService maps paginated and field variants |
| Keep pending request badge in MainShell | Done | ContactProvider fetches and updates |
| Enforce privacy field allow_search_by_phone end-to-end | Open | migration and runtime mapping drift noted in feedback |
| Harden contact sync privacy policy checks | Open | gap documented in canonical feedback |
| Consolidate user phone lookup endpoint usage in mobile | Open | both /users/phone/{phone} and /users/search-by-phone used |

## Verification

### Functional

- Send, accept, decline, and cancel friend request flows complete without manual DB edits.
- Block and unblock flows update status endpoint correctly.
- contacts/sync and contacts/matched return deterministic outputs for known fixtures.
- QR scan add friend flow returns expected social action result.

### Contract

- Mobile service adapters can parse both list and page wrapper response forms.
- Social endpoint auth failures return consistent unauthorized or forbidden payloads.

### Data

- friendship uniqueness holds for user pair.
- block_list uniqueness holds for blocker and blocked pair.
- friend_request status transition path is one-way and timestamped.

## Evidence

- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/FriendController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/BlockController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/ContactSyncController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/controller/QrController.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/Friendship.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/FriendRequest.java
- backend/java-services/services/core-service/src/main/java/iuh/cnm/vnalo/core_service/model/entity/social/BlockList.java
- frontend/mobile/lib/services/friend_service.dart
- frontend/mobile/lib/features/contacts/providers/contact_provider.dart
