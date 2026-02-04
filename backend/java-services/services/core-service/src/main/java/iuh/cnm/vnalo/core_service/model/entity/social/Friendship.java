package iuh.cnm.vnalo.core_service.model.entity.social;

import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "friendship", indexes = {
    @Index(name = "idx_friendship_user_from", columnList = "user_id_from"),
    @Index(name = "idx_friendship_user_to", columnList = "user_id_to")
}, uniqueConstraints = {
    @UniqueConstraint(name = "uk_friendship_users", columnNames = {"user_id_from", "user_id_to"})
})
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Friendship {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "friendship_id", updatable = false, nullable = false)
    private UUID friendshipId;

    @Column(name = "user_id_from", nullable = false)
    private UUID userIdFrom;

    @Column(name = "user_id_to", nullable = false)
    private UUID userIdTo;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 30)
    private FriendshipSource source;

    @Column(name = "nickname_from", length = 50)
    private String nicknameFrom;

    @Column(name = "nickname_to", length = 50)
    private String nicknameTo;

    @Column(name = "is_favorite_from")
    @Builder.Default
    private Boolean isFavoriteFrom = false;

    @Column(name = "is_favorite_to")
    @Builder.Default
    private Boolean isFavoriteTo = false;

    @Column(name = "is_hidden_from")
    @Builder.Default
    private Boolean isHiddenFrom = false;

    @Column(name = "is_hidden_to")
    @Builder.Default
    private Boolean isHiddenTo = false;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static Friendship create(UUID userA, UUID userB, FriendshipSource source) {
        return Friendship.builder()
                .userIdFrom(userA)
                .userIdTo(userB)
                .source(source)
                .build();
    }

    public boolean containsUser(UUID userId) {
        return userIdFrom.equals(userId) || userIdTo.equals(userId);
    }

    public UUID getFriendId(UUID currentUserId) {
        if (userIdFrom.equals(currentUserId)) {
            return userIdTo;
        } else if (userIdTo.equals(currentUserId)) {
            return userIdFrom;
        }
        throw new IllegalArgumentException("User is not part of this friendship");
    }

    public String getNicknameForFriend(UUID currentUserId) {
        if (userIdFrom.equals(currentUserId)) {
            return nicknameFrom;
        } else if (userIdTo.equals(currentUserId)) {
            return nicknameTo;
        }
        return null;
    }

    public void setNicknameForFriend(UUID currentUserId, String nickname) {
        if (userIdFrom.equals(currentUserId)) {
            this.nicknameFrom = nickname;
        } else if (userIdTo.equals(currentUserId)) {
            this.nicknameTo = nickname;
        }
    }
}
