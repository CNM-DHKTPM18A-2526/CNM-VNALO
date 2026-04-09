package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for user login.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LoginRequest {

    /**
     * Phone number or email address.
     */
    @NotBlank(message = "Phone or email is required")
    private String identifier;

    /**
     * User password.
     */
    @NotBlank(message = "Password is required")
    private String password;

    /**
     * Device ID for session management (optional).
     */
    private String deviceId;

    /**
     * Device name for display (optional).
     */
    private String deviceName;

    /**
     * Platform identifier (optional): WEB, ANDROID, IOS, PC.
     */
    private String platform;

    /**
     * Optional confirmation used by clients when replacing an active untrusted web session.
     */
    private Boolean confirmReplaceUntrustedWeb;
}
