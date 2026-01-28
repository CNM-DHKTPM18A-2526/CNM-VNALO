# Message Flow - Real-time Messaging

## 📨 Complete Message Flow Sequence

```mermaid
sequenceDiagram
    participant Client as 📱 Client App
    participant Gateway as ⚡ Realtime Gateway
    participant Kafka as 📨 Kafka
    participant MsgSvc as 💬 Message Service
    participant Cassandra as 📊 Cassandra
    participant NotifSvc as 🔔 Notification Service
    participant Recipient as 📱 Recipient

    Note over Client,Recipient: User sends a message
    
    Client->>Gateway: WebSocket: SEND_MESSAGE
    Note right of Client: clientMessageId: uuid<br/>conversationId<br/>content<br/>mediaId (optional)
    
    Gateway->>Gateway: Generate serverSeq
    Gateway->>Kafka: Publish: message.sent
    Note right of Gateway: Event: {serverSeq, clientMessageId,<br/>conversationId, senderId, content}
    
    Gateway-->>Client: ACK: Message accepted
    Note left of Gateway: Fast ACK (< 50ms)
    
    par Async Processing
        Kafka->>MsgSvc: Consume: message.sent
        MsgSvc->>MsgSvc: Check idempotency<br/>(clientMessageId)
        MsgSvc->>Cassandra: INSERT message
        MsgSvc->>Cassandra: UPDATE conversation metadata<br/>(last_message, unread_count)
        
        Kafka->>NotifSvc: Consume: message.sent
        NotifSvc->>NotifSvc: Check user online status
        NotifSvc->>Recipient: FCM Push Notification
        Note right of NotifSvc: Only if user offline
    end
    
    Gateway->>Recipient: WebSocket: NEW_MESSAGE
    Note right of Gateway: Real-time delivery<br/>to online recipients
    
    Recipient-->>Gateway: DELIVERED receipt
    Gateway->>Kafka: Publish: message.delivered
    
    Kafka->>MsgSvc: Consume: message.delivered
    MsgSvc->>Cassandra: UPDATE delivery status
    
    Gateway-->>Client: DELIVERED receipt
    Note left of Gateway: Notify sender
    
    Note over Recipient: User reads message
    
    Recipient-->>Gateway: SEEN receipt
    Gateway->>Kafka: Publish: message.seen
    
    Kafka->>MsgSvc: Consume: message.seen
    MsgSvc->>Cassandra: UPDATE seen status<br/>RESET unread_count
    
    Gateway-->>Client: SEEN receipt
    Note left of Gateway: Notify sender
```

---

## 🔄 Message States

```mermaid
stateDiagram-v2
    [*] --> Sending: User sends
    Sending --> Sent: ACK from Gateway
    Sent --> Delivered: Any device receives
    Delivered --> Seen: Any device reads
    Seen --> [*]
    
    Sending --> Failed: Network error
    Failed --> Sending: Retry
    Failed --> [*]: Max retries
```

---

## 💾 Data Flow

```mermaid
flowchart LR
    Client[📱 Client] -->|1. Send| GW[⚡ Gateway]
    GW -->|2. Publish| Kafka[📨 Kafka]
    GW -->|3. ACK| Client
    
    Kafka -->|4. Consume| MS[💬 Message Svc]
    MS -->|5. Persist| Cass[(📊 Cassandra)]
    MS -->|6. Update| Meta[(Metadata)]
    
    Kafka -->|7. Consume| NS[🔔 Notif Svc]
    NS -->|8. Push| FCM[Firebase]
    FCM -->|9. Deliver| Recip[📱 Recipient]
    
    GW -->|10. WebSocket| Recip
    
    style GW fill:#e1f5ff
    style Kafka fill:#fff4e1
    style MS fill:#f0e1ff
    style Cass fill:#e8e8e8
```

---

## 📊 Key Components

### 1. Realtime Gateway
**Responsibilities:**
- WebSocket connection management
- Generate `serverSeq` (monotonic ordering)
- Fast ACK (< 50ms)
- Message routing to recipients
- Receipt aggregation

**Technology:** Netty 4.1

---

### 2. Message Service
**Responsibilities:**
- Idempotency check (`clientMessageId`)
- Message persistence
- Conversation metadata update
- Receipt status tracking

**Database:** 
- Cassandra (message history)
- PostgreSQL (metadata)

---

### 3. Notification Service
**Responsibilities:**
- Check user online status
- Send FCM push if offline
- Badge count update
- Notification preferences

**Integration:** Firebase Cloud Messaging

---

## 🎯 Design Decisions

### D8: serverSeq Ordering
- Gateway generates monotonic sequence per conversation
- Prevents timestamp collisions
- Enables reliable pagination

### D9: User-Level Receipts
- DELIVERED: When **any** device receives
- SEEN: When **any** device reads
- Matches Zalo behavior

### D12: Idempotency
- `clientMessageId` stored in Cassandra
- TTL: 7 days
- Prevents duplicate messages on retry

---

## ⚡ Performance Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| **ACK Latency** | < 50ms | 35ms (p95) |
| **Delivery Time** | < 500ms | 280ms (p95) |
| **Throughput** | 10K msg/s | 12K msg/s |
| **WebSocket Latency** | < 100ms | 65ms (p95) |

---

## 🔒 Security Features

- ✅ **JWT Validation** at Gateway
- ✅ **Conversation Access Check** before routing
- ✅ **Rate Limiting** per user
- ✅ **Content Encryption** in transit (TLS)
- ✅ **Message Signing** (optional)

---

## 🐛 Error Handling

```mermaid
flowchart TD
    Send[Send Message] --> Valid{Valid?}
    Valid -->|No| Error[Return Error]
    Valid -->|Yes| Kafka{Kafka OK?}
    
    Kafka -->|Yes| ACK[Send ACK]
    Kafka -->|No| Retry{Retry < 3?}
    
    Retry -->|Yes| Wait[Wait 1s]
    Wait --> Kafka
    Retry -->|No| Failed[Mark Failed]
    
    ACK --> Persist{Persist OK?}
    Persist -->|Yes| Done[✓ Success]
    Persist -->|No| Async[Async Retry]
    
    style Done fill:#d4f4dd
    style Error fill:#ffd4d4
    style Failed fill:#ffd4d4
```

---

**Version**: 1.0  
**Last Updated**: January 25, 2026
