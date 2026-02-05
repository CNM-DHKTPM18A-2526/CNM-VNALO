package iuh.cnm.vnalo.core_service.model.entity.auth;

import com.fasterxml.jackson.annotation.JsonIgnore;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * Entity for storing OTP (One-Time Password) verification codes.
 * Used for phone/email verification, password reset, and 2FA.
 */
@Entity
@Table(name = "auth_otp", indexes = {
    @Index(name = "idx_otp_target_purpose", columnList = "target, purpose")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthOtp {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "otp_id", updatable = false, nullable = false)
    private UUID otpId;

    /**
     * Target identifier (phone number or email) that receives the OTP.
     */
    @Column(name = "target", nullable = false, length = 100)
    private String target;

    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 30)
    private OtpPurpose purpose;

    @JsonIgnore
    @Column(name = "otp_hash", nullable = false, length = 255)
    private String otpHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "attempts")
    @Builder.Default
    private Integer attempts = 0;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }

    /**
     * Check if OTP is still valid (not verified and not expired).
     */
    public boolean isValid() {
        return verifiedAt == null && Instant.now().isBefore(expiresAt);
    }

    /**
     * Check if maximum verification attempts have been exceeded.
     */
    public boolean isMaxAttemptsExceeded(int maxAttempts) {
        return attempts != null && attempts >= maxAttempts;
    }

    /**
     * Increment the attempt counter.
     */
    public void incrementAttempts() {
        this.attempts = (this.attempts == null ? 0 : this.attempts) + 1;
    }

    /**
     * Mark OTP as verified.
     */
    public void markAsVerified() {
        this.verifiedAt = Instant.now();
    }
}
