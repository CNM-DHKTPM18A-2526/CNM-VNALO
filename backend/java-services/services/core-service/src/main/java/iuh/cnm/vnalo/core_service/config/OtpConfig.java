package iuh.cnm.vnalo.core_service.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration properties for OTP (One-Time Password) functionality.
 * Supports toggle for development/production modes.
 */
@Configuration
@ConfigurationProperties(prefix = "otp")
@Getter
@Setter
public class OtpConfig {
    
    /**
     * Enable/disable OTP verification.
     * Set to false for development to skip OTP entirely.
     */
    private boolean enabled = true;
    
    /**
     * OTP expiration time in minutes.
     */
    private int expirationMinutes = 5;
    
    /**
     * Maximum wrong attempts before OTP is invalidated.
     */
    private int maxAttempts = 3;
    
    /**
     * Length of OTP code (default: 6 digits).
     */
    private int length = 6;
    
    /**
     * Rate limiting configuration.
     */
    private RateLimit rateLimit = new RateLimit();
    
    /**
     * Test mode configuration for development/testing.
     */
    private TestMode testMode = new TestMode();
    
    @Getter
    @Setter
    public static class RateLimit {
        /**
         * Maximum OTP requests per phone number per hour.
         */
        private int requestsPerHour = 5;
        
        /**
         * Cooldown period between OTP requests in seconds.
         */
        private int cooldownSeconds = 60;
    }
    
    @Getter
    @Setter
    public static class TestMode {
        /**
         * Enable test mode - OTP will be logged instead of sent via SMS.
         */
        private boolean enabled = false;
        
        /**
         * Mock OTP that will always be accepted in test mode.
         */
        private String mockOtp = "123456";
        
        /**
         * Log OTP to console in test mode.
         */
        private boolean logOtp = true;
    }
    
    /**
     * Check if OTP should be skipped entirely.
     */
    public boolean shouldSkipOtp() {
        return !enabled;
    }
    
    /**
     * Check if running in test mode.
     */
    public boolean isTestMode() {
        return enabled && testMode.isEnabled();
    }
}
