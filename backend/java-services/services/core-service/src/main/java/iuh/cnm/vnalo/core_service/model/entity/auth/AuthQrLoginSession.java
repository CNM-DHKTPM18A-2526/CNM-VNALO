package iuh.cnm.vnalo.core_service.model.entity.auth;

import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "auth_qr_login_session", indexes = {
    @Index(name = "idx_qr_login_token", columnList = "qr_token", unique = true),
    @Index(name = "idx_qr_login_expires", columnList = "expires_at"),
    @Index(name = "idx_qr_login_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthQrLoginSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "session_id", nullable = false, updatable = false)
    private UUID sessionId;

    @Column(name = "qr_token", nullable = false, unique = true, length = 128)
    private String qrToken;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private QrLoginSessionStatus status;

    @Column(name = "web_device_name", length = 100)
    private String webDeviceName;

    @Column(name = "web_platform", length = 20)
    private String webPlatform;

    @Column(name = "web_ip_address", length = 45)
    private String webIpAddress;

    @Column(name = "web_user_agent")
    private String webUserAgent;

    @Column(name = "web_location", length = 255)
    private String webLocation;

    @Column(name = "mobile_device_id", length = 100)
    private String mobileDeviceId;

    @Column(name = "mobile_device_name", length = 100)
    private String mobileDeviceName;

    @Column(name = "mobile_platform", length = 20)
    private String mobilePlatform;

    @Column(name = "mobile_ip_address", length = 45)
    private String mobileIpAddress;

    @Column(name = "mobile_location", length = 255)
    private String mobileLocation;

    @Column(name = "approved_by_account_id")
    private UUID approvedByAccountId;

    @Column(name = "available_at", nullable = false)
    private Instant availableAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
