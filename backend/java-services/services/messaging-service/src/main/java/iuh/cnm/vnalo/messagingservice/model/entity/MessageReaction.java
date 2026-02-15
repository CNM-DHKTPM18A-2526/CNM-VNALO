package iuh.cnm.vnalo.messagingservice.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "message_reaction",
        uniqueConstraints = @UniqueConstraint(columnNames = {"message_id", "user_id"}))
@EntityListeners(AuditingEntityListener.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MessageReaction {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "reaction_id")
    private UUID reactionId;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Column(name = "message_id", nullable = false)
    private UUID messageId;

    @Column(name = "server_seq", nullable = false)
    private Long serverSeq;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "emoji", nullable = false, length = 20)
    private String emoji;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
