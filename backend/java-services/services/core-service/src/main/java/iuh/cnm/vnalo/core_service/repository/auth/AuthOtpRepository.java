package iuh.cnm.vnalo.core_service.repository.auth;

import iuh.cnm.vnalo.core_service.model.entity.auth.AuthOtp;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository for AuthOtp entity.
 */
@Repository
public interface AuthOtpRepository extends JpaRepository<AuthOtp, UUID> {

    /**
     * Find the latest valid (not verified, not expired) OTP for a target and purpose.
     */
    @Query("SELECT o FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose " +
           "AND o.verifiedAt IS NULL AND o.expiresAt > :now ORDER BY o.createdAt DESC LIMIT 1")
    Optional<AuthOtp> findLatestValid(@Param("target") String target,
                                       @Param("purpose") OtpPurpose purpose,
                                       @Param("now") Instant now);

    /**
     * Find any pending (unverified) OTP for a target and purpose.
     */
    Optional<AuthOtp> findByTargetAndPurposeAndVerifiedAtIsNull(String target, OtpPurpose purpose);

    /**
     * Check if there's a valid OTP for the target and purpose.
     */
    @Query("SELECT COUNT(o) > 0 FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose " +
           "AND o.verifiedAt IS NULL AND o.expiresAt > :now")
    boolean existsValidOtp(@Param("target") String target,
                           @Param("purpose") OtpPurpose purpose,
                           @Param("now") Instant now);

    /**
     * Count recent OTP requests for rate limiting.
     */
    @Query("SELECT COUNT(o) FROM AuthOtp o WHERE o.target = :target AND o.createdAt > :since")
    long countRecentRequests(@Param("target") String target, @Param("since") Instant since);

    /**
     * Count recent OTP requests for rate limiting by target and purpose.
     */
    @Query("SELECT COUNT(o) FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose AND o.createdAt > :since")
    long countRecentRequests(@Param("target") String target,
                              @Param("purpose") OtpPurpose purpose,
                              @Param("since") Instant since);

    /**
     * Find the latest OTP for a target and purpose (regardless of verification status).
     */
    @Query("SELECT o FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose ORDER BY o.createdAt DESC LIMIT 1")
    Optional<AuthOtp> findLatestOtp(@Param("target") String target, @Param("purpose") OtpPurpose purpose);

    /**
     * Find the latest valid (not verified, not expired) OTP.
     */
    @Query("SELECT o FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose " +
           "AND o.verifiedAt IS NULL AND o.expiresAt > :now ORDER BY o.createdAt DESC LIMIT 1")
    Optional<AuthOtp> findLatestValidOtp(@Param("target") String target,
                                          @Param("purpose") OtpPurpose purpose,
                                          @Param("now") Instant now);

    /**
     * Check if there's a verified OTP for the target and purpose.
     */
    @Query("SELECT COUNT(o) > 0 FROM AuthOtp o WHERE o.target = :target AND o.purpose = :purpose AND o.verifiedAt IS NOT NULL")
    boolean existsVerifiedOtp(@Param("target") String target, @Param("purpose") OtpPurpose purpose);
}
