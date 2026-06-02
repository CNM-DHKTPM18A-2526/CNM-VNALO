package iuh.cnm.vnalo.core_service.model.dto.request.admin;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public record AdminRoleGrantRequest(
        @NotBlank @Email String email,
        @NotBlank String roleCode,
        Instant expiresAt
) {}
