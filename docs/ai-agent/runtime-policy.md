# AI Assistant Runtime Policy

> Runtime policy defines how an AI action proposal becomes a user-visible result. It applies to web, mobile, and any future client.

## Required Pipeline

```text
user prompt
  -> AI chat request with analyzeIntent=true
  -> AI response with optional actionCommand/actionParams
  -> schema validation
  -> parameter extraction and normalization
  -> entity resolution
  -> precondition policy check
  -> confirmation UX if required
  -> executor API call or navigation
  -> success/failure assistant feedback
  -> audit event
```

## Layer Responsibilities

### AI Service

- Build answer with VNALO-scoped system prompt.
- Return only allow-listed canonical commands.
- Sanitize malformed or unsupported commands to `null`.
- Never include secrets, tokens, private prompt instructions, or hidden chain-of-thought.
- Treat `analyzeIntent=false` as normal chat with no action proposal.

### Web Runtime

- Keep synthetic AI conversation behavior isolated from normal conversation/user APIs.
- Validate `actionCommand` against `actionRegistry`.
- Resolve names against the current authenticated user's allowed graph.
- Reject missing, ambiguous, duplicate, pseudo, blocked, or unauthorized entities.
- Use modal/sheet confirmation for medium/high risk actions.
- Route to compose/create UI only after preconditions are satisfied.
- Append failure feedback to the AI chat timeline when blocked.

### Mobile Runtime

- Keep action plans aligned with web action contract.
- Use the same minimum member counts, permission assumptions, and risk labels.
- Prefer native bottom sheets/route flows for confirmation and execution.
- Do not allow mini-board or floating assistant UI to bypass policy gates.

### Backend Services

- Enforce final RBAC, membership, relationship, size, retention, and state constraints.
- Reject invalid group sizes, illegal membership changes, invalid recall windows, and unauthorized admin actions.
- Return typed errors that clients can translate into assistant feedback.

## Confirmation Rules

- Low-risk navigation may execute immediately after entity resolution.
- Medium-risk state changes require a clear confirmation modal/sheet.
- High-risk destructive actions require strong confirmation and explicit target details.
- Confirmation copy must include real resolved names, not raw text from AI.
- Confirmation must never include hidden or raw sensitive payloads.

## Audit Events

Each action attempt should emit metadata events when analytics is available:

| Event | Required metadata |
| --- | --- |
| `AI_ACTION_PROPOSED` | command, risk, surface, hasParams |
| `AI_ACTION_BLOCKED` | command, reasonCode, surface |
| `AI_ACTION_CONFIRMED` | command, risk, surface |
| `AI_ACTION_CANCELLED` | command, risk, surface |
| `AI_ACTION_EXECUTED` | command, executor, surface |
| `AI_ACTION_FAILED` | command, reasonCode, executor, surface |

Never include raw message content, raw prompt text, access tokens, face embeddings, or full private payloads in audit metadata.

## Error Handling

- Network/API failures must show a retry-safe message.
- Policy failures must explain what the user needs to provide or change.
- Unsupported commands must be treated as assistant limitations, not hidden errors.
- AI provider failure must not break the normal chat list or current conversation route.
