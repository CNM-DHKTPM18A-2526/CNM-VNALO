package iuh.cnm.vnalo.messagingservice.model.entity.conversation;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversation_direct_map")
@IdClass(ConversationDirectMap.DirectMapId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationDirectMap {

    @Id
    @Column(name = "user_id_1")
    private UUID userId1;

    @Id
    @Column(name = "user_id_2")
    private UUID userId2;

    @Column(name = "conversation_id", nullable = false)
    private UUID conversationId;

    @Column(name = "created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DirectMapId implements Serializable {
        private UUID userId1;
        private UUID userId2;
    }
}
