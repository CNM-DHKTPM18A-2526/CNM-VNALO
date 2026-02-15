package iuh.cnm.vnalo.messagingservice.model.entity.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.MemberRole;
import iuh.cnm.vnalo.messagingservice.model.enums.notification.NotificationSetting;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversation_member")
@IdClass(ConversationMember.ConversationMemberId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationMember {

    @Id
    @Column(name = "conversation_id")
    private UUID conversationId;

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", length = 20)
    @Builder.Default
    private MemberRole role = MemberRole.MEMBER;

    @Column(name = "nickname", length = 50)
    private String nickname;

    @Column(name = "joined_at")
    @Builder.Default
    private Instant joinedAt = Instant.now();

    @Column(name = "joined_by")
    private UUID joinedBy;

    @Column(name = "left_at")
    private Instant leftAt;

    @Column(name = "removed_by")
    private UUID removedBy;

    @Column(name = "mute_until")
    private Instant muteUntil;

    @Column(name = "is_pinned")
    @Builder.Default
    private Boolean isPinned = false;

    @Column(name = "pin_order")
    private Integer pinOrder;

    @Column(name = "is_hidden")
    @Builder.Default
    private Boolean isHidden = false;

    @Column(name = "last_read_seq")
    @Builder.Default
    private Long lastReadSeq = 0L;

    @Column(name = "last_read_at")
    private Instant lastReadAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "notification_setting", length = 20)
    @Builder.Default
    private NotificationSetting notificationSetting = NotificationSetting.ALL;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ConversationMemberId implements Serializable {
        private UUID conversationId;
        private UUID userId;
    }
}
