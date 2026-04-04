package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_sticker_pack", indexes = {
        @Index(name = "idx_user_sticker_pack", columnList = "user_id, pinned_order")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@IdClass(UserStickerPack.UserStickerPackId.class)
public class UserStickerPack {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Id
    @Column(name = "pack_id")
    private UUID packId;

    @CreationTimestamp
    @Column(name = "installed_at", updatable = false)
    private LocalDateTime installedAt;

    @Column(name = "pinned_order")
    private Integer pinnedOrder;  // NULL if not pinned

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UserStickerPackId implements Serializable {
        private UUID userId;
        private UUID packId;
    }
}
