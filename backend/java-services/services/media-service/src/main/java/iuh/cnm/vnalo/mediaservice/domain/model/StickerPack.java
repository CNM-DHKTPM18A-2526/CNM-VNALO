package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "sticker_pack", indexes = {
        @Index(name = "idx_sticker_pack_owner", columnList = "owner_user_id"),
        @Index(name = "idx_sticker_pack_status", columnList = "status"),
        @Index(name = "idx_sticker_pack_popular", columnList = "download_count DESC")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StickerPack {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "sticker_pack_id")
    private UUID stickerPackId;

    @Column(name = "owner_user_id")
    private UUID ownerUserId;  // NULL for official packs

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 500)
    private String description;

    @Column(name = "cover_media_id", nullable = false)
    private UUID coverMediaId;  // FK → media_metadata

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private StickerPackStatus status = StickerPackStatus.DRAFT;

    @Builder.Default
    @Column(name = "sticker_count")
    private Integer stickerCount = 0;

    @Builder.Default
    @Column(name = "download_count")
    private Integer downloadCount = 0;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
