# AI Assistant RAG Knowledge Policy

> RAG helps the assistant answer VNALO questions. RAG must not become an authorization source or execution engine.

## Allowed Knowledge Sources

- Public product help and FAQ documents.
- Feature descriptions and safe usage guides.
- Business rules and action contract documents from `docs/ai-agent`.
- Privacy/legal summaries written for users.
- Troubleshooting runbooks with secrets removed.
- Admin monitoring concepts at aggregate level.

## Excluded Knowledge Sources

- `.env`, API keys, JWT secrets, private tokens, credentials, certificates.
- Raw private messages, raw AI prompts, files uploaded by users, and personal media.
- Face embeddings, liveness artifacts, biometric templates, or raw face images.
- Internal admin exports containing identifiable user activity.
- Database dumps and logs with PII unless explicitly redacted.
- Hidden chain-of-thought, prompt injection examples that include live secrets, or exploit payloads.

## Chunking Strategy

- Chunk by rule/action/topic, not by arbitrary character count when possible.
- Keep one action rule per chunk for precise retrieval.
- Include metadata: `docPath`, `section`, `versionDate`, `sensitivity`, `owner`, `lastReviewedAt`.
- Mark chunks as `public-help`, `developer-rule`, `ops-runbook`, or `privacy-policy`.
- Prefer smaller chunks for action preconditions and larger chunks for user help guides.

## Retrieval Policy

- RAG can answer how features work and what information is needed.
- RAG cannot decide that a user has permission; runtime/backend must check live state.
- RAG cannot override action contract, backend validation, legal policy, or user consent.
- If retrieved docs conflict with runtime/backend errors, the assistant must trust runtime/backend errors.

## Response Policy

- Use RAG to explain why an action is blocked in user-friendly language.
- Do not quote long internal docs to users.
- Do not reveal internal implementation details unless the route is an admin/developer surface.
- If knowledge is stale or missing, say the assistant cannot verify and avoid fabricated guidance.

## Versioning

- RAG indexes must include a docs version or commit hash.
- After changing `docs/ai-agent`, rebuild/reload the RAG index before relying on it in production.
- When an action contract changes, update docs, frontend runtime, mobile runtime, backend validators, and AI service prompt/parser in the same release train.
