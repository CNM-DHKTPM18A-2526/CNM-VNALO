package iuh.cnm.vnalo.moderation_service.model.dto.response;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import lombok.Builder;
import lombok.Getter;

import java.time.Instant;
import java.util.UUID;

@Builder
@Getter
public class ModerationCaseResponse {
    private UUID caseId;
    private ModerationCaseStatus status;
    private ModerationDecision decision;
    private UUID assignedModeratorId;
    private String note;
    private Instant resolvedAt;
}