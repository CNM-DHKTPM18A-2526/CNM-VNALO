# AI Assistant Precondition Matrix

> This matrix is the checklist for web/mobile runtime and backend validator alignment.

| Action | Entity resolution | Preconditions | Confirmation | Failure behavior |
| --- | --- | --- | --- | --- |
| `OPEN_PROFILE` | Resolve one real user. | Not pseudo user; viewer can access profile. | Usually no. | Ask to clarify or report unavailable profile. |
| `COMPOSE_MESSAGE` | Resolve one direct user or conversation. | Non-empty draft; requester can send; group post policy allows sending. | Yes before send; optional if only opening draft. | Open draft only or explain missing target/content. |
| `START_CALL` | Resolve one direct real user. | Not self; target callable; no active call; `callType` valid. | Yes. | Explain missing friend/contact, active call, or invalid target. |
| `SEND_FRIEND_REQUEST` | Resolve one real user. | Not self; not friends; no duplicate pending request; not blocked. | Yes. | Explain exact relationship blocker. |
| `CREATE_GROUP` | Resolve all member names/ids to eligible users. | `groupName` non-empty; at least two selected members besides creator; no duplicates/self/pseudo/blocked. | Yes. | Ask for more members, clarify ambiguous names, or report ineligible users. |
| `CHANGE_GROUP_NAME` | Resolve target group. | Active member; permitted by role/settings; title non-empty and under limit. | Yes. | Explain missing permission or invalid title. |
| `ADD_GROUP_MEMBER` | Resolve target group and new users. | Requester active member; invite permission; users not already active; within group limit. | Yes. | Explain permission or membership blocker. |
| `REMOVE_GROUP_MEMBER` | Resolve target group and member. | Requester has role permission; target active; cannot remove equal/higher role illegally. | Yes. | Explain role constraint. |
| `TRANSFER_GROUP_OWNER` | Resolve target group and target member. | Requester is owner; target active; target not self. | Strong yes. | Explain ownership requirement. |
| `LEAVE_GROUP` | Resolve target group. | Requester active; owner must transfer ownership first if others remain. | Yes. | Explain owner transfer requirement. |
| `DISBAND_GROUP` | Resolve target group. | Requester is owner; group active. | Strong yes. | Explain ownership requirement. |
| `RECALL_MESSAGE` | Resolve message in current conversation. | Own message or privileged role; not already recalled; inside recall window. | Yes. | Explain not found, expired, already recalled, or permission denied. |
| `PIN_MESSAGE` | Resolve message in conversation. | Message not recalled; pin policy allows requester; pin limit not exceeded. | Yes. | Explain permission or pin limit. |
| `UNPIN_MESSAGE` | Resolve pinned message. | Message currently pinned; requester can unpin. | Yes. | Explain state or permission mismatch. |
| `MUTE_CONVERSATION` | Resolve conversation. | Requester is participant/member; not already muted if no-op should be avoided. | Optional. | Explain unavailable conversation. |
| `UNMUTE_CONVERSATION` | Resolve conversation. | Requester is participant/member; currently muted if no-op should be avoided. | Optional. | Explain unavailable conversation. |
| `BLOCK_USER` | Resolve one real user. | Not self; relation can be blocked; legal/privacy copy shown if needed. | Yes. | Explain invalid target. |
| `UNBLOCK_USER` | Resolve one real user. | Target is currently blocked. | Yes. | Explain no-op or invalid target. |

## Resolver Requirements

- Match by stable id when present.
- If only a display name is present, search allowed user/contact graph.
- Return `none`, `single`, or `ambiguous`; never silently pick the first result.
- Normalize case, whitespace, accents, and duplicate names for display only; retain canonical ids for execution.
- Do not resolve pseudo ids such as `__vnalo_ai__` through normal user APIs.

## Backend Alignment Requirements

- Group create DTO must enforce at least two member ids if the product rule remains creator plus two selected users.
- Message service must enforce group role and membership constraints independent of client runtime.
- Core/contact service must enforce friend request deduplication and self-request blocking.
- AI service should keep the allow-list in sync with this matrix.
