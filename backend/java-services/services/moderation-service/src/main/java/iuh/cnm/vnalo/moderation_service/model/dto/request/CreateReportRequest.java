package iuh.cnm.vnalo.moderation_service.model.dto.request;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Builder;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Builder
@Getter
@Setter
public class CreateReportRequest {

    @NotNull
    private ReportTargetType targetType;

    @NotNull
    private UUID targetId;

    @NotBlank
    @Size(max = 50)
    private String reasonCode;

    @Size(max = 1000)
    private String description;
}