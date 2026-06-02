# Documentation Audit and Remediation Plan

> Audit date: 2026-06-02. Scope: repository documentation, AI assistant rules, RAG readiness, privacy/admin/analytics references, deployment runbooks.

## Executive Summary

The repository has extensive documentation, but the AI assistant and operational docs were not yet organized as a single production contract. Several docs contain stale wording, mixed language, and mojibake. The highest-risk gap is that assistant business rules, action command schema, runtime policy, and RAG policy were spread across code, prompts, and feature-specific documents instead of one canonical docs set.

## Inventory Findings

| Area | Current state | Risk | Remediation |
| --- | --- | --- | --- |
| Root docs | `README.md`, `README.vi.md`, `CONTRIBUTING.md` exist. | Medium: overview can drift from service reality. | Keep as product overview, link to `docs/README.md`. |
| System docs | Architecture, API, DB, SDD layers exist. | Medium: some sections may lag behind recent AI/admin/analytics work. | Reconcile during feature-specific changes. |
| AI docs | `MODULE_SPEC_AI_ASSISTANT.md` exists. | High: action preconditions and RAG policy were incomplete as a runtime contract. | Added `docs/ai-agent/*` as canonical assistant contract. |
| Analytics docs | Many detailed analytics docs exist. | Medium: docs are broad but need linkage to assistant/admin privacy rules. | Link analytics from docs index and align event taxonomy in future code phase. |
| Deployment docs | Docker and EC2 docs exist. | Medium: AI-specific debug/redeploy commands were scattered in chats. | Added `docs/ai-agent/deployment-runbook.md`. |
| Mobile UI specs | Detailed screen specs exist. | Low/medium: may not reflect newest assistant mini-board and action policy. | Reconcile after mobile AI runtime update. |
| Privacy/legal/admin | Implemented scope exists in code/docs but not yet indexed as a unified compliance map. | High for production analytics/admin monitoring. | Add dedicated privacy/admin docs in next phase if missing after code audit. |
| Encoding quality | Some existing docs/source snippets show mojibake. | High for UX and docs reliability. | Fix touched docs as UTF-8; schedule targeted mojibake cleanup. |

## Canonical Documentation Structure

```text
docs/
  README.md
  ai-agent/
    README.md
    business-rules.md
    action-contract.md
    runtime-policy.md
    precondition-matrix.md
    rag-knowledge-policy.md
    safety-and-privacy.md
    deployment-runbook.md
  project/
    documentation-audit.md
  system/
  mobile/
  sdd/
```

## Code Alignment Gaps Found

- Web action handling is still concentrated in `frontend/web/src/pages/AiChatPage.tsx`; it should be extracted to an action runtime module.
- Web and mobile action preconditions need explicit parity checks, especially `CREATE_GROUP` minimum member count.
- Backend message-service group creation DTO should be checked against the product rule requiring creator plus at least two selected members.
- AI service prompt/parser allow-list should be reconciled with `docs/ai-agent/action-contract.md` whenever commands are added or removed.
- Admin dashboard visibility must be guarded by RBAC both in UI navigation and backend routes.

## Quality Gate for Future AI Agent Work

- Docs updated before or with code changes.
- Action exists in `action-contract.md` before client implementation.
- Preconditions exist in `precondition-matrix.md` before executor implementation.
- Backend validator exists for every mutating action.
- Web/mobile failure copy does not claim success before execution.
- RAG index excludes sensitive data classes.
- EC2 runbook includes exact health and smoke checks.

## Recommended Next Implementation Phases

1. Extract web action runtime from `AiChatPage.tsx` into `frontend/web/src/features/ai-assistant/actions`.
2. Align mobile branch `ai-mobile-assistant` action plans with the new precondition matrix.
3. Enforce backend group creation minimum selected-member rule if product confirms creator plus two selected members.
4. Add analytics event taxonomy docs for assistant action lifecycle.
5. Add privacy/legal docs for analytics consent, face-auth data, and admin monitoring exports.
6. Run a targeted mojibake cleanup pass for user-facing docs/source strings.
