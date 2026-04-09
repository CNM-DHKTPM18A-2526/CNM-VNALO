package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Service for QR code-based user identification and friend adding.
 * Generates and validates QR tokens for secure friend requests.
 *
 * <p>Token format: SHA-256(userId + ":" + nonce + ":" + epochSecond + ":" + secret)
 * This embeds the expiry epoch in the hash so the token can be validated
 * stateless without server-side storage while still enforcing time bounds.
 */
@Service
@Slf4j
public class QrService {

    private final AuthAccountRepository authAccountRepository;
    private final UserProfileRepository userProfileRepository;
    private final FriendService friendService;

    /** Configurable secret injected from application.yml / env var. */
    private final String qrSecret;

    private static final int QR_TOKEN_VALIDITY_MINUTES = 5;
    /** Clock tolerance in seconds to absorb small clock skew between devices. */
    private static final int CLOCK_SKEW_TOLERANCE_SECONDS = 30;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    public QrService(
            AuthAccountRepository authAccountRepository,
            UserProfileRepository userProfileRepository,
            FriendService friendService,
            @Value("${qr.secret:changeme-set-QR_SECRET-env-var}") String qrSecret) {
        this.authAccountRepository = authAccountRepository;
        this.userProfileRepository = userProfileRepository;
        this.friendService = friendService;
        this.qrSecret = qrSecret;

        if ("changeme-set-QR_SECRET-env-var".equals(qrSecret)) {
            log.warn("QR secret is using the default placeholder value. " +
                     "Set the QR_SECRET environment variable (or qr.secret in application.yml) in production!");
        }
    }

    /**
     * Generate QR data for a user.
     * Returns a payload containing userId, a time-limited token and expiry.
     * The QR code image itself is rendered by the frontend/mobile app.
     */
    @Transactional(readOnly = true)
    public QrPayload generateQrPayload(UUID userId) {
        AuthAccount account = authAccountRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        UserProfile profile = userProfileRepository.findById(userId).orElse(null);

        Instant expiresAt = Instant.now().plus(QR_TOKEN_VALIDITY_MINUTES, ChronoUnit.MINUTES);
        String nonce = generateNonce();
        // Token encodes expiresAt epoch so validation can enforce time bounds
        String token = generateToken(userId, expiresAt, nonce);

        String displayName = profile != null ? profile.getDisplayName() : account.getPhone();

        return new QrPayload(userId, displayName, token, nonce, expiresAt);
    }

    /**
     * Validate a scanned QR payload.
     * Returns the scanned user's info if the QR is valid and not expired.
     */
    @Transactional(readOnly = true)
    public QrScanResult scanQr(UUID scannerId, UUID targetUserId, String token, String nonce) {
        // Can't scan yourself
        if (scannerId.equals(targetUserId)) {
            return new QrScanResult(false, null, null, "Cannot add yourself");
        }

        // Validate token across the valid time window.
        // We check the token against candidate expiry timestamps in 1-minute increments
        // within the validity window + clock skew tolerance.
        boolean tokenValid = false;
        Instant now = Instant.now();
        // Check all candidate expiresAt values in the validity window
        for (int minutesBack = 0; minutesBack <= QR_TOKEN_VALIDITY_MINUTES; minutesBack++) {
            Instant candidateExpiry = now.plus(QR_TOKEN_VALIDITY_MINUTES - minutesBack, ChronoUnit.MINUTES)
                    .truncatedTo(ChronoUnit.MINUTES); // align to minute boundaries
            String expected = generateToken(targetUserId, candidateExpiry, nonce);
            if (expected.equals(token)) {
                // Also check that candidateExpiry is in the future (with skew tolerance)
                if (candidateExpiry.isAfter(now.minusSeconds(CLOCK_SKEW_TOLERANCE_SECONDS))) {
                    tokenValid = true;
                }
                break;
            }
        }

        if (!tokenValid) {
            log.debug("QR token validation failed for target user {}", targetUserId);
            return new QrScanResult(false, null, null, "Invalid or expired QR code");
        }

        // Get target user info
        AuthAccount targetAccount = authAccountRepository.findById(targetUserId).orElse(null);
        if (targetAccount == null) {
            return new QrScanResult(false, null, null, "User not found");
        }

        UserProfile targetProfile = userProfileRepository.findById(targetUserId).orElse(null);
        String displayName = targetProfile != null ? targetProfile.getDisplayName() : targetAccount.getPhone();

        // Check if already friends
        boolean alreadyFriends = friendService.areFriends(scannerId, targetUserId);

        return new QrScanResult(true, targetUserId, displayName,
                alreadyFriends ? "Already friends" : "User found, ready to add friend");
    }

    // ─── Helpers ──────────────────────────────

    private String generateNonce() {
        byte[] bytes = new byte[16];
        SECURE_RANDOM.nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    /**
     * Generate a time-bound token: SHA-256(userId + ":" + nonce + ":" + expiresAtEpoch + ":" + secret).
     * Token encodes the expiry epoch so validation can enforce time bounds without server storage.
     */
    private String generateToken(UUID userId, Instant expiresAt, String nonce) {
        try {
            // Truncate to minutes so 1-min window checks work during scan validation
            long expiryEpoch = expiresAt.truncatedTo(ChronoUnit.MINUTES).getEpochSecond();
            String input = userId + ":" + nonce + ":" + expiryEpoch + ":" + qrSecret;
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash).substring(0, 32);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }

    /**
     * QR code payload to be encoded as JSON in the QR image.
     */
    public record QrPayload(
            UUID userId,
            String displayName,
            String token,
            String nonce,
            Instant expiresAt
    ) {}

    /**
     * Result of scanning a QR code.
     */
    public record QrScanResult(
            boolean valid,
            UUID userId,
            String displayName,
            String message
    ) {}
}
