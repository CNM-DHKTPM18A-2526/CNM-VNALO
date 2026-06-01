package iuh.cnm.vnalo.core_service.model.entity.auth;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "auth_legal_consent", indexes = {
        @Index(name = "idx_auth_legal_consent_account", columnList = "account_id,consent_type,granted_at"),
        @Index(name = "idx_auth_legal_consent_granted", columnList = "granted_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthLegalConsent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "consent_id", updatable = false, nullable = false)
    private UUID consentId;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(name = "consent_type", nullable = false, length = 40)
    private String consentType;

    @Column(name = "document_version", nullable = false, length = 32)
    private String documentVersion;

    @Column(name = "granted", nullable = false)
    private boolean granted;

    @Column(name = "granted_at", nullable = false)
    private Instant grantedAt;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "user_agent", length = 500)
    private String userAgent;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Column(name = "platform", length = 20)
    private String platform;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        final Instant now = Instant.now();
        if (this.grantedAt == null) {
            this.grantedAt = now;
        }
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}