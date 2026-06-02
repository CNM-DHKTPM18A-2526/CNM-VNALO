package iuh.cnm.vnalo.core_service.model.dto.request.admin;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record AdminRoleRevokeRequest(
        @NotBlank @Email String email,
        @NotBlank String roleCode
) {}
