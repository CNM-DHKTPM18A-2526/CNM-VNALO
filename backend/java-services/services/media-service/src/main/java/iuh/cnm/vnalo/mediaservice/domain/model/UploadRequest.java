package iuh.cnm.vnalo.mediaservice.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "upload_request", indexes = {
        @Index(name = "idx_upload_user", columnList = "owner_user_id, created_at DESC"),
        @Index(name = "idx_upload_status", columnList = "status, expires_at")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UploadRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "upload_request_id")
    private UUID uploadRequestId;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(name = "file_name", nullable = false, length = 255)
    private String fileName;

    @Column(name = "mime_type", nullable = false, length = 100)
    private String mimeType;

    @Column(name = "expected_size_bytes", nullable = false)
    private Long expectedSizeBytes;

    @Column(name = "presigned_url", nullable = false, columnDefinition = "TEXT")
    private String presignedUrl;

    @Column(name = "object_key", nullable = false, length = 500)
    private String objectKey;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "source_type", length = 30)
    private String sourceType;  // CHAT, STORY, TIMELINE, AVATAR, STICKER

    @Column(name = "source_id")
    private UUID sourceId;

    @Builder.Default
    @Column(length = 20)
    private String status = "ISSUED";  // ISSUED, CONFIRMED, EXPIRED, CANCELLED

    @Column(name = "confirmed_media_id")
    private UUID confirmedMediaId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
