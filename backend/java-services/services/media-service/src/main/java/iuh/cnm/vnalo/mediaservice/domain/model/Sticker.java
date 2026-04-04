package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "sticker", indexes = {
        @Index(name = "idx_sticker_pack", columnList = "pack_id, display_order"),
        @Index(name = "idx_sticker_status", columnList = "status")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Sticker {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "sticker_id")
    private UUID stickerId;

    @Column(name = "pack_id", nullable = false)
    private UUID packId;

    @Column(length = 50)
    private String name;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;  // FK → media_metadata

    @Builder.Default
    @Column(name = "is_animated")
    private Boolean isAnimated = false;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private StickerStatus status = StickerStatus.ACTIVE;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
