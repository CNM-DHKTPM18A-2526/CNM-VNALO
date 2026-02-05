package iuh.cnm.vnalo.core_service.model.entity.auth;

import com.fasterxml.jackson.annotation.JsonIgnore;
import iuh.cnm.vnalo.core_service.model.entity.base.BaseEntity;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "auth_account", indexes = {
    @Index(name = "idx_auth_account_phone", columnList = "phone"),
    @Index(name = "idx_auth_account_status", columnList = "status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthAccount extends BaseEntity {

    @Column(name = "phone", unique = true, nullable = false, length = 20)
    private String phone;

    @Column(name = "firebase_uid", unique = true, length = 128)
    private String firebaseUid;

    @JsonIgnore
    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "password_updated_at")
    private Instant passwordUpdatedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private AccountStatus status = AccountStatus.PENDING_VERIFICATION;

    @Column(name = "locked_until")
    private Instant lockedUntil;

    @Column(name = "failed_login_count")
    @Builder.Default
    private Integer failedLoginCount = 0;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    @Column(name = "last_login_device_id", length = 100)
    private String lastLoginDeviceId;

    public boolean isLocked() {
        if (status == AccountStatus.LOCKED || status == AccountStatus.DISABLED) {
            return true;
        }
        // Check if temporary lock is still active
        if (lockedUntil != null && Instant.now().isBefore(lockedUntil)) {
            return true;
        }
        return false;
    }

    public boolean isActive() {
        return status == AccountStatus.ACTIVE && !isLocked();
    }

    public void onLoginSuccess() {
        this.lastLoginAt = Instant.now();
        this.failedLoginCount = 0;
    }

    public void onLoginSuccess(String deviceId) {
        this.lastLoginAt = Instant.now();
        this.lastLoginDeviceId = deviceId;
        this.failedLoginCount = 0;
    }

    public void onLoginFailed() {
        this.failedLoginCount = (failedLoginCount == null ? 0 : failedLoginCount) + 1;
    }

    public void lock(Instant until) {
        this.status = AccountStatus.LOCKED;
        this.lockedUntil = until;
    }
}
