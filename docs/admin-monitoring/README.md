# Admin Monitoring Documentation

> Admin monitoring must be useful for operations while remaining privacy-preserving and RBAC-gated.

## Entry and Access Rules

- Normal users must not see dashboard entry points in tabbars, sidebars, settings modals, or direct navigation menus.
- Admin users should access dashboard from the settings modal as an additional option beside settings and logout.
- Backend routes must enforce admin permissions even if the frontend hides navigation.
- Recommended permissions:
  - `ADMIN_MONITORING_VIEW`
  - `ADMIN_MONITORING_EXPORT`
  - `ADMIN_USER_BEHAVIOR_VIEW`
  - `ADMIN_AUDIT_VIEW`

## Dashboard Content

| Widget | Purpose | Privacy level |
| --- | --- | --- |
| DAU/WAU/MAU | Product health overview. | aggregate |
| Session duration p50/p95 | Engagement and performance signal. | aggregate |
| Screen views | UX/navigation monitoring. | aggregate |
| Top features | Product usage prioritization. | aggregate |
| Error rate | Reliability tracking. | aggregate |
| AI success rate | Assistant provider/runtime health. | aggregate |
| Face-auth success rate | Biometric login health. | aggregate |
| Export history | Compliance audit. | admin audit |

## User Behavior Data Categories

Allowed metadata categories:

- session start/end/heartbeat timestamps
- screen route names
- feature identifiers
- API error status/reason code
- AI action lifecycle events
- face-auth lifecycle metadata
- platform, app version, coarse device category

Excluded raw data categories:

- raw private messages
- raw AI prompts unless separate consent and policy exist
- access tokens and secrets
- face embeddings, liveness frames, biometric templates
- raw uploaded images/files

## Export Rules

- Export requires `ADMIN_MONITORING_EXPORT`.
- Export action must create an audit record with actor, filters, timestamp, and format.
- Exports should default to aggregate data.
- Identifier-level exports require stronger permission and masking by default.
