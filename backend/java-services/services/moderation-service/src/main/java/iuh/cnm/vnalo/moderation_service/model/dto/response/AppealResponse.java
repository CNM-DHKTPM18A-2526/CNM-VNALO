package iuh.cnm.vnalo.moderation_service.model.dto.response;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAppeal;
import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class AppealResponse {
    private UUID id;
    private UUID caseId;
    private UUID userId;
    private String reason;
    private AppealStatus status;
    private String moderatorResponse;
    private UUID moderatorId;
    private Instant createdAt;
    private Instant updatedAt;

    public static AppealResponse from(ModerationAppeal appeal) {
        return AppealResponse.builder()
                .id(appeal.getId())
                .caseId(appeal.getCaseId())
                .userId(appeal.getUserId())
                .reason(appeal.getReason())
                .status(appeal.getStatus())
                .moderatorResponse(appeal.getModeratorResponse())
                .moderatorId(appeal.getModeratorId())
                .createdAt(appeal.getCreatedAt())
                .updatedAt(appeal.getUpdatedAt())
                .build();
    }
}