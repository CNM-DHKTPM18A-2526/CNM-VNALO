package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthQrLoginSession;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthRefreshToken;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.entity.user.UserSetting;
import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthQrLoginSessionRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserSettingRepository;
import iuh.cnm.vnalo.core_service.security.JwtTokenProvider;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class QrLoginService {

    private static final Duration SESSION_TTL = Duration.ofSeconds(60);
    private static final Duration APPROVAL_COOLDOWN = Duration.ofSeconds(5);
    private static final int MAX_ACTIVE_UNTRUSTED_WEB_DEVICES = 1;

    private final AuthQrLoginSessionRepository qrSessionRepository;
    private final AuthAccountRepository authAccountRepository;
    private final UserProfileRepository userProfileRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserSettingRepository userSettingRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final SessionAuditService sessionAuditService;

    @Transactional
    public SessionCreateResponse createSession(HttpServletRequest request, SessionCreateRequest input) {
        final Instant now = Instant.now();
        final Instant expiresAt = now.plus(SESSION_TTL);
        final String token = randomToken();

        final AuthQrLoginSession session = AuthQrLoginSession.builder()
                .qrToken(token)
                .status(QrLoginSessionStatus.PENDING)
                .webDeviceName(trimToNull(input.deviceName()))
                .webPlatform(normalizePlatform(input.platform(), "WEB"))
                .webIpAddress(resolveClientIp(request))
                .webUserAgent(trimToNull(request.getHeader("User-Agent")))
                .webLocation(trimToNull(input.location()))
                .availableAt(now.plus(APPROVAL_COOLDOWN))
                .expiresAt(expiresAt)
                .build();
        qrSessionRepository.save(session);

        final String qrPayload = "{\"type\":\"VNALO_WEB_LOGIN\",\"token\":\"" + token + "\",\"exp\":\"" + expiresAt + "\"}";
        return new SessionCreateResponse(token, expiresAt, SESSION_TTL.toSeconds(), qrPayload);
    }

    @Transactional
    public SessionPollResponse pollSession(String token, HttpServletRequest request) {
        final AuthQrLoginSession session = findSession(token);
        markExpiredIfNeeded(session);

        if (session.getStatus() == QrLoginSessionStatus.APPROVED && session.getConsumedAt() == null) {
            final UUID accountId = Optional.ofNullable(session.getApprovedByAccountId())
                    .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
            final AuthResponse auth = buildAuthResponseForWeb(accountId, session, request);
            session.setStatus(QrLoginSessionStatus.CONSUMED);
            session.setConsumedAt(Instant.now());
            sessionAuditService.record(
                accountId,
                null,
                "QR_SESSION_CONSUMED",
                "QR_WEB",
                "UNTRUSTED",
                "QR session consumed and auth delivered to web"
            );

            final LoginNotice notice = buildLoginNotice(session);
            return new SessionPollResponse(
                    session.getStatus(),
                    session.getExpiresAt(),
                    secondsRemaining(session.getExpiresAt()),
                    cooldownRemaining(session.getAvailableAt()),
                    session.getWebDeviceName(),
                    session.getWebIpAddress(),
                    session.getWebLocation(),
                    auth,
                    notice
            );
        }

        return new SessionPollResponse(
                session.getStatus(),
                session.getExpiresAt(),
                secondsRemaining(session.getExpiresAt()),
                cooldownRemaining(session.getAvailableAt()),
                session.getWebDeviceName(),
                session.getWebIpAddress(),
                session.getWebLocation(),
                null,
                null
        );
    }

    @Transactional
    public SessionApproveResponse approveSession(String token, UUID approverId, HttpServletRequest request, SessionApproveRequest input) {
        final AuthQrLoginSession session = findSession(token);
        markExpiredIfNeeded(session);

        if (session.getStatus() == QrLoginSessionStatus.CONSUMED) {
            throw new ApiException(ErrorCode.AUTH_QR_SESSION_ALREADY_USED);
        }
        if (session.getStatus() == QrLoginSessionStatus.EXPIRED) {
            throw new ApiException(ErrorCode.AUTH_QR_SESSION_EXPIRED);
        }
        if (session.getStatus() != QrLoginSessionStatus.PENDING) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "QR session cannot be approved in current state");
        }

        final Instant now = Instant.now();
        if (session.getAvailableAt() != null && now.isBefore(session.getAvailableAt())) {
            throw new ApiException(ErrorCode.AUTH_QR_APPROVAL_COOLDOWN);
        }

        if (hasActiveUntrustedWebSession(approverId) && !Boolean.TRUE.equals(input.confirmReplaceActiveUntrusted())) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    "CONFIRM_REPLACE_REQUIRED: Active untrusted web session exists. Confirm replace to continue.");
        }

        session.setStatus(QrLoginSessionStatus.APPROVED);
        session.setApprovedByAccountId(approverId);
        session.setApprovedAt(now);
        session.setMobileDeviceId(trimToNull(input.deviceId()));
        session.setMobileDeviceName(trimToNull(input.deviceName()));
        session.setMobilePlatform(normalizePlatform(input.platform(), "MOBILE"));
        session.setMobileIpAddress(resolveClientIp(request));
        session.setMobileLocation(trimToNull(input.location()));

        sessionAuditService.record(
            approverId,
            null,
            "QR_SESSION_APPROVED",
            "QR_WEB",
            "UNTRUSTED",
            "Trusted mobile approved untrusted web login"
        );

        return new SessionApproveResponse(
                session.getStatus(),
                session.getWebDeviceName(),
                session.getWebIpAddress(),
                session.getWebLocation(),
                session.getExpiresAt()
        );
    }

    @Transactional(readOnly = true)
    public SessionPreviewResponse getSessionPreview(String token) {
        final AuthQrLoginSession session = findSession(token);
        markExpiredIfNeeded(session);

        return new SessionPreviewResponse(
                session.getStatus(),
                session.getExpiresAt(),
                secondsRemaining(session.getExpiresAt()),
                cooldownRemaining(session.getAvailableAt()),
                session.getWebDeviceName(),
                session.getWebPlatform(),
                session.getWebIpAddress(),
                session.getWebLocation()
        );
    }

    private AuthQrLoginSession findSession(String token) {
        return qrSessionRepository.findByQrToken(token)
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_QR_SESSION_NOT_FOUND));
    }

    private void markExpiredIfNeeded(AuthQrLoginSession session) {
        if ((session.getStatus() == QrLoginSessionStatus.PENDING || session.getStatus() == QrLoginSessionStatus.APPROVED)
                && Instant.now().isAfter(session.getExpiresAt())) {
            session.setStatus(QrLoginSessionStatus.EXPIRED);
        }
    }

    private AuthResponse buildAuthResponseForWeb(UUID accountId, AuthQrLoginSession session, HttpServletRequest request) {
        final AuthAccount account = authAccountRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        final UserProfile profile = userProfileRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

        final UserSetting setting = userSettingRepository.findById(accountId)
            .orElseGet(() -> UserSetting.createDefault(accountId));

        final UserPrincipal principal = UserPrincipal.create(account);
        final String refreshToken = jwtTokenProvider.generateRefreshToken();

        enforceQrWebDeviceSlots(accountId);
        final AuthRefreshToken stored = AuthRefreshToken.builder()
                .accountId(accountId)
                .tokenHash(hashToken(refreshToken))
                .deviceId("qr-web-" + UUID.randomUUID())
                .deviceName(nonBlank(session.getWebDeviceName(), "Web Browser"))
                .platform(nonBlank(session.getWebPlatform(), "WEB"))
                .ipAddress(nonBlank(session.getWebIpAddress(), resolveClientIp(request)))
                .userAgent(nonBlank(session.getWebUserAgent(), request.getHeader("User-Agent")))
                .expiresAt(Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpiration()))
                .build();
        refreshTokenRepository.save(stored);

            final Map<String, Object> claims = new HashMap<>();
            claims.put("clientPlatform", "WEB");
            claims.put("sessionType", "QR_WEB");
            claims.put("trustLevel", "UNTRUSTED");
            claims.put("restrictedWebMode", false);
            claims.put("deviceId", stored.getDeviceId());
            claims.put("syncEnabled", Boolean.TRUE.equals(setting.getSyncEnabled()));
            final String accessToken = jwtTokenProvider.generateAccessToken(principal, claims);

            sessionAuditService.record(
                accountId,
                stored,
                "QR_WEB_SESSION_CREATED",
                "QR_WEB",
                "UNTRUSTED",
                "Untrusted web session created via QR"
            );

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtTokenProvider.getAccessTokenExpirationSeconds())
                .user(UserInfoResponse.builder()
                        .id(profile.getId())
                        .phone(account.getPhone())
                        .email(account.getEmail())
                        .displayName(profile.getDisplayName())
                        .avatarUrl(profile.getAvatarUrl())
                        .coverUrl(profile.getCoverUrl())
                        .bio(profile.getBio())
                        .gender(profile.getGender())
                        .dob(profile.getDob())
                        .statusMessage(profile.getStatusMessage())
                        .isVerified(profile.getIsVerified())
                        .build())
                .build();
    }

    private void enforceQrWebDeviceSlots(UUID accountId) {
        final Instant now = Instant.now();
        final List<AuthRefreshToken> activeTokens = refreshTokenRepository
                .findByAccountIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtAsc(accountId, now);

        final List<AuthRefreshToken> activeWebTokens = activeTokens.stream()
            .filter(token -> isWebToken(token.getPlatform()) && isQrWebToken(token.getDeviceId()))
                .toList();

        final int revokeCount = activeWebTokens.size() - MAX_ACTIVE_UNTRUSTED_WEB_DEVICES + 1;
        if (revokeCount <= 0) {
            return;
        }

        for (int i = 0; i < revokeCount; i++) {
            activeWebTokens.get(i).setRevokedAt(now);
        }
        refreshTokenRepository.saveAll(activeWebTokens.subList(0, revokeCount));
    }

    private boolean isWebToken(String platform) {
        final String normalized = trimToNull(platform);
        if (normalized == null) {
            return true;
        }
        final String upper = normalized.toUpperCase(Locale.ROOT);
        return !"ANDROID".equals(upper) && !"IOS".equals(upper);
    }

    private boolean isQrWebToken(String deviceId) {
        final String normalized = trimToNull(deviceId);
        return normalized != null && normalized.startsWith("qr-web-");
    }

    private boolean hasActiveUntrustedWebSession(UUID accountId) {
        final Instant now = Instant.now();
        return refreshTokenRepository
                .findByAccountIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtAsc(accountId, now)
                .stream()
                .anyMatch(token -> isQrWebToken(token.getDeviceId()));
    }

    private LoginNotice buildLoginNotice(AuthQrLoginSession session) {
        final String location = nonBlank(session.getWebLocation(), nonBlank(session.getWebIpAddress(), "Không rõ"));
        final String time = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss")
                .withZone(ZoneId.systemDefault())
                .format(Instant.now());
        final String content = "Đăng nhập thành công trên máy tính\n"
                + "- Bằng: Mã QR\n"
                + "- Tại: " + location + "\n"
                + "- Lúc: " + time;

        return new LoginNotice("Vnalo", content, "/settings?tab=devices");
    }

    private String hashToken(String token) {
        try {
            final MessageDigest digest = MessageDigest.getInstance("SHA-256");
            final byte[] hash = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("Failed to hash token", e);
        }
    }

    private String randomToken() {
        final byte[] bytes = new byte[36];
        new java.security.SecureRandom().nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String resolveClientIp(HttpServletRequest request) {
        final String xff = trimToNull(request.getHeader("X-Forwarded-For"));
        if (xff != null) {
            final int comma = xff.indexOf(',');
            return comma > 0 ? xff.substring(0, comma).trim() : xff;
        }
        final String realIp = trimToNull(request.getHeader("X-Real-IP"));
        if (realIp != null) {
            return realIp;
        }
        return trimToNull(request.getRemoteAddr());
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        final String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private String normalizePlatform(String value, String fallback) {
        final String normalized = trimToNull(value);
        if (normalized == null) {
            return fallback;
        }
        return normalized.toUpperCase(Locale.ROOT);
    }

    private String nonBlank(String value, String fallback) {
        return trimToNull(value) == null ? fallback : value;
    }

    private long secondsRemaining(Instant expiresAt) {
        final long seconds = Duration.between(Instant.now(), expiresAt).getSeconds();
        return Math.max(seconds, 0);
    }

    private long cooldownRemaining(Instant availableAt) {
        final long seconds = Duration.between(Instant.now(), availableAt).getSeconds();
        return Math.max(seconds, 0);
    }

    public record SessionCreateRequest(String deviceName, String platform, String location) {}

    public record SessionApproveRequest(String deviceId, String deviceName, String platform, String location, Boolean confirmReplaceActiveUntrusted) {}

    public record SessionCreateResponse(String token, Instant expiresAt, long expiresInSeconds, String qrPayload) {}

    public record SessionPreviewResponse(
            QrLoginSessionStatus status,
            Instant expiresAt,
            long secondsRemaining,
            long cooldownSecondsRemaining,
            String webDeviceName,
            String webPlatform,
            String webIpAddress,
            String webLocation
    ) {}

    public record SessionApproveResponse(
            QrLoginSessionStatus status,
            String webDeviceName,
            String webIpAddress,
            String webLocation,
            Instant expiresAt
    ) {}

    public record LoginNotice(String senderName, String content, String historyPath) {}

    public record SessionPollResponse(
            QrLoginSessionStatus status,
            Instant expiresAt,
            long secondsRemaining,
            long cooldownSecondsRemaining,
            String webDeviceName,
            String webIpAddress,
            String webLocation,
            AuthResponse auth,
            LoginNotice loginNotice
    ) {}
}
