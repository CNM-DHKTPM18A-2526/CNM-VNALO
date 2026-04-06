package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Email;

/**
 * DTO for initiating a password reset — sends OTP to the registered phone.
 */
public record ForgotPasswordRequest(
        @NotBlank(message = "Email is required")
        @Email(message = "Email must be valid")
        String email
) {}
