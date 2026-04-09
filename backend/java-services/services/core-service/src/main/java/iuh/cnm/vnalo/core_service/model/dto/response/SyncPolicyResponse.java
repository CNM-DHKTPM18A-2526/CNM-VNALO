package iuh.cnm.vnalo.core_service.model.dto.response;

import java.time.Instant;

public record SyncPolicyResponse(
        Boolean syncEnabled,
        Boolean webRestrictedMode,
        Instant updatedAt
) {
}
