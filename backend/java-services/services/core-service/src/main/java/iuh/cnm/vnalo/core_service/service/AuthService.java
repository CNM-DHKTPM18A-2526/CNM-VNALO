package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.ChangePasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ForgotPasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RefreshTokenRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ResetPasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthRefreshToken;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.entity.user.UserSetting;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserSettingRepository;
import iuh.cnm.vnalo.core_service.security.JwtTokenProvider;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private static final int MAX_ACTIVE_MOBILE_DEVICES = 1;
    private static final int MAX_ACTIVE_WEB_DEVICES_STANDARD = 2;
    private static final int MAX_ACTIVE_WEB_DEVICES_WITH_QR = 3;

    private final AuthAccountRepository authAccountRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserProfileRepository userProfileRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;
    private final UserSettingRepository userSettingRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final OtpService otpService;
    private final SessionAuditService sessionAuditService;

    @Transactional(readOnly = true)
    public boolean isPhoneRegistered(String phone) {
        return authAccountRepository.existsByPhone(phone);
    }

    @Transactional(readOnly = true)
    public boolean isEmailRegistered(String email) {
        return authAccountRepository.existsByEmailIgnoreCase(normalizeEmail(email));
    }

    @Transactional
    public OtpService.OtpSendResult sendRegistrationOtp(String email) {
        final String normalizedEmail = normalizeEmail(email);
        return otpService.sendOtp(normalizedEmail, OtpPurpose.REGISTER);
    }

    @Transactional(readOnly = true)
    public void verifyRegistrationOtp(String email, String otp) {
        otpService.verifyOtp(normalizeEmail(email), otp, OtpPurpose.REGISTER);
    }

    @Transactional
    public AuthResponse register(RegisterRequest request, HttpServletRequest httpRequest) {
        final String normalizedEmail = normalizeEmail(request.getEmail());

        if (authAccountRepository.existsByPhone(request.getPhone())) {
            throw new ApiException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS);
        }
        if (authAccountRepository.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new ApiException(ErrorCode.AUTH_EMAIL_ALREADY_EXISTS);
        }

        otpService.verifyOtp(normalizedEmail, request.getOtp(), OtpPurpose.REGISTER);

        AuthAccount account = AuthAccount.builder()
                .phone(request.getPhone())
                .email(normalizedEmail)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .passwordUpdatedAt(Instant.now())
                .status(AccountStatus.ACTIVE)
                .build();
        account = authAccountRepository.save(account);

        UserProfile profile = UserProfile.createWithAccountId(account.getId(), request.getDisplayName());
        profile.setAvatarUrl(buildDefaultAvatarUrl(request.getDisplayName(), account.getId()));
        if (request.getGender() != null) {
            profile.setGender(request.getGender());
        }
        if (request.getDob() != null) {
            profile.setDob(request.getDob());
        }
        profile = userProfileRepository.save(profile);

        UserPrivacySetting privacySetting = UserPrivacySetting.createDefault(profile.getId());
        userPrivacySettingRepository.save(privacySetting);

        UserSetting userSetting = UserSetting.createDefault(profile.getId());
        userSettingRepository.save(userSetting);

        IssuedRefreshToken issuedRefreshToken = generateAndSaveRefreshToken(
            account.getId(),
            httpRequest,
            null,
            null,
            null,
            false
        );
        UserPrincipal userPrincipal = UserPrincipal.create(account);
        String accessToken = buildAccessTokenForSession(userPrincipal, null, "ANDROID", false, true);

        log.info("User registered successfully: {}", account.getId());
        return buildAuthResponse(accessToken, issuedRefreshToken.rawToken(), account, profile);
    }

    @Transactional
    public AuthResponse login(LoginRequest request, HttpServletRequest httpRequest) {
        AuthAccount account = resolveAccountByIdentifier(request.getIdentifier())
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_INVALID_CREDENTIALS));

        if (account.isLocked()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_LOCKED);
        }

        if (!account.isActive()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_DISABLED);
        }

        if (!passwordEncoder.matches(request.getPassword(), account.getPasswordHash())) {
            account.onLoginFailed();
            if (account.getFailedLoginCount() >= 5) {
                account.lock(Instant.now().plusSeconds(1800));
                log.warn("Account {} locked after {} failed attempts", account.getId(), account.getFailedLoginCount());
            }
            authAccountRepository.save(account);
            throw new ApiException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }

        final String normalizedPlatform = resolvePlatform(request.getPlatform(), httpRequest);
        if (classifyPlatform(normalizedPlatform) == DeviceGroup.WEB && !isQrWebDevice(request.getDeviceId())) {
            enforceKnownWebDeviceOrQrApproval(account.getId(), request.getDeviceId());
        }

        account.onLoginSuccess(request.getDeviceId());
        authAccountRepository.save(account);

        UserProfile profile = userProfileRepository.findById(account.getId())
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

        if (request.getDeviceId() != null) {
            refreshTokenRepository.revokeByAccountIdAndDeviceId(account.getId(), request.getDeviceId(), Instant.now());
        }

        UserPrincipal userPrincipal = UserPrincipal.create(account);
        IssuedRefreshToken issuedRefreshToken = generateAndSaveRefreshToken(
            account.getId(),
            httpRequest,
            request.getDeviceId(),
            request.getDeviceName(),
            normalizedPlatform,
            false
        );

        final UserSetting setting = userSettingRepository.findById(account.getId())
                .orElseGet(() -> UserSetting.createDefault(account.getId()));
        final boolean restrictedWebMode = isWebRestrictedForSession(setting, normalizedPlatform, request.getDeviceId());

        String accessToken = buildAccessTokenForSession(
                userPrincipal,
                request.getDeviceId(),
                normalizedPlatform,
                false,
                restrictedWebMode
        );

        sessionAuditService.record(
                account.getId(),
                issuedRefreshToken.token(),
                "LOGIN_SUCCESS",
                resolveSessionType(issuedRefreshToken.token()),
                resolveTrustLevel(issuedRefreshToken.token()),
                "Password login succeeded"
        );

        return buildAuthResponse(accessToken, issuedRefreshToken.rawToken(), account, profile);
    }

    @Transactional
    public AuthResponse refreshToken(RefreshTokenRequest request, HttpServletRequest httpRequest) {
        String tokenHash = hashToken(request.getRefreshToken());
        AuthRefreshToken storedToken = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_REFRESH_TOKEN_REVOKED));

        if (!storedToken.isValid()) {
            throw new ApiException(ErrorCode.AUTH_REFRESH_TOKEN_EXPIRED);
        }

        AuthAccount account = authAccountRepository.findById(storedToken.getAccountId())
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        if (!account.isActive()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_DISABLED);
        }

        UserProfile profile = userProfileRepository.findById(account.getId())
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

        UserPrincipal userPrincipal = UserPrincipal.create(account);

        storedToken.revoke();
        refreshTokenRepository.save(storedToken);
        sessionAuditService.record(
            account.getId(),
            storedToken,
            "SESSION_REVOKED_REFRESH_ROTATION",
            resolveSessionType(storedToken),
            resolveTrustLevel(storedToken),
            "Refresh rotation revoked old token"
        );

        IssuedRefreshToken issuedRefreshToken = generateAndSaveRefreshToken(
            account.getId(),
            httpRequest,
            storedToken.getDeviceId(),
            storedToken.getDeviceName(),
            storedToken.getPlatform(),
            isQrWebDevice(storedToken.getDeviceId())
        );
        final UserSetting setting = userSettingRepository.findById(account.getId())
            .orElseGet(() -> UserSetting.createDefault(account.getId()));
        final boolean restrictedWebMode = isWebRestrictedForSession(setting, storedToken.getPlatform(), storedToken.getDeviceId());

        String newAccessToken = buildAccessTokenForSession(
            userPrincipal,
            storedToken.getDeviceId(),
            storedToken.getPlatform(),
            isQrWebDevice(storedToken.getDeviceId()),
            restrictedWebMode
        );

        sessionAuditService.record(
            account.getId(),
            issuedRefreshToken.token(),
            "SESSION_REFRESHED",
            resolveSessionType(issuedRefreshToken.token()),
            resolveTrustLevel(issuedRefreshToken.token()),
            "Refresh token rotated"
        );
        return buildAuthResponse(newAccessToken, issuedRefreshToken.rawToken(), account, profile);
    }

    @Transactional(readOnly = true)
    public List<LoginDeviceInfo> getLoginDevices(UUID accountId, int limit) {
        final int pageSize = Math.max(1, Math.min(limit, 50));
        return refreshTokenRepository
            .findByAccountIdOrderByCreatedAtDesc(accountId, PageRequest.of(0, pageSize))
            .stream()
            .map(token -> new LoginDeviceInfo(
                token.getTokenId(),
                token.getDeviceId(),
                token.getDeviceName(),
                token.getPlatform(),
                token.getIpAddress(),
                token.getUserAgent(),
                token.getCreatedAt(),
                token.getExpiresAt(),
                token.getRevokedAt(),
                token.isValid(),
                resolveSessionType(token),
                resolveTrustLevel(token),
                resolveSessionState(token)
            ))
            .toList();
    }

    @Transactional
    public void logout(String refreshToken) {
        if (refreshToken != null && !refreshToken.isBlank()) {
            String tokenHash = hashToken(refreshToken);
            refreshTokenRepository.findByTokenHash(tokenHash).ifPresent(token ->
                sessionAuditService.record(
                    token.getAccountId(),
                    token,
                    "SESSION_REVOKED_LOGOUT",
                    resolveSessionType(token),
                    resolveTrustLevel(token),
                    "User requested logout"
                )
            );
            refreshTokenRepository.revokeByTokenHash(tokenHash, Instant.now());
        }
    }

    @Transactional
    public void logoutAll(UUID accountId) {
        sessionAuditService.record(
                accountId,
                null,
                "SESSION_REVOKED_LOGOUT_ALL",
                "BULK",
                "N/A",
                "User requested logout all sessions"
        );
        refreshTokenRepository.revokeAllByAccountId(accountId, Instant.now());
    }

    @Transactional
    public void changePassword(UUID accountId, ChangePasswordRequest request) {
        AuthAccount account = authAccountRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        if (!passwordEncoder.matches(request.getCurrentPassword(), account.getPasswordHash())) {
            throw new ApiException(ErrorCode.AUTH_PASSWORD_MISMATCH);
        }

        validatePasswordPolicy(request.getNewPassword());

        if (passwordEncoder.matches(request.getNewPassword(), account.getPasswordHash())) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "New password must be different from current password");
        }

        account.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        account.setPasswordUpdatedAt(Instant.now());
        account.setFailedLoginCount(0);

        if (account.getStatus() == AccountStatus.LOCKED) {
            account.setStatus(AccountStatus.ACTIVE);
            account.setLockedUntil(null);
        }

        authAccountRepository.save(account);
        refreshTokenRepository.revokeAllByAccountId(accountId, Instant.now());

        log.info("Password changed successfully for account {}", accountId);
    }

    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        final String email = normalizeEmail(request.email());

        authAccountRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_ACCOUNT_NOT_FOUND_BY_EMAIL));

        otpService.sendOtp(email, OtpPurpose.RESET_PASSWORD);
        log.info("Password reset OTP sent for email: {}", maskEmail(email));
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        final String email = normalizeEmail(request.getEmail());

        AuthAccount account = authAccountRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_ACCOUNT_NOT_FOUND_BY_EMAIL));

        otpService.verifyOtp(email, request.getOtp(), OtpPurpose.RESET_PASSWORD);
        validatePasswordPolicy(request.getNewPassword());

        if (passwordEncoder.matches(request.getNewPassword(), account.getPasswordHash())) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR, "New password must be different from current password");
        }

        account.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        account.setPasswordUpdatedAt(Instant.now());
        account.setFailedLoginCount(0);

        if (account.isLocked()) {
            account.setStatus(AccountStatus.ACTIVE);
            account.setLockedUntil(null);
        }

        authAccountRepository.save(account);
        refreshTokenRepository.revokeAllByAccountId(account.getId(), Instant.now());

        log.info("Password reset successfully for email: {}", maskEmail(email));
    }

    private IssuedRefreshToken generateAndSaveRefreshToken(
        UUID accountId,
        HttpServletRequest request,
        String deviceId,
        String deviceName,
        String platform,
        boolean allowExtraWebSlot
    ) {
        String rawToken = jwtTokenProvider.generateRefreshToken();
        String tokenHash = hashToken(rawToken);
        final String normalizedPlatform = resolvePlatform(platform, request);

        enforceActiveDeviceSlots(accountId, normalizedPlatform, allowExtraWebSlot);

        AuthRefreshToken refreshToken = AuthRefreshToken.builder()
                .accountId(accountId)
                .tokenHash(tokenHash)
                .deviceId(deviceId != null ? deviceId : UUID.randomUUID().toString())
                .deviceName(deviceName)
                .platform(normalizedPlatform)
                .ipAddress(resolveClientIp(request))
                .userAgent(request != null ? request.getHeader("User-Agent") : null)
                .expiresAt(Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpiration()))
                .build();

        refreshTokenRepository.save(refreshToken);
            return new IssuedRefreshToken(rawToken, refreshToken);
    }

    private String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(token.getBytes());
            return Base64.getEncoder().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("Failed to hash token", e);
        }
    }

    private void enforceActiveDeviceSlots(UUID accountId, String platform, boolean allowExtraWebSlot) {
        final DeviceGroup targetGroup = classifyPlatform(platform);
        final int maxWebDevices = allowExtraWebSlot ? MAX_ACTIVE_WEB_DEVICES_WITH_QR : MAX_ACTIVE_WEB_DEVICES_STANDARD;
        final int maxAllowedForGroup = targetGroup == DeviceGroup.MOBILE ? MAX_ACTIVE_MOBILE_DEVICES : maxWebDevices;

        final Instant now = Instant.now();
        final List<AuthRefreshToken> activeTokens = refreshTokenRepository
            .findByAccountIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtAsc(accountId, now);

        final List<AuthRefreshToken> sameGroupTokens = activeTokens.stream()
            .filter(token -> classifyToken(token) == targetGroup)
            .toList();

        final int revokeCount = sameGroupTokens.size() - maxAllowedForGroup + 1;
        if (revokeCount <= 0) {
            return;
        }

        for (int i = 0; i < revokeCount; i++) {
            sameGroupTokens.get(i).setRevokedAt(now);
            sessionAuditService.record(
                    accountId,
                    sameGroupTokens.get(i),
                    "SESSION_REVOKED_SLOT_ENFORCED",
                    resolveSessionType(sameGroupTokens.get(i)),
                    resolveTrustLevel(sameGroupTokens.get(i)),
                    "Device slot limit enforcement"
            );
        }
        refreshTokenRepository.saveAll(sameGroupTokens.subList(0, revokeCount));
    }

    private void enforceKnownWebDeviceOrQrApproval(UUID accountId, String deviceId) {
        final String normalizedDeviceId = deviceId == null ? "" : deviceId.trim();
        if (normalizedDeviceId.isBlank()) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    "Unknown web device. Please login by QR approval from trusted mobile.");
        }

        final boolean knownWebDevice = refreshTokenRepository.existsByAccountIdAndDeviceId(accountId, normalizedDeviceId);
        if (knownWebDevice) {
            return;
        }

        final boolean hasTrustedMobile = refreshTokenRepository.hasActiveTrustedMobileSession(accountId, Instant.now());
        if (!hasTrustedMobile) {
            throw new ApiException(ErrorCode.VALIDATION_ERROR,
                    "No trusted mobile session available. Login on mobile first, then approve QR for this web device.");
        }

        throw new ApiException(ErrorCode.VALIDATION_ERROR,
                "Unknown web device detected. Please approve this login via QR from trusted mobile.");
    }

    private String buildAccessTokenForSession(
            UserPrincipal userPrincipal,
            String deviceId,
            String platform,
            boolean isQrSession,
            boolean restrictedWebMode
    ) {
        final Map<String, Object> claims = new HashMap<>();
        final String normalizedPlatform = normalizePlatform(platform) != null ? normalizePlatform(platform) : "WEB";
        claims.put("clientPlatform", normalizedPlatform);
        claims.put("sessionType", isQrSession ? "QR_WEB" : "PASSWORD");
        claims.put("trustLevel", isQrSession ? "UNTRUSTED" : ("WEB".equals(normalizedPlatform) ? "TRUSTED_WEB" : "TRUSTED_MOBILE"));
        claims.put("restrictedWebMode", restrictedWebMode);
        if (deviceId != null && !deviceId.isBlank()) {
            claims.put("deviceId", deviceId);
        }
        return jwtTokenProvider.generateAccessToken(userPrincipal, claims);
    }

    private boolean isWebRestrictedForSession(UserSetting setting, String platform, String deviceId) {
        final String normalizedPlatform = normalizePlatform(platform);
        if (!"WEB".equals(normalizedPlatform) && !"PC".equals(normalizedPlatform)) {
            return false;
        }
        // Null syncEnabled should behave as enabled for backward compatibility.
        if (Boolean.FALSE.equals(setting.getSyncEnabled()) || Boolean.TRUE.equals(setting.getWebRestrictedMode())) {
            return true;
        }
        return isQrWebDevice(deviceId);
    }

    private DeviceGroup classifyToken(AuthRefreshToken token) {
        final String platform = normalizePlatform(token.getPlatform());
        if (platform != null) {
            return classifyPlatform(platform);
        }

        final String userAgent = token.getUserAgent();
        if (userAgent != null) {
            final String ua = userAgent.toLowerCase(Locale.ROOT);
            if (ua.contains("android") || ua.contains("iphone") || ua.contains("ipad") || ua.contains("ios")) {
                return DeviceGroup.MOBILE;
            }
        }
        return DeviceGroup.WEB;
    }

    private DeviceGroup classifyPlatform(String platform) {
        return switch (platform) {
            case "ANDROID", "IOS" -> DeviceGroup.MOBILE;
            default -> DeviceGroup.WEB;
        };
    }

    private boolean isQrWebDevice(String deviceId) {
        return deviceId != null && deviceId.startsWith("qr-web-");
    }

    private String resolvePlatform(String platform, HttpServletRequest request) {
        final String normalized = normalizePlatform(platform);
        if (normalized != null) {
            return normalized;
        }

        if (request != null) {
            final String userAgent = request.getHeader("User-Agent");
            if (userAgent != null) {
                final String ua = userAgent.toLowerCase(Locale.ROOT);
                if (ua.contains("android")) {
                    return "ANDROID";
                }
                if (ua.contains("iphone") || ua.contains("ipad") || ua.contains("ios")) {
                    return "IOS";
                }
            }
        }
        return "WEB";
    }

    private AuthResponse buildAuthResponse(String accessToken, String refreshToken, AuthAccount account, UserProfile profile) {
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

    private Optional<AuthAccount> resolveAccountByIdentifier(String identifier) {
        final String trimmed = identifier == null ? "" : identifier.trim();
        if (trimmed.contains("@")) {
            return authAccountRepository.findByEmailIgnoreCase(normalizeEmail(trimmed));
        }
        return authAccountRepository.findByPhone(trimmed);
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "***";
        }
        final String trimmed = email.trim();
        final int at = trimmed.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return trimmed.charAt(0) + "***" + trimmed.substring(at);
    }

    private String resolveClientIp(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        final String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            final int comma = xff.indexOf(',');
            return (comma > 0 ? xff.substring(0, comma) : xff).trim();
        }
        final String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        return request.getRemoteAddr();
    }

    private String normalizePlatform(String platform) {
        if (platform == null || platform.isBlank()) {
            return null;
        }
        final String normalized = platform.trim().toUpperCase(Locale.ROOT);
        return switch (normalized) {
            case "ANDROID", "IOS", "WEB", "PC" -> normalized;
            default -> "WEB";
        };
    }

    private enum DeviceGroup {
        MOBILE,
        WEB
    }

    private void validatePasswordPolicy(String password) {
        if (password == null || password.length() < 8) {
            throw new ApiException(ErrorCode.AUTH_PASSWORD_POLICY);
        }
        boolean hasUpper = password.chars().anyMatch(Character::isUpperCase);
        boolean hasLower = password.chars().anyMatch(Character::isLowerCase);
        boolean hasDigit = password.chars().anyMatch(Character::isDigit);
        if (!hasUpper || !hasLower || !hasDigit) {
            throw new ApiException(ErrorCode.AUTH_PASSWORD_POLICY);
        }
    }

    private String buildDefaultAvatarUrl(String displayName, UUID accountId) {
        String safeName = (displayName == null || displayName.isBlank()) ? "User" : displayName.trim();
        String encodedName = URLEncoder.encode(safeName, StandardCharsets.UTF_8);
        return "https://api.dicebear.com/9.x/initials/png?seed=" + encodedName
                + "&radius=50&size=256&chars=2&fontFamily=Arial&fontWeight=600&backgroundType=gradientLinear";
    }

    public record LoginDeviceInfo(
            UUID tokenId,
            String deviceId,
            String deviceName,
            String platform,
            String ipAddress,
            String userAgent,
            Instant createdAt,
            Instant expiresAt,
            Instant revokedAt,
            boolean active,
            String sessionType,
            String trustLevel,
            String sessionState
    ) {}

    private String resolveSessionType(AuthRefreshToken token) {
        return isQrWebDevice(token.getDeviceId()) ? "QR_WEB" : "PASSWORD";
    }

    private String resolveTrustLevel(AuthRefreshToken token) {
        if (isQrWebDevice(token.getDeviceId())) {
            return "UNTRUSTED";
        }
        return classifyToken(token) == DeviceGroup.MOBILE ? "TRUSTED_MOBILE" : "TRUSTED_WEB";
    }

    private String resolveSessionState(AuthRefreshToken token) {
        if (token.getRevokedAt() != null) {
            return "REVOKED";
        }
        if (token.getExpiresAt() != null && token.getExpiresAt().isBefore(Instant.now())) {
            return "EXPIRED";
        }
        return "ACTIVE";
    }

    private record IssuedRefreshToken(String rawToken, AuthRefreshToken token) {}

}
