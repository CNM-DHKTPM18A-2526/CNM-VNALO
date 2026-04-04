package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "media_variant", indexes = {
        @Index(name = "idx_media_variant", columnList = "media_id, variant_type")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MediaVariant {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "media_variant_id")
    private UUID mediaVariantId;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;

    @Column(name = "variant_type", nullable = false, length = 20)
    private String variantType;  // THUMBNAIL, COMPRESSED, PREVIEW, HD, SD

    @Column(name = "object_key", nullable = false, length = 500)
    private String objectKey;

    private Integer width;

    private Integer height;

    @Column(name = "size_bytes")
    private Long sizeBytes;

    @Builder.Default
    @Column(length = 20)
    private String status = "READY";  // PROCESSING, READY, FAILED

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
