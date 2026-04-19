# DEFINITION OF DONE

> [!IMPORTANT]
> This DoD defines when VNALO is considered release-ready from a spec, runtime, and governance perspective.

## Done Criteria Overview

A change set is Done only when all five gates pass:

1. Spec Gate
2. Contract Gate
3. Verification Gate
4. Security and Risk Gate
5. Reconcile Gate

## Gate 1: Spec Gate

| Check | Pass Condition |
|---|---|
| Layer completeness | All required files in Layer 0 to Layer 4 exist and are updated for impacted scope. |
| Atomic scope | Each updated document has single clear responsibility and no placeholder sections. |
| Decision traceability | Any architecture-affecting change has a `DECISION_LOG` entry with evidence. |
| Diagram parity | Architecture, data, or flow changes are reflected in mermaid diagrams. |

## Gate 2: Contract Gate

| Check | Pass Condition |
|---|---|
| API contract parity | Endpoint method/path/auth/response are aligned with implementation. |
| Socket contract parity | Event names and payload requirements are aligned with active gateway code. |
| Data contract parity | Entity/table changes are represented in global ERD and ownership notes. |
| Error contract parity | Added or modified error paths are mapped in error matrix. |

## Gate 3: Verification Gate

| Check | Pass Condition |
|---|---|
| Build viability | Affected services compile/start without new blocking errors. |
| Functional checks | Core user flows impacted by the change have explicit verification evidence. |
| Regression safety | Existing critical flows (auth, chat, call, moderation) remain operational. |
| Observability | Logs and error outputs remain diagnosable with stable codes/messages. |

## Gate 4: Security and Risk Gate

| Check | Pass Condition |
|---|---|
| Auth boundary review | Changes crossing trust boundaries include explicit authn/authz assessment. |
| Sensitive paths | Any exception to security best practice is documented with owner and timeframe. |
| Data access constraints | Access scope and ownership constraints are preserved. |
| Abuse controls | Rate limits, spam constraints, and moderation interactions are not regressed. |

## Gate 5: Reconcile Gate

| Check | Pass Condition |
|---|---|
| SCAN evidence | Source files used to justify updates are referenced in layer docs. |
| DIFF visibility | Gaps or drift are documented in `SYSTEM_RECONCILE_REPORT.md`. |
| REVISE closure | Each identified drift is either corrected or tracked as accepted debt with owner. |
| Zero-delta target | No known untracked mismatch between code and SDD for the changed scope. |

## Required Evidence Bundle

Every completed work package must include:

- Updated SDD files for impacted layers.
- File-level evidence paths for changed runtime contracts.
- Verification notes for tests or manual checks executed.
- Risk entries for any accepted non-ideal behavior.

## Release Blockers

A release is blocked if any of the following is true:

- Critical endpoint or socket contract changed without Layer 3 update.
- Security-sensitive behavior changed without risk review entry.
- Data model changed without ERD and migration impact update.
- Error behavior changed without matrix update and client impact review.
- High-severity DIFF finding has no owner or target remediation window.

## Acceptance Checklist

| Item | Status |
|---|---|
| Layer 0 governance and decisions current | Required |
| Layer 1 UX and navigation contracts current for impacted screens | Required |
| Layer 2 module contracts current | Required |
| Layer 3 integration/data/error contracts current | Required |
| Layer 4 reconcile and readiness updated | Required |
| Verification evidence attached | Required |
| Open risks assigned with timeline | Required |

## This Cycle Status

For cycle `SDD-RECONCILE-2026-04-19`:

- Gate 1: Passed
- Gate 2: Passed for documented runtime scope
- Gate 3: Documentation-level pass; runtime execution evidence remains repository-dependent
- Gate 4: Passed with accepted risks documented
- Gate 5: Passed

> [!NOTE]
> Runtime hardening debts remain tracked, especially notification identity trust and restricted web mode policy enforcement.
