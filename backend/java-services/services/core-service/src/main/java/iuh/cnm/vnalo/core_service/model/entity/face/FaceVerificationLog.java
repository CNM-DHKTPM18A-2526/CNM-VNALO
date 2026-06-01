package iuh.cnm.vnalo.core_service.model.entity.face;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Entity representing a face verification audit log entry.
 * Records every verification attempt for security auditing.
 */
@Entity
@Table(name = "face_verification_logs", indexes = {
    @Index(name = "idx_face_verify_log_user", columnList = "user_id"),
    @Index(name = "idx_face_verify_log_created", columnList = "created_at"),
    @Index(name = "idx_face_verify_log_verified", columnList = "verified"),
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FaceVerificationLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "verified", nullable = false)
    private Boolean verified;

    @Column(name = "confidence", precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(name = "liveness_score", precision = 5, scale = 4)
    private BigDecimal livenessScore;

    @Column(name = "threshold", precision = 5, scale = 4)
    @Builder.Default
    private BigDecimal threshold = new BigDecimal("0.65");

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "device_id")
    private String deviceId;

    @Column(name = "app_version", length = 50)
    private String appVersion;

    @Column(name = "inference_time_ms")
    private Integer inferenceTimeMs;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
