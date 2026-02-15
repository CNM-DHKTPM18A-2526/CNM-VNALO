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
@Table(name = "conversation_inbox")
@IdClass(ConversationInbox.InboxId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationInbox {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Id
    @Column(name = "conversation_id")
    private UUID conversationId;

    @Column(name = "last_message_seq")
    @Builder.Default
    private Long lastMessageSeq = 0L;

    @Column(name = "last_message_at")
    private Instant lastMessageAt;

    @Column(name = "last_message_preview", length = 200)
    private String lastMessagePreview;

    @Column(name = "last_message_sender_id")
    private UUID lastMessageSenderId;

    @Column(name = "last_message_type", length = 30)
    private String lastMessageType;

    @Column(name = "unread_count")
    @Builder.Default
    private Integer unreadCount = 0;

    @Column(name = "is_pinned")
    @Builder.Default
    private Boolean isPinned = false;

    @Column(name = "is_muted")
    @Builder.Default
    private Boolean isMuted = false;

    @Column(name = "is_hidden")
    @Builder.Default
    private Boolean isHidden = false;

    @Column(name = "updated_at")
    @Builder.Default
    private Instant updatedAt = Instant.now();

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class InboxId implements Serializable {
        private UUID userId;
        private UUID conversationId;
    }
}
