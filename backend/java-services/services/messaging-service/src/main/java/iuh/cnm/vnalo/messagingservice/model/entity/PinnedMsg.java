package iuh.cnm.vnalo.messagingservice.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "pinned_message",
        uniqueConstraints = @UniqueConstraint(columnNames = {"conversation_id", "message_id"}))
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PinnedMsg {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "pin_id")
    private UUID pinId;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Column(name = "message_id", nullable = false)
    private UUID messageId;

    @Column(name = "server_seq", nullable = false)
    private Long serverSeq;

    @Column(name = "pinned_by", nullable = false)
    private UUID pinnedBy;

    @Column(name = "pinned_at")
    @Builder.Default
    private Instant pinnedAt = Instant.now();
}
