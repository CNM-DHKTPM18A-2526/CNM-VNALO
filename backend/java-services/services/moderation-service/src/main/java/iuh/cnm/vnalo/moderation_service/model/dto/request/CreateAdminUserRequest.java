package iuh.cnm.vnalo.moderation_service.model.dto.request;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationAdminRole;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class CreateAdminUserRequest {
    @NotNull
    private UUID userId;

    @NotNull
    private ModerationAdminRole role;
}