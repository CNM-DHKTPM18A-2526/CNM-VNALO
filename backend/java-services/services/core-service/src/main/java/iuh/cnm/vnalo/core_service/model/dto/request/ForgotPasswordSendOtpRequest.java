package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for forgot password OTP sending.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ForgotPasswordSendOtpRequest {

    @NotBlank(message = "Phone number is required")
    @Pattern(regexp = "^\\+[1-9]\\d{9,14}$", message = "Invalid phone number format. Must include country code (e.g., +84123456789)")
    private String phone;
}
