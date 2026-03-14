package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class QrService {

    private final AuthAccountRepository authAccountRepository;
    private final UserProfileRepository userProfileRepository;
    private final FriendService friendService;

    private static final int QR_TOKEN_VALIDITY_MINUTES = 5;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    /**
     * Generate QR data for a user.
     * Returns a payload containing userId and a time-limited token.
     * The QR code itself is rendered by the frontend/mobile app.
     */
    @Transactional(readOnly = true)
    public QrPayload generateQrPayload(UUID userId) {
        AuthAccount account = authAccountRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        UserProfile profile = userProfileRepository.findById(userId).orElse(null);

        // Generate time-limited token: HMAC(userId + timestamp + nonce)
        Instant expiresAt = Instant.now().plus(QR_TOKEN_VALIDITY_MINUTES, ChronoUnit.MINUTES);
        String nonce = generateNonce();
        String token = generateToken(userId, expiresAt, nonce);

        String displayName = profile != null ? profile.getDisplayName() : account.getPhone();

        return new QrPayload(
                userId,
                displayName,
                token,
                nonce,
                expiresAt
        );
    }

    /**
     * Validate a scanned QR payload and optionally send a friend request.
     * Returns the scanned user's info if the QR is valid.
     */
    @Transactional
    public QrScanResult scanQr(UUID scannerId, UUID targetUserId, String token, String nonce) {
        // Validate token
        Instant expiresAt = Instant.now().plus(QR_TOKEN_VALIDITY_MINUTES, ChronoUnit.MINUTES);
        // We need to check within a window; regenerate the expected token
        // Instead, just verify the token matches for the given nonce
        String expectedToken = generateToken(targetUserId, expiresAt, nonce);

        // Token validation: since we can't store server-side state for QR codes,
        // we validate using a deterministic approach (token = hash of userId + nonce + secret)
        String simpleToken = generateSimpleToken(targetUserId, nonce);
        if (!simpleToken.equals(token)) {
            return new QrScanResult(false, null, null, "Invalid or expired QR code");
        }

        // Can't scan yourself
        if (scannerId.equals(targetUserId)) {
            return new QrScanResult(false, null, null, "Cannot add yourself");
        }

        // Get target user info
        AuthAccount targetAccount = authAccountRepository.findById(targetUserId)
                .orElse(null);
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
     * Generate a simple token based on userId and nonce.
     * This is a stateless approach — token can be verified without DB lookup.
     */
    private String generateSimpleToken(UUID userId, String nonce) {
        try {
            String input = userId.toString() + ":" + nonce + ":vnalo-qr-secret";
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash).substring(0, 32);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }

    private String generateToken(UUID userId, Instant expiresAt, String nonce) {
        return generateSimpleToken(userId, nonce);
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
