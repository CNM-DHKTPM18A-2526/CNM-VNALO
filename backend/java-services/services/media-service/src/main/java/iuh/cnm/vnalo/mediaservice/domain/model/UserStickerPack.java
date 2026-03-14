package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "user_sticker_pack", indexes = {
        @Index(name = "idx_user_sticker", columnList = "user_id, order_index")
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
    @Column(name = "downloaded_at", updatable = false)
    private LocalDateTime downloadedAt;

    @Column(name = "order_index")
    private Integer orderIndex;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UserStickerPackId implements Serializable {
        private UUID userId;
        private UUID packId;
    }
}
