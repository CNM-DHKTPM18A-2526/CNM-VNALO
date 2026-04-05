package iuh.cnm.vnalo.moderation_service.model.entity;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationActionType;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "moderation_action")
@Getter @Setter @Builder
@NoArgsConstructor @AllArgsConstructor
public class ModerationAction {

    @Id
    @GeneratedValue
    @Column(name = "action_id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "case_id", nullable = false)
    private UUID caseId;

    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", nullable = false, length = 40)
    private ModerationActionType actionType;

    @Column(name = "target_user_id")
    private UUID targetUserId;

    @Column(name = "target_message_id")
    private UUID targetMessageId;

    @Column(name = "target_conversation_id")
    private UUID targetConversationId;

    @Column(name = "reason", length = 1000)
    private String reason;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}