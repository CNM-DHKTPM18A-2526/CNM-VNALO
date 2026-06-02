# VNALO Documentation

> Runtime-reconciled documentation index for VNALO. Use this page before changing product rules, service contracts, deployment flows, or AI assistant behavior.

## Product and Project

| Document | Description |
| --- | --- |
| [Project Status](project/status.md) | Current implementation status by service and frontend track. |
| [Changelog](project/changelog.md) | Version history and reconcile notes. |
| [Team Assignment](project/team-assignment.md) | Ownership and delivery responsibilities. |
| [Documentation Audit](project/documentation-audit.md) | Current documentation health, gaps, and remediation plan. |

## Architecture and System References

| Document | Description |
| --- | --- |
| [Architecture](system/architecture.md) | Service map, ports, trust boundaries, routing, JWT contract, and security perimeter. |
| [Database Schema](system/database-schema.md) | PostgreSQL-first schema documentation with reconcile notes. |
| [API Reference](system/api-reference.md) | REST endpoints and Socket.IO events. |
| [SDD Index](sdd/README.md) | Layered software design documents. |

## AI Agent and RAG

| Document | Description |
| --- | --- |
| [AI Agent Overview](ai-agent/README.md) | Scope, source-of-truth map, and implementation order for the VNALO assistant. |
| [Business Rules](ai-agent/business-rules.md) | Business constraints the assistant must respect before proposing or executing actions. |
| [Action Contract](ai-agent/action-contract.md) | Typed command schema, aliases, risk levels, confirmations, and execution targets. |
| [Runtime Policy](ai-agent/runtime-policy.md) | Intent-to-execution flow for web, mobile, AI service, and backend validators. |
| [Precondition Matrix](ai-agent/precondition-matrix.md) | Action-by-action validation matrix for resolver, policy, confirmation, and executor layers. |
| [RAG Knowledge Policy](ai-agent/rag-knowledge-policy.md) | What can be indexed, chunked, retrieved, or excluded from assistant RAG. |
| [Safety and Privacy](ai-agent/safety-and-privacy.md) | Sensitive-data, consent, audit, and destructive-action guardrails. |
| [Analytics Event Taxonomy](ai-agent/analytics-event-taxonomy.md) | Production-safe assistant analytics event schema and aggregates. |

## Operations and Deployment

| Document | Description |
| --- | --- |
| [Docker Deploy](../docker/README-deploy.md) | Docker deployment reference. |
| [EC2 Setup](deploy/EC2_SETUP.md) | EC2 provisioning and operating notes. |
| [AI Agent Deployment Runbook](ai-agent/deployment-runbook.md) | EC2 checks and redeploy commands specific to AI assistant/runtime changes. |

## Domain Documentation

| Directory | Description |
| --- | --- |
| [Mobile UI Specs](mobile/ui_spec/README.md) | Mobile screen-level UX/UI specifications. |
| [Analytics](system/analytics/README.md) | Analytics service architecture, API, operations, quality gates, and rollout plans. |
| [Moderation](system/moderation/01-service-overview.md) | Moderation service domain documentation. |
| [Performance Reviews](system/performance) | Endpoint performance reviews and integration fix summaries. |
| [Admin Monitoring](admin-monitoring/README.md) | RBAC, dashboard widgets, export rules, and privacy boundaries. |
| [Privacy Data Map](privacy/data-collection-map.md) | Data collection categories, consent, and sensitive-data exclusions. |

## Root References

| File | Description |
| --- | --- |
| [README.md](../README.md) | Project overview in English. |
| [README.vi.md](../README.vi.md) | Project overview in Vietnamese. |
| [contributing.md](contributing.md) | Development conventions and contribution standards. |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Repository-level contribution guide. |
