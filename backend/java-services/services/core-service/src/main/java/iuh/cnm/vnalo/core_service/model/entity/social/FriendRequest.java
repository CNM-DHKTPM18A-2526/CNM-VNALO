package iuh.cnm.vnalo.core_service.model.entity.social;

import iuh.cnm.vnalo.core_service.model.enums.FriendRequestStatus;
import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "friend_request", indexes = {
    @Index(name = "idx_friend_request_to_user", columnList = "user_id_to, status"),
    @Index(name = "idx_friend_request_from_user", columnList = "user_id_from")
})
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FriendRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "request_id", updatable = false, nullable = false)
    private UUID requestId;

    @Column(name = "user_id_from", nullable = false)
    private UUID userIdFrom;

    @Column(name = "user_id_to", nullable = false)
    private UUID userIdTo;

    @Column(name = "message", length = 200)
    private String message;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 30)
    private FriendshipSource source;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private FriendRequestStatus status = FriendRequestStatus.PENDING;

    public void accept() {
        this.status = FriendRequestStatus.ACCEPTED;
        this.respondedAt = Instant.now();
    }

    public void decline() {
        this.status = FriendRequestStatus.DECLINED;
        this.respondedAt = Instant.now();
    }

    public void cancel() {
        this.status = FriendRequestStatus.CANCELED;
        this.respondedAt = Instant.now();
    }

    public boolean isPending() {
        return status == FriendRequestStatus.PENDING;
    }
}
