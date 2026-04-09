package iuh.cnm.vnalo.core_service.model.entity.auth;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "auth_session_audit", indexes = {
        @Index(name = "idx_auth_session_audit_account", columnList = "account_id,created_at"),
        @Index(name = "idx_auth_session_audit_event", columnList = "event_type,created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthSessionAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "audit_id", updatable = false, nullable = false)
    private UUID auditId;

    @Column(name = "account_id", nullable = false)
    private UUID accountId;

    @Column(name = "token_id")
    private UUID tokenId;

    @Column(name = "event_type", nullable = false, length = 80)
    private String eventType;

    @Column(name = "session_type", length = 40)
    private String sessionType;

    @Column(name = "trust_level", length = 40)
    private String trustLevel;

    @Column(name = "platform", length = 20)
    private String platform;

    @Column(name = "device_id", length = 100)
    private String deviceId;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "detail", length = 500)
    private String detail;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
