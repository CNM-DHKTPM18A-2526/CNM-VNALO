package iuh.cnm.vnalo.core_service.model.entity.auth;

import iuh.cnm.vnalo.core_service.model.entity.base.BaseEntity;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "auth_account", indexes = {
    @Index(name = "idx_auth_account_phone", columnList = "phone")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthAccount extends BaseEntity {

    @Column(name = "phone", unique = true, nullable = false, length = 20)
    private String phone;

    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "password_updated_at")
    private Instant passwordUpdatedAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    @Builder.Default
    private AccountStatus status = AccountStatus.PENDING_VERIFICATION;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    public boolean isLocked() {
        return status == AccountStatus.LOCKED || status == AccountStatus.DISABLED;
    }

    public boolean isActive() {
        return status == AccountStatus.ACTIVE;
    }

    public void onLoginSuccess() {
        this.lastLoginAt = Instant.now();
    }
}
