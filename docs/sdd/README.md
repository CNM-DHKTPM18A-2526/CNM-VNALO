# VNALO SDD Digital Twin

> [!IMPORTANT]
> This directory is the canonical spec stack for VNALO.
> It is maintained with a SCAN -> DIFF -> REVISE loop against live code.

## Purpose

This SDD tree makes the repository AI-actionable and auditable:

- Layer 0 defines governing architecture and decisions.
- Layer 1 defines navigation and screen-level UI contracts.
- Layer 2 defines module behavior contracts.
- Layer 3 defines API, signaling, database, and error contracts.
- Layer 4 defines reconcile outcomes and release readiness criteria.

## Hierarchy

- layer-0
  - CLAUDE.md
  - DECISION_LOG.md
  - ARCHITECTURE_BLUEPRINT.md
- layer-1
  - NAVIGATION_MASTER_GRAPH.md
  - UI_DESIGN_SYSTEM.md
  - SCREEN_SPEC_AUTH_FLOW.md
  - SCREEN_SPEC_MAIN_SHELL.md
  - SCREEN_SPEC_CHAT_DETAIL.md
  - SCREEN_SPEC_VOICE_CALL.md
  - SCREEN_SPEC_VIDEO_CALL.md
- layer-2
  - MODULE_SPEC_CHAT.md       ← HARDENED 2026-04-29
  - MODULE_SPEC_CALL.md
  - MODULE_SPEC_SOCIAL.md
  - MODULE_SPEC_REALTIME_SYNC.md
  - MODULE_SPEC_WEB_APP.md
  - MODULE_SPEC_AI_ASSISTANT.md  ← HARDENED 2026-04-29
  - MODULE_SPEC_POLL.md         ← NEW 2026-04-29
  - MODULE_SPEC_MEDIA_PROXY.md  ← NEW 2026-04-29
- layer-3
  - API_REFERENCE_CATALOG.md
  - SOCKET_SIGNALING_SCHEMA.md
  - GLOBAL_DATABASE_ERD.md
  - ERROR_CODE_MATRIX.md
- layer-4
  - SYSTEM_RECONCILE_REPORT.md
  - DEFINITION_OF_DONE.md
  - REMEDIATION_BLUEPRINT.md  ← NEW 2026-04-29

## Reconcile Protocol

### 1) SCAN

Scan only from source-of-truth files:

- backend service controllers, gateways, entities, security configs
- frontend mobile navigation, providers, screens, socket integration
- docker runtime topology and environment contracts

### 2) DIFF

Compare specs against:

- code behavior
- existing docs in docs/system and docs/feedback

### 3) REVISE

- If code is correct and docs are stale, update docs.
- If docs are correct and code is wrong, open code correction tasks.
- Record every architectural decision change in layer-0/DECISION_LOG.md.

## Quality Bar

- Mermaid-first architecture and flow visuals.
- No placeholder sections.
- Atomic file scope.
- Explicit constraints and verification criteria per module.
