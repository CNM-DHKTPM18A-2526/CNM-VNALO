package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthRefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
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

    List<AuthRefreshToken> findByAccountIdOrderByCreatedAtDesc(UUID accountId, Pageable pageable);

    List<AuthRefreshToken> findByAccountIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtAsc(UUID accountId, Instant now);

        boolean existsByAccountIdAndDeviceId(UUID accountId, String deviceId);

        @Query("""
                SELECT CASE WHEN COUNT(t) > 0 THEN true ELSE false END
                FROM AuthRefreshToken t
                WHERE t.accountId = :accountId
                    AND t.revokedAt IS NULL
                    AND t.expiresAt > :now
                    AND UPPER(COALESCE(t.platform, 'WEB')) IN ('ANDROID','IOS')
                """)
        boolean hasActiveTrustedMobileSession(@Param("accountId") UUID accountId, @Param("now") Instant now);
}
