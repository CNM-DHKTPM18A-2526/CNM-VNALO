package iuh.cnm.vnalo.messagingservice.model.entity.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationType;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.JoinMode;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversation")
@EntityListeners(AuditingEntityListener.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "conversation_id")
    private UUID conversationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 20)
    private ConversationType type;

    @Column(name = "title", length = 100)
    private String title;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    @Column(name = "description", length = 500)
    private String description;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private ConversationStatus status = ConversationStatus.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(name = "join_mode", length = 20)
    @Builder.Default
    private JoinMode joinMode = JoinMode.INVITE_ONLY;

    @Column(name = "member_limit")
    @Builder.Default
    private Integer memberLimit = 1000;

    @Column(name = "invite_link", length = 100, unique = true)
    private String inviteLink;

    @Column(name = "invite_link_expires_at")
    private Instant inviteLinkExpiresAt;

    @Column(name = "is_encrypted")
    @Builder.Default
    private Boolean isEncrypted = false;

    @Column(name = "allow_member_invite")
    @Builder.Default
    private Boolean allowMemberInvite = true;

    @Column(name = "allow_member_pin")
    @Builder.Default
    private Boolean allowMemberPin = false;

    @Column(name = "allow_member_edit_info")
    @Builder.Default
    private Boolean allowMemberEditInfo = false;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
