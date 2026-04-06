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
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import iuh.cnm.vnalo.core_service.security.JwtTokenProvider;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Base64;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final AuthAccountRepository authAccountRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserProfileRepository userProfileRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final OtpService otpService;

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

        UserPrincipal userPrincipal = UserPrincipal.create(account);
        String accessToken = jwtTokenProvider.generateAccessToken(userPrincipal);
        String refreshToken = generateAndSaveRefreshToken(account.getId(), httpRequest, null);

        log.info("User registered successfully: {}", account.getId());
        return buildAuthResponse(accessToken, refreshToken, account, profile);
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

        account.onLoginSuccess(request.getDeviceId());
        authAccountRepository.save(account);

        UserProfile profile = userProfileRepository.findById(account.getId())
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

        if (request.getDeviceId() != null) {
            refreshTokenRepository.revokeByAccountIdAndDeviceId(account.getId(), request.getDeviceId(), Instant.now());
        }

        UserPrincipal userPrincipal = UserPrincipal.create(account);
        String accessToken = jwtTokenProvider.generateAccessToken(userPrincipal);
        String refreshToken = generateAndSaveRefreshToken(account.getId(), httpRequest, request.getDeviceId());

        return buildAuthResponse(accessToken, refreshToken, account, profile);
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
        String newAccessToken = jwtTokenProvider.generateAccessToken(userPrincipal);

        storedToken.revoke();
        refreshTokenRepository.save(storedToken);

        String newRefreshToken = generateAndSaveRefreshToken(account.getId(), httpRequest, storedToken.getDeviceId());
        return buildAuthResponse(newAccessToken, newRefreshToken, account, profile);
    }

    @Transactional
    public void logout(String refreshToken) {
        if (refreshToken != null && !refreshToken.isBlank()) {
            String tokenHash = hashToken(refreshToken);
            refreshTokenRepository.revokeByTokenHash(tokenHash, Instant.now());
        }
    }

    @Transactional
    public void logoutAll(UUID accountId) {
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

    private String generateAndSaveRefreshToken(UUID accountId, HttpServletRequest request, String deviceId) {
        String rawToken = jwtTokenProvider.generateRefreshToken();
        String tokenHash = hashToken(rawToken);

        AuthRefreshToken refreshToken = AuthRefreshToken.builder()
                .accountId(accountId)
                .tokenHash(tokenHash)
                .deviceId(deviceId != null ? deviceId : UUID.randomUUID().toString())
                .expiresAt(Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpiration()))
                .build();

        refreshTokenRepository.save(refreshToken);
        return rawToken;
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
        String seed = accountId != null ? accountId.toString() : UUID.randomUUID().toString();
        return "https://api.dicebear.com/9.x/initials/svg?seed=" + seed + "&radius=50&size=256&chars=2&fontFamily=Arial&fontWeight=600&backgroundType=gradientLinear&text=" + encodedName;
    }
}
