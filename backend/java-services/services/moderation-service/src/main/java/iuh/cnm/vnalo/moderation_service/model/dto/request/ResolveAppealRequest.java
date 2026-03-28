package iuh.cnm.vnalo.moderation_service.model.dto.request;

import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResolveAppealRequest {
    @NotNull
    private AppealStatus status;

    private String response;
}