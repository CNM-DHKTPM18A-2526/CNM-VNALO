package iuh.cnm.vnalo.moderation_service.model.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class AssignCaseRequest {
    @NotNull
    private UUID moderatorId;
}