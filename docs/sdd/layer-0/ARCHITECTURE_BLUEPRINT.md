# ARCHITECTURE BLUEPRINT

> [!IMPORTANT]
> This blueprint reflects repository runtime behavior at the time of SDD generation.

## System Topology

```mermaid
flowchart TB
    Mobile[Flutter Mobile App]
    Web[Web Frontend]

    subgraph Node
      Msg[message-service\nNestJS\n:3000\n/api/v1 + /chat]
      RT[realtime-gateway\nNestJS\n:8085\n/realtime]
    end

    subgraph Java
      Core[core-service\nSpring Boot\n:8081\n/api/v1]
      Media[media-service\nSpring Boot\n:8083\n/api/v1/media + /api/v1/stickers]
      Mod[moderation-service\nSpring Boot\n:8082\n/api/v1\ndisabled by default compose]
      Content[content-service\nSpring Boot\n:8086\n/api/v1]
      Notif[notification-service\nSpring Boot\n:8087\n/api/v1]
      AI[ai-service\nSpring Boot\n:8094\n/api/v1]
      Ana[analytics-service\nSpring Boot\n:8084\nprofile planned]
    end

    PG[(PostgreSQL)]
    Redis[(Redis)]
    Kafka[(Kafka)]
    Rabbit[(RabbitMQ)]

    Mobile --> Core
    Mobile --> Msg
    Mobile --> Media
    Mobile --> AI
    Mobile --> Msg
    Mobile -. WS /chat .-> Msg
    Mobile -. WS /realtime optional .-> RT

    Msg --> PG
    Core --> PG
    Media --> PG
    Mod --> PG
    Content --> PG
    Notif --> PG
    Ana --> PG

    Msg --> Redis
    Core --> Redis
    Media --> Redis
    RT --> Redis
    AI --> Redis

    Kafka --> Notif
    Media --> Rabbit
    RT --> Rabbit
```

## Runtime Service Contract Matrix

| Service | Port | Entry Contract | Primary Responsibility | Runtime Status |
| --- | --- | --- | --- | --- |
| core-service | 8081 | /api/v1 | Auth, users, social graph, QR auth | Active |
| message-service | 3000 | /api/v1 and WS namespace /chat | Conversations, messages, inbox, call signaling | Active |
| realtime-gateway | 8085 | WS namespace /realtime | Presence and typing federation | Active but secondary for mobile |
| media-service | 8083 | /api/v1/media and /api/v1/stickers | Media upload, sticker pack APIs | Active |
| moderation-service | 8082 | /api/v1 | Reports, cases, actions, appeals | Implemented, disabled in default compose |
| content-service | 8086 | /api/v1 | Stories, posts, comments, likes | Active; security config permitAll with controller header trust |
| notification-service | 8087 | /api/v1 | Device registration and user notifications | Active; controller trusts X-User-Id header |
| ai-service | 8094 | /api/v1/ai and /api/v1/chat | Assistant chat and history | Active |
| analytics-service | 8084 | /api/v1/analytics and /internal/events | Trend dashboards and event ingestion | Implemented, optional compose profile planned |

## Trust and Auth Boundaries

```mermaid
flowchart LR
    TokenIssuer[core-service token issuer]
    JWTClients[Mobile and web clients]
    JWTValidators[message-service + realtime-gateway + Java JWT filters]
    WeakHeaderNotif[notification-service X-User-Id header path]
    WeakHeaderContent[content-service X-User-Id header path plus permitAll]

    TokenIssuer --> JWTClients
    JWTClients --> JWTValidators
    JWTClients --> WeakHeaderNotif
    JWTClients --> WeakHeaderContent
```

> [!WARNING]
> notification-service and content-service currently rely on controller-level X-User-Id headers for mutating actions, and content-service security config permits all requests.

## Canonical End-to-End Flows

### Login and Chat Start

```mermaid
sequenceDiagram
    participant U as Mobile User
    participant Core as core-service
    participant Msg as message-service
    participant WS as chat namespace /chat

    U->>Core: POST /api/v1/auth/login
    Core-->>U: access + refresh tokens
    U->>Msg: GET /api/v1/inbox (Bearer)
    U->>WS: connect with auth.token
    WS-->>U: presence.changed online
    U->>WS: conversation.join
    WS-->>U: conversation.joined
```

### 1:1 Call Signaling

```mermaid
sequenceDiagram
    participant A as Caller Mobile
    participant GW as message-service chat.gateway
    participant B as Callee Mobile
    participant R as Redis

    A->>GW: call.offer {conversationId, callId, targetUserId, sdp}
    alt callee online
      GW-->>B: call.offer
    else callee offline
      GW->>R: publish CALL_OFFLINE
    end
    B->>GW: call.answer
    GW-->>A: call.answer
    A->>GW: call.ice-candidate
    GW-->>B: call.ice-candidate
    A->>GW: call.end
    GW-->>B: call.end
```

## Data Ownership

- core-service owns account and social canonical identity.
- message-service owns conversation and message canonical state.
- media-service owns media metadata and sticker catalogs.
- moderation-service owns moderation case lifecycle.
- analytics-service owns aggregate read models and event history.
- notification-service owns per-user notification feed and device token registrations.

## Constraints

- Shared JWT secret must remain synchronized across token issuer and validators.
- message-service and core-service currently share vnalo_core persistence domain.
- media-service uses dedicated vnalo_media DB and must integrate via API or events.
- moderation-service is implemented but commented out in default docker-compose runtime.
- analytics-service runs only when compose profile planned is selected.
- Socket event names are part of client contract and must be versioned for breaking changes.
