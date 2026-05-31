package iuh.cnm.vnalo.core_service.model.entity.face;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Entity representing a user's face enrollment.
 * Stores the encrypted face embedding for later verification.
 */
@Entity
@Table(name = "face_enrollments", indexes = {
    @Index(name = "idx_face_enrollment_user", columnList = "user_id"),
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FaceEnrollment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /**
     * AES-256-GCM encrypted 512-D face embedding vector, stored as Base64 string.
     * The encrypted blob includes IV (12 bytes) + GCM tag + ciphertext.
     */
    @Column(name = "embedding_data", columnDefinition = "text", nullable = false)
    private String embeddingData;

    @Column(name = "enrolled_at", nullable = false)
    @Builder.Default
    private Instant enrolledAt = Instant.now();

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "version", nullable = false)
    @Builder.Default
    private Integer version = 1;

    @Column(name = "liveness_score", precision = 5, scale = 4)
    private BigDecimal livenessScore;

    @Column(name = "quality_score", precision = 5, scale = 4)
    private BigDecimal qualityScore;

    /**
     * JSON metadata about the device used during enrollment.
     * Contains: os_version, app_version, device_model, etc.
     */
    @Column(name = "device_info", columnDefinition = "jsonb")
    private String deviceInfo;

    @Column(name = "terms_version", length = 50)
    private String termsVersion;

    @Column(name = "consent_agreed", nullable = false)
    @Builder.Default
    private Boolean consentAgreed = false;
}
