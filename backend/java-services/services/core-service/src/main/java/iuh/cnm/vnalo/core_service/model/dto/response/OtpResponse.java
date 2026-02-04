package iuh.cnm.vnalo.core_service.model.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Response DTO for OTP operations.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpResponse {
    
    /**
     * Whether OTP was sent successfully.
     */
    private boolean success;
    
    /**
     * Whether OTP verification was skipped (disabled in config).
     */
    private boolean skipped;
    
    /**
     * Human-readable message.
     */
    private String message;
    
    /**
     * Time until OTP expires (in seconds).
     */
    private int expiresInSeconds;
    
    /**
     * Cooldown time before next OTP request (in seconds).
     */
    private int cooldownSeconds;
    
    public static OtpResponse success(int expiresIn, int cooldown) {
        return OtpResponse.builder()
            .success(true)
            .skipped(false)
            .message("OTP sent successfully")
            .expiresInSeconds(expiresIn)
            .cooldownSeconds(cooldown)
            .build();
    }
    
    public static OtpResponse skipped(String reason) {
        return OtpResponse.builder()
            .success(true)
            .skipped(true)
            .message(reason)
            .expiresInSeconds(0)
            .cooldownSeconds(0)
            .build();
    }
}
