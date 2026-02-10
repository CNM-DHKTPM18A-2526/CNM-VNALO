package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.config.OtpConfig;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RefreshTokenRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
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
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Base64;
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
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final OtpConfig otpConfig;
    private final OtpService otpService;

    @Transactional
    public AuthResponse register(RegisterRequest request, HttpServletRequest httpRequest) {
        // Check if phone already registered
        if (authAccountRepository.existsByPhone(request.getPhone())) {
            throw new ApiException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS);
        }

        // Verify OTP if enabled
        if (!otpConfig.shouldSkipOtp()) {
            // OTP is required when enabled
            if (request.getOtp() == null || request.getOtp().isBlank()) {
                throw new ApiException(ErrorCode.AUTH_OTP_REQUIRED);
            }
            // Verify OTP
            otpService.verifyOtp(request.getPhone(), request.getOtp(), OtpPurpose.REGISTER);
            log.info("OTP verified for phone: ****{}", request.getPhone().substring(request.getPhone().length() - 4));
        } else {
            log.info("OTP verification skipped (disabled in config)");
        }

        // Create account - status depends on OTP verification
        AccountStatus initialStatus = otpConfig.shouldSkipOtp() 
                ? AccountStatus.ACTIVE 
                : AccountStatus.ACTIVE; // OTP already verified at this point
        
        AuthAccount account = AuthAccount.builder()
                .phone(request.getPhone())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .passwordUpdatedAt(Instant.now())
                .status(initialStatus)
                .build();
        account = authAccountRepository.save(account);

        // Create profile with same ID as account (1:1 relationship)
        UserProfile profile = UserProfile.createWithAccountId(account.getId(), request.getDisplayName());
        profile = userProfileRepository.save(profile);

        // Create default privacy settings
        UserPrivacySetting privacySetting = UserPrivacySetting.createDefault(profile.getId());
        userPrivacySettingRepository.save(privacySetting);

        // Generate tokens
        UserPrincipal userPrincipal = UserPrincipal.create(account);
        String accessToken = jwtTokenProvider.generateAccessToken(userPrincipal);
        String refreshToken = generateAndSaveRefreshToken(account.getId(), httpRequest, null);

        log.info("User registered successfully: {}", account.getId());
        return buildAuthResponse(accessToken, refreshToken, account, profile);
    }

    @Transactional
    public AuthResponse login(LoginRequest request, HttpServletRequest httpRequest) {
        // Pre-check: find account and check lock status
        AuthAccount account = authAccountRepository.findByPhone(request.getIdentifier())
                .orElseThrow(() -> new ApiException(ErrorCode.AUTH_INVALID_CREDENTIALS));

        if (account.isLocked()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_LOCKED);
        }

        if (!account.isActive()) {
            throw new ApiException(ErrorCode.AUTH_ACCOUNT_DISABLED);
        }

        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getIdentifier(), request.getPassword())
            );

            UserPrincipal userPrincipal = (UserPrincipal) authentication.getPrincipal();

            account.onLoginSuccess(request.getDeviceId());
            authAccountRepository.save(account);

            UserProfile profile = userProfileRepository.findById(account.getId())
                    .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

            if (request.getDeviceId() != null) {
                refreshTokenRepository.revokeByAccountIdAndDeviceId(account.getId(), request.getDeviceId(), Instant.now());
            }

            String accessToken = jwtTokenProvider.generateAccessToken(userPrincipal);
            String refreshToken = generateAndSaveRefreshToken(account.getId(), httpRequest, request.getDeviceId());

            return buildAuthResponse(accessToken, refreshToken, account, profile);
        } catch (BadCredentialsException e) {
            // Track failed login attempt
            account.onLoginFailed();
            // Auto-lock after 5 consecutive failures
            if (account.getFailedLoginCount() >= 5) {
                account.lock(Instant.now().plusSeconds(1800)); // Lock for 30 minutes
                log.warn("Account {} locked after {} failed attempts", account.getId(), account.getFailedLoginCount());
            }
            authAccountRepository.save(account);
            throw new ApiException(ErrorCode.AUTH_INVALID_CREDENTIALS);
        }
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
}
