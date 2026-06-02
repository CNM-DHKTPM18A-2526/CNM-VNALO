# AI Assistant Safety and Privacy Policy

> Safety and privacy rules apply to assistant chat, action runtime, RAG, analytics, and admin monitoring.

## Sensitive Data Classes

| Data | Handling |
| --- | --- |
| Access tokens, refresh tokens, secrets | Never log, index, display, or send to AI providers. |
| Raw private messages and prompts | Do not send to analytics/RAG; use only in the active AI request when user intentionally invokes AI. |
| Face embeddings and biometric artifacts | Never send to RAG or third-party AI providers. Store/process only in face-auth services under explicit policy. |
| Images/media | Analyze only when user explicitly requests; do not persist derived sensitive details without policy. |
| Behavioral analytics | Store metadata only; mask identifiers in admin UI unless privileged drilldown is required. |
| Admin exports | Require permission, audit trail, and retention rules. |

## Consent Requirements

- Users must be informed about analytics and product-improvement data categories.
- Separate consent is required before collecting or using sensitive categories beyond essential service operation.
- Users should be able to review or withdraw optional analytics consent where implemented.
- Face-auth enrollment must be explicit and separate from password/QR login.

## Prompt and Tool Safety

- AI must not accept user instructions to bypass permissions, reveal secrets, or mutate data without confirmation.
- AI must not execute actions based on prompt-only claims such as "I am admin".
- AI must not perform destructive actions from a single ambiguous instruction.
- Tool/action parameters must be regenerated from resolved entities, not copied blindly from model output.

## Admin Monitoring Safety

- Admin dashboard navigation must be hidden for non-admin users.
- Backend must enforce admin permissions even if a user manually enters the URL.
- Aggregate dashboards should be the default; personally identifiable drilldown requires explicit permission.
- Exports must be auditable and rate-limited.

## Incident Handling

- If assistant returns unsafe action text, client should block execution and log `AI_ACTION_BLOCKED` with reason `unsafe_or_unsupported`.
- If RAG retrieves sensitive content, remove the source from index and rotate any exposed secrets.
- If analytics captures raw content by mistake, quarantine affected records and run retention/deletion jobs.
