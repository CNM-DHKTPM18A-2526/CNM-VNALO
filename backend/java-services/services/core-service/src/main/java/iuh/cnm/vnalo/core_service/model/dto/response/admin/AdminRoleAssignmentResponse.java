package iuh.cnm.vnalo.core_service.model.dto.response.admin;

import java.time.Instant;
import java.util.UUID;

public record AdminRoleAssignmentResponse(
        UUID accountId,
        String email,
        String roleCode,
        Instant grantedAt,
        UUID grantedBy,
        Instant expiresAt
) {}
