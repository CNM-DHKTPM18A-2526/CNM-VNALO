# AI Agent Documentation

> Status: production hardening baseline. These documents define the contract for VNALO AI Assistant across web, mobile, AI service, and backend services.

## Purpose

VNALO AI Assistant is a guarded in-app assistant. It may answer VNALO-related questions, draft safe suggestions, and propose allow-listed actions. It must not mutate data by itself. Every action must pass resolver, policy, confirmation, executor, and audit gates.

## Source-of-Truth Order

1. Backend service validators and RBAC are the final enforcement layer.
2. Web/mobile action runtime validates early for UX and safety.
3. AI service prompt and parser may propose only allow-listed commands.
4. RAG documents explain product knowledge but never grant permission.
5. Human-facing docs describe expected behavior and must stay aligned with code.

## Document Map

| File | Owner | Purpose |
| --- | --- | --- |
| `business-rules.md` | Product + engineering | Business invariants shared by web/mobile/backend. |
| `action-contract.md` | AI + client teams | Command schema, risk, aliases, and response contract. |
| `runtime-policy.md` | Web/mobile/backend | Required execution flow and failure handling. |
| `precondition-matrix.md` | Feature owners | Per-action resolver and policy requirements. |
| `rag-knowledge-policy.md` | AI + privacy | What may be indexed/retrieved for assistant answers. |
| `safety-and-privacy.md` | Security + privacy | Consent, audit, sensitive data, and destructive-action rules. |
| `deployment-runbook.md` | Ops | EC2 verification and redeploy commands. |

## Implementation Baseline

- Web AI is embedded as the synthetic 1:1 conversation `vnalo-ai-assistant`.
- AI pseudo user id is `__vnalo_ai__`; clients must not call normal user APIs with this id.
- `/chat-ai` should redirect to `/chat/vnalo-ai-assistant`.
- `POST /api/v1/ai/chat` must set `analyzeIntent: true` when the client wants action proposals.
- Clients must treat `actionCommand` as a proposal, not an executable instruction.
- Unsupported, ambiguous, or unsafe actions must produce a clear assistant feedback message instead of pretending success.

## Required Next Code Shape

```text
frontend/web/src/features/ai-assistant/actions/
  actionSchemas.ts
  actionRegistry.ts
  actionParamExtractors.ts
  actionResolvers.ts
  actionPreconditions.ts
  actionExecutor.ts
  actionFeedback.ts
  actionAudit.ts
```

Mobile should keep its existing provider/action-plan pattern but align names, preconditions, and failure messages with these docs.
