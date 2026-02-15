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
@Table(name = "group_banned_member")
@IdClass(GroupBannedMember.BannedMemberId.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GroupBannedMember {

    @Id
    @Column(name = "conversation_id")
    private UUID conversationId;

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "banned_by", nullable = false)
    private UUID bannedBy;

    @Column(name = "reason", length = 200)
    private String reason;

    @Column(name = "banned_at")
    @Builder.Default
    private Instant bannedAt = Instant.now();

    @Column(name = "expires_at")
    private Instant expiresAt;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class BannedMemberId implements Serializable {
        private UUID conversationId;
        private UUID userId;
    }
}
