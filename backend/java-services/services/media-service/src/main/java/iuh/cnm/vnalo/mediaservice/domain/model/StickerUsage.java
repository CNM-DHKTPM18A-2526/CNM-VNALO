package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "sticker_usage", indexes = {
        @Index(name = "idx_sticker_usage", columnList = "user_id, usage_count DESC")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@IdClass(StickerUsage.StickerUsageId.class)
public class StickerUsage {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Id
    @Column(name = "sticker_id")
    private UUID stickerId;

    @Builder.Default
    @Column(name = "usage_count")
    private Integer usageCount = 1;

    @Column(name = "last_used_at")
    private LocalDateTime lastUsedAt;

    @PrePersist
    @PreUpdate
    public void updateLastUsed() {
        this.lastUsedAt = LocalDateTime.now();
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StickerUsageId implements Serializable {
        private UUID userId;
        private UUID stickerId;
    }
}
