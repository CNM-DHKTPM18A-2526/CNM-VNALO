package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for OTP verification.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VerifyOtpRequest {

    /**
     * Phone number or email that received the OTP.
     */
    @NotBlank(message = "Target (phone/email) is required")
    private String target;

    /**
     * OTP code to verify.
     */
    @NotBlank(message = "OTP is required")
    private String otp;
}
