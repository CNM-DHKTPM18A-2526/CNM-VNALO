# AI Assistant Analytics Event Taxonomy

> Scope: assistant action lifecycle, behavioral monitoring metadata, and production-safe event payloads.

## Principles

- Track action lifecycle metadata, not raw private content.
- Derive `userId` from authenticated context on backend where possible.
- Do not include raw prompt, raw message content, access tokens, face embeddings, or uploaded media bytes.
- Keep payloads bounded and schema-versioned.
- Prefer stable enums over free-form text.

## Required Event Envelope

```json
{
  "eventType": "AI_ACTION_PROPOSED",
  "schemaVersion": "2026-06-02",
  "occurredAt": "ISO-8601",
  "surface": "web|mobile",
  "sessionId": "opaque-session-id",
  "deviceId": "opaque-device-id",
  "conversationType": "ai_assistant|direct|group|unknown",
  "metadata": {}
}
```

## Assistant Events

| Event | When | Required metadata | Forbidden metadata |
| --- | --- | --- | --- |
| `AI_PANEL_OPENED` | Assistant surface opened. | surface, entryPoint | prompt, messageContent |
| `AI_PROMPT_SENT` | Prompt submitted. | promptLength, hasAttachment, contextType | rawPrompt |
| `AI_RESPONSE_RECEIVED` | AI response rendered. | providerStatus, degraded, latencyMs, hasAction | rawResponse |
| `AI_RESPONSE_FAILED` | AI request failed. | statusCode, reasonCode, latencyMs | stack with secrets |
| `AI_IMAGE_ANALYSIS_USED` | User intentionally analyzes image. | imageCount, mimeCategory, sizeBucket | rawImage, faceEmbedding |
| `AI_ACTION_PROPOSED` | Model returns allow-listed command. | command, risk, requiresConfirmation | action raw hidden prompt |
| `AI_ACTION_BLOCKED` | Runtime blocks before confirmation/execution. | command, reasonCode, stage | rawPrompt, rawMessage |
| `AI_ACTION_CONFIRMED` | User confirms action. | command, risk | private payload |
| `AI_ACTION_CANCELLED` | User cancels action. | command, risk | cancellation free-text if sensitive |
| `AI_ACTION_EXECUTED` | Executor succeeds. | command, executor, latencyMs | raw API response |
| `AI_ACTION_FAILED` | Executor fails. | command, executor, reasonCode, statusCode | tokens, full request body |

## Reason Codes

| Code | Meaning |
| --- | --- |
| `missing_required_params` | AI did not provide enough structured data. |
| `entity_not_found` | Resolver found no eligible entity. |
| `entity_ambiguous` | Resolver found multiple eligible entities. |
| `precondition_failed` | Business rule blocked action. |
| `permission_denied` | User lacks required role/permission. |
| `confirmation_cancelled` | User did not confirm. |
| `backend_rejected` | Backend validator rejected the request. |
| `provider_unavailable` | AI provider failed before actionable result. |
| `unsupported_surface` | Current client cannot execute command safely. |

## Aggregates for Admin Monitoring

- AI prompt count by surface and hour.
- AI response success rate by provider status.
- AI action proposed/blocked/executed ratio by command.
- Top blocked commands by reason code.
- p50/p95 AI latency by surface.
- Image analysis usage count by day.
- No raw prompt/message drilldown without separate consent and policy.
