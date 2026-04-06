package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.config.OtpConfig;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthOtp;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.repository.auth.AuthOtpRepository;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * Service for OTP (One-Time Password) management.
 * Supports sending and verifying OTP codes with configurable toggle.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OtpService {
    
    private final AuthOtpRepository otpRepository;
    private final OtpConfig otpConfig;
    private final PasswordEncoder passwordEncoder;
    private final FcmService fcmService;
    private final EmailOtpService emailOtpService;
    private final SecureRandom secureRandom = new SecureRandom();
    
    /**
     * Send OTP to the target phone number.
     * 
     * @param phone Target phone number
     * @param purpose Purpose of OTP (REGISTRATION, PASSWORD_RESET, etc.)
     * @return Result containing expiration info
     */
    @Transactional
    public OtpSendResult sendOtp(String target, OtpPurpose purpose) {
        log.info("Sending OTP to {} for purpose: {}", maskTarget(target), purpose);
        
        // Check if OTP is disabled (dev mode)
        if (otpConfig.shouldSkipOtp()) {
            log.info("OTP is DISABLED - skipping send");
            return OtpSendResult.skipped("OTP verification is disabled");
        }
        
        // Rate limiting check
        long recentRequests = otpRepository.countRecentRequests(
            target, purpose, Instant.now().minus(1, ChronoUnit.HOURS));
        
        if (recentRequests >= otpConfig.getRateLimit().getRequestsPerHour()) {
            log.warn("Rate limit exceeded for target: {}", maskTarget(target));
            throw new ApiException(ErrorCode.AUTH_OTP_RATE_LIMITED);
        }
        
        // Check cooldown period
        otpRepository.findLatestOtp(target, purpose).ifPresent(lastOtp -> {
            long secondsSinceLastRequest = ChronoUnit.SECONDS.between(
                lastOtp.getCreatedAt(), Instant.now());
            if (secondsSinceLastRequest < otpConfig.getRateLimit().getCooldownSeconds()) {
                throw new ApiException(ErrorCode.AUTH_OTP_COOLDOWN);
            }
        });
        
        // Generate OTP
        String rawOtp = generateOtp();
        String otpHash = passwordEncoder.encode(rawOtp);
        
        // Save to database
        AuthOtp otp = AuthOtp.builder()
            .target(target)
            .purpose(purpose)
            .otpHash(otpHash)
            .expiresAt(Instant.now().plus(otpConfig.getExpirationMinutes(), ChronoUnit.MINUTES))
            .build();
        otpRepository.save(otp);
        
        // Send OTP
        if (otpConfig.isTestMode()) {
            // Test mode: log OTP instead of sending
            if (otpConfig.getTestMode().isLogOtp()) {
                log.info("========================================");
                log.info("TEST MODE - OTP for {}: {}", maskTarget(target), rawOtp);
                log.info("========================================");
            }
        } else {
            // Production: route OTP by target type.
            if (isEmailTarget(target)) {
                emailOtpService.sendOtp(target, rawOtp, purpose);
            } else {
                sendOtpViaSms(target, rawOtp);
            }
        }
        
        log.info("OTP sent successfully to {}", maskTarget(target));
        return OtpSendResult.success(otpConfig.getExpirationMinutes() * 60);
    }
    
    /**
     * Verify OTP code.
     * 
     * @param phone Target phone number
     * @param otpCode OTP code to verify
     * @param purpose Purpose of OTP
     * @return true if verified successfully
     */
    @Transactional
    public boolean verifyOtp(String target, String otpCode, OtpPurpose purpose) {
        log.info("Verifying OTP for {}", maskTarget(target));
        
        // If OTP disabled, skip verification
        if (otpConfig.shouldSkipOtp()) {
            log.info("OTP is DISABLED - auto-verifying");
            return true;
        }
        
        // Test mode: accept mock OTP
        if (otpConfig.isTestMode() && 
            otpCode.equals(otpConfig.getTestMode().getMockOtp())) {
            log.info("TEST MODE - Mock OTP accepted for {}", maskTarget(target));
            return true;
        }
        
        // Find latest valid OTP
        AuthOtp otp = otpRepository.findLatestValidOtp(target, purpose, Instant.now())
            .orElseThrow(() -> {
                log.warn("No valid OTP found for {}", maskTarget(target));
                return new ApiException(ErrorCode.AUTH_OTP_EXPIRED);
            });
        
        // Check max attempts
        if (otp.isMaxAttemptsExceeded(otpConfig.getMaxAttempts())) {
            log.warn("Max OTP attempts exceeded for {}", maskTarget(target));
            throw new ApiException(ErrorCode.AUTH_OTP_MAX_ATTEMPTS);
        }
        
        // Verify OTP
        if (!passwordEncoder.matches(otpCode, otp.getOtpHash())) {
            otp.incrementAttempts();
            otpRepository.save(otp);
            log.warn("Invalid OTP attempt for {} (attempt {})", 
                maskTarget(target), otp.getAttempts());
            throw new ApiException(ErrorCode.AUTH_OTP_INVALID);
        }
        
        // Mark as verified
        otp.markAsVerified();
        otpRepository.save(otp);
        
        log.info("OTP verified successfully for {}", maskTarget(target));
        return true;
    }
    
    /**
     * Check if phone has been verified for a specific purpose.
     */
    @Transactional(readOnly = true)
    public boolean isPhoneVerified(String phone, OtpPurpose purpose) {
        if (otpConfig.shouldSkipOtp()) {
            return true;
        }
        return otpRepository.existsVerifiedOtp(phone, purpose);
    }
    
    /**
     * Generate random OTP code.
     */
    private String generateOtp() {
        int length = otpConfig.getLength();
        int min = (int) Math.pow(10, length - 1);
        int max = (int) Math.pow(10, length) - 1;
        int otp = min + secureRandom.nextInt(max - min + 1);
        return String.valueOf(otp);
    }
    
    /**
     * Send OTP via notification.
     * 
     * For REGISTRATION: OTP is logged (new user has no FCM token yet).
     * For PASSWORD_RESET: OTP sent via FCM push notification (user has token).
     * 
     * In production, consider:
     * - Use Firebase Phone Auth on client-side for registration
     * - Use FCM for password reset OTP delivery
     */
    private void sendOtpViaSms(String phone, String otp) {
        // In production, integrate with SMS provider (Firebase Phone Auth recommended for client-side)
        log.info("OTP delivery requested for {}", maskTarget(phone));
        log.warn("OTP delivery provider is not configured. Configure SMS/FCM delivery before production usage.");
        
        // TODO: For password reset flow, fetch user's FCM tokens and send via FCM:
        // List<String> fcmTokens = deviceRepository.findFcmTokensByPhone(phone);
        // if (!fcmTokens.isEmpty()) {
        //     fcmService.sendOtpToMultipleDevices(fcmTokens, otp);
        // }
    }
    
    /**
     * Mask phone number for logging (show only last 4 digits).
     */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 4) {
            return "****";
        }
        return "****" + phone.substring(phone.length() - 4);
    }

    private String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "***";
        }
        int at = email.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        return email.charAt(0) + "***" + email.substring(at);
    }

    private String maskTarget(String target) {
        if (isEmailTarget(target)) {
            return maskEmail(target);
        }
        return maskPhone(target);
    }

    private boolean isEmailTarget(String target) {
        return target != null && target.contains("@");
    }
    
    /**
     * Result of sending OTP.
     */
    @Getter
    public static class OtpSendResult {
        private final boolean success;
        private final boolean skipped;
        private final String message;
        private final int expiresInSeconds;
        
        private OtpSendResult(boolean success, boolean skipped, String message, int expiresInSeconds) {
            this.success = success;
            this.skipped = skipped;
            this.message = message;
            this.expiresInSeconds = expiresInSeconds;
        }
        
        public static OtpSendResult success(int expiresIn) {
            return new OtpSendResult(true, false, "OTP sent successfully", expiresIn);
        }
        
        public static OtpSendResult skipped(String reason) {
            return new OtpSendResult(true, true, reason, 0);
        }
    }
}
