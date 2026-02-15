package iuh.cnm.vnalo.messagingservice.model.entity.call;

import iuh.cnm.vnalo.messagingservice.model.enums.call.CallEndReason;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "call_session")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CallSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "call_id")
    private UUID callId;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "call_type", nullable = false, length = 20)
    private CallType callType;

    @Column(name = "initiator_id", nullable = false)
    private UUID initiatorId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private CallStatus status = CallStatus.RINGING;

    @Column(name = "started_at")
    @Builder.Default
    private Instant startedAt = Instant.now();

    @Column(name = "connected_at")
    private Instant connectedAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    @Enumerated(EnumType.STRING)
    @Column(name = "end_reason", length = 30)
    private CallEndReason endReason;
}
