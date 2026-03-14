package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "sticker_pack", indexes = {
        @Index(name = "idx_sticker_pack_category", columnList = "category, download_count DESC"),
        @Index(name = "idx_sticker_pack_status", columnList = "status")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StickerPack {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "pack_id")
    private UUID packId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 500)
    private String description;

    @Column(name = "thumbnail_url", nullable = false, length = 500)
    private String thumbnailUrl;

    @Column(name = "banner_url", length = 500)
    private String bannerUrl;

    @Column(length = 100)
    private String author;

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private StickerPackCategory category;

    @Builder.Default
    @Column(name = "is_premium")
    private Boolean isPremium = false;

    @Builder.Default
    @Column(name = "is_animated")
    private Boolean isAnimated = false;

    @Builder.Default
    @Column(precision = 10, scale = 2)
    private BigDecimal price = BigDecimal.ZERO;

    @Builder.Default
    @Column(name = "download_count")
    private Integer downloadCount = 0;

    @Builder.Default
    @Column(name = "sticker_count")
    private Integer stickerCount = 0;

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private StickerPackStatus status = StickerPackStatus.ACTIVE;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
