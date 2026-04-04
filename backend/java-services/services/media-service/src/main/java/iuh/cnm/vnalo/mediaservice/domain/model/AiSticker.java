package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ai_sticker", indexes = {
        @Index(name = "idx_ai_sticker_user", columnList = "user_id, created_at DESC")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AiSticker {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "ai_sticker_id")
    private UUID aiStickerId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String prompt;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;  // FK → media_metadata

    @Builder.Default
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private AiStickerStatus status = AiStickerStatus.GENERATING;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
