# Privacy and Data Collection Map

> This map describes production-safe categories for legal pages, analytics instrumentation, and admin monitoring.

## Essential Service Data

| Category | Examples | Purpose |
| --- | --- | --- |
| Account identity | user id, phone, display name | login, contacts, chat identity |
| Authentication state | session type, device id, token metadata | security and session management |
| Chat metadata | conversation id, membership, delivery state | messaging functionality |
| Call metadata | caller/callee ids, call type, timestamps | call setup and history |
| Media metadata | file id, mime category, size bucket | upload/download and moderation |

## Optional Product Improvement Data

| Category | Examples | Notes |
| --- | --- | --- |
| Sessions | start, heartbeat, end | metadata only |
| Screen views | route/screen id | no message content |
| Feature usage | feature id, success/failure | no raw payload |
| Client errors | status/reason code, surface | redact stack traces |
| AI lifecycle | provider status, command, reason code | no raw prompt by default |
| Face-auth lifecycle | enroll/verify success/failure/model unavailable | no biometric template |

## Sensitive Data Rules

- Face embeddings and liveness artifacts are biometric data and must not be sent to RAG, analytics, or third-party AI providers.
- Raw messages and prompts are private content and must not be used for product analytics without separate explicit policy and consent.
- Access tokens, secrets, API keys, and credentials must never be logged or exported.
- Admin UI should mask identifiers unless privileged drilldown is explicitly required.

## Consent and Legal Page Requirements

- Registration must link to Terms and Privacy pages before account creation.
- Face-auth enrollment must explain biometric data handling separately.
- Optional analytics consent should explain product improvement categories and withdrawal behavior.
- Legal pages must be updated whenever new event categories are added.
