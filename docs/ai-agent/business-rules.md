# AI Assistant Business Rules

> These rules are product constraints. They are not optional prompt hints. They must be enforced by code before any mutating action is executed.

## Global Rules

- AI may propose actions only from the allow-listed action contract.
- AI must never claim an action was completed until the executor returns success.
- AI must not fabricate users, conversations, group membership, permissions, or delivery state.
- Entity names from natural language must resolve to exactly one real entity before execution.
- Ambiguous or missing entities must stop execution and ask the user to clarify.
- Destructive or privacy-sensitive actions require explicit confirmation.
- Web and mobile must present equivalent safety decisions even if the UI differs.
- Backend validators must reject invalid requests even when the client has already validated them.
- Pseudo/system identities such as `__vnalo_ai__` are UI/runtime constructs and must not be passed to normal user detail APIs.

## Conversation and Message Rules

- A direct conversation may be opened only with a real user the requester is allowed to contact.
- A group action requires the requester to be an active member of that group.
- Message actions require the message to belong to the active conversation.
- Recalled messages cannot be pinned, copied as normal content, or treated as active content for later AI actions.
- AI should not send raw private message content to RAG or analytics without a separate explicit consent rule.

## Group Creation Rules

- A group requires a non-empty name after trimming.
- A group requires at least two selected members besides the creator, so the initial group has at least three users.
- Each requested member must resolve to exactly one eligible real user.
- Members must not include the creator, duplicates, blocked users, or pseudo users.
- If a requested user is not in friends/contacts where the product requires that relation, AI must explain that the user cannot be added yet.
- The assistant may open a prefilled create-group modal only after minimum member count and resolution checks pass.

## Friend Request Rules

- A friend request target must resolve to exactly one real user.
- The target must not be the requester.
- The users must not already be friends.
- There must not be an existing pending outgoing request.
- If there is a pending incoming request, the assistant should guide the user to accept/reject instead of sending a duplicate.
- Blocked relationships must stop execution if the backend exposes that state.

## Calling Rules

- Calls require a direct real user target, not a group or pseudo user.
- The target must be callable under the product rules, normally a friend/contact relation.
- The requester cannot call themselves.
- The client must check active call state before starting a new call.
- Call type must be explicit and valid: `voice` or `video`.

## Group Administration Rules

- Adding members requires group membership and invite permission.
- Removing members requires role permission; normal members cannot remove others.
- A deputy cannot remove an owner or equal/higher privileged member.
- Ownership transfer requires the requester to be group owner and the target to be exactly one active member.
- The owner cannot leave a group while other active members remain unless ownership is transferred first.
- Disbanding a group is destructive and requires owner role plus strong confirmation.
- Renaming a group requires a non-empty title within the backend limit and the configured group edit permission.

## Admin Monitoring Rules

- Admin dashboard entry points must be visible only to accounts with admin monitoring permission.
- Normal users must not see or access admin dashboard navigation options.
- Admin exports must create an audit record with actor, time range, data category, and export format.
- Behavioral analytics UI must mask or aggregate identifiers unless a privileged drilldown is explicitly allowed.

## Face Authentication Rules

- Face-auth availability depends on feature flag, model readiness, and backend health.
- Login must fail closed when the model is unavailable and must show a service-unavailable UX instead of silently falling back without user consent.
- Face embeddings and liveness artifacts are sensitive biometric data and must not be sent to RAG.
- Enrollment, verification success, verification failure, and model-unavailable events may be tracked as metadata only.

## Analytics and Privacy Rules

- Behavioral analytics requires a clearly documented product-improvement purpose.
- Raw message content, raw AI prompts, images, face embeddings, access tokens, and secrets are excluded from analytics events.
- Session, screen, feature, error, AI outcome, and face-auth outcome events may be recorded as structured metadata.
- Users must be able to understand what categories of data are collected from legal/privacy pages.
