package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "media_metadata", indexes = {
        @Index(name = "idx_media_owner", columnList = "owner_user_id, created_at DESC"),
        @Index(name = "idx_media_status", columnList = "status"),
        @Index(name = "idx_media_category", columnList = "media_category, created_at DESC")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MediaMetadata {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "media_id")
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Enumerated(EnumType.STRING)
    @Column(name = "media_category", nullable = false, length = 30)
    private MediaCategory category;

    @Column(name = "mime_type", nullable = false, length = 100)
    private String mimeType;

    @Column(name = "original_filename", length = 255)
    private String originalFilename;

    // S3 Storage
    @Column(nullable = false, length = 50)
    private String bucket;

    @Column(name = "object_key", nullable = false, length = 500)
    private String objectKey;

    @Column(length = 20)
    @Builder.Default
    private String region = "ap-southeast-1";

    // CDN URLs (derived after processing)
    @Column(name = "url", length = 500)
    private String url;

    @Column(name = "thumbnail_url", length = 500)
    private String thumbnailUrl;

    // Metadata
    @Column(name = "size_bytes", nullable = false)
    private Long sizeBytes;

    @Column(name = "checksum_sha256", length = 64)
    private String checksumSha256;

    private Integer width;

    private Integer height;

    @Column(name = "duration_ms")
    private Integer durationMs;

    @Builder.Default
    @Column(name = "needs_processing")
    private Boolean needsProcessing = true;

    // Lifecycle
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    @Builder.Default
    private MediaStatus status = MediaStatus.PENDING_UPLOAD;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
