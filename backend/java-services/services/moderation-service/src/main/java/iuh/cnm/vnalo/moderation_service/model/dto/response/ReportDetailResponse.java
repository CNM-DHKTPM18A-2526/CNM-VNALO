package iuh.cnm.vnalo.moderation_service.model.dto.response;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportPriority;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import lombok.Builder;
import lombok.Getter;

import java.util.UUID;

@Builder
@Getter
public class ReportDetailResponse {
    private UUID reportId;
    private UUID reporterUserId;
    private ReportTargetType targetType;
    private UUID targetId;
    private String reasonCode;
    private String description;
    private ReportStatus status;
    private ReportPriority priority;
    private String evidenceJson;
    private ModerationCaseResponse moderationCase;
}