package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotNull;

public record UpdateSyncPolicyRequest(
        @NotNull(message = "syncEnabled is required")
        Boolean syncEnabled
) {
}
