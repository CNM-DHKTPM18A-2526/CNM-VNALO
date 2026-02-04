package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthRefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RefreshTokenRepository extends JpaRepository<AuthRefreshToken, UUID> {

    Optional<AuthRefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Query("UPDATE AuthRefreshToken t SET t.revokedAt = :revokedAt WHERE t.tokenHash = :tokenHash AND t.revokedAt IS NULL")
    void revokeByTokenHash(@Param("tokenHash") String tokenHash, @Param("revokedAt") Instant revokedAt);

    @Modifying
    @Query("UPDATE AuthRefreshToken t SET t.revokedAt = :revokedAt WHERE t.accountId = :accountId AND t.revokedAt IS NULL")
    void revokeAllByAccountId(@Param("accountId") UUID accountId, @Param("revokedAt") Instant revokedAt);

    @Modifying
    @Query("UPDATE AuthRefreshToken t SET t.revokedAt = :revokedAt WHERE t.accountId = :accountId AND t.deviceId = :deviceId AND t.revokedAt IS NULL")
    void revokeByAccountIdAndDeviceId(@Param("accountId") UUID accountId, @Param("deviceId") String deviceId, @Param("revokedAt") Instant revokedAt);
}
