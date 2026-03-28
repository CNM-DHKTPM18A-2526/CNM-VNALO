package iuh.cnm.vnalo.moderation_service.model.dto.request;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ResolveCaseRequest {
    @NotNull
    private ModerationDecision decision;

    @Size(max = 1000)
    private String note;
}