package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.ScopeType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class AccessScopeRequest {

    @NotNull(message = "Scope type is required")
    private ScopeType scopeType;

    @NotNull(message = "Scope ID is required")
    private UUID scopeId;
}
