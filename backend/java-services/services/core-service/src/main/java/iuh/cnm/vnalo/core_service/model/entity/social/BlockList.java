package iuh.cnm.vnalo.core_service.model.entity.social;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "block_list", indexes = {
    @Index(name = "idx_block_list_blocker", columnList = "blocker_id"),
    @Index(name = "idx_block_list_blocked", columnList = "blocked_id")
}, uniqueConstraints = {
    @UniqueConstraint(name = "uk_block_list", columnNames = {"blocker_id", "blocked_id"})
})
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BlockList {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "block_id", updatable = false, nullable = false)
    private UUID blockId;

    @Column(name = "blocker_id", nullable = false)
    private UUID blockerId;

    @Column(name = "blocked_id", nullable = false)
    private UUID blockedId;

    @Column(name = "block_messages")
    @Builder.Default
    private Boolean blockMessages = true;

    @Column(name = "block_calls")
    @Builder.Default
    private Boolean blockCalls = true;

    @Column(name = "block_and_hide_logs")
    @Builder.Default
    private Boolean blockAndHideLogs = false;

    @Column(name = "reason", length = 30)
    private String reason;

    @Column(name = "note", length = 200)
    private String note;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public static BlockList create(UUID blockerId, UUID blockedId) {
        return BlockList.builder()
                .blockerId(blockerId)
                .blockedId(blockedId)
                .build();
    }
}
