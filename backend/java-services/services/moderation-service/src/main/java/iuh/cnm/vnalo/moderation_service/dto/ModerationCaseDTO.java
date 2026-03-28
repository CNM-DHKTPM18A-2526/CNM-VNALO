package iuh.cnm.vnalo.moderation_service.dto;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ModerationCaseDTO {
    private UUID id;
    private UUID reportId;
    private String moderatorId;
    private ModerationCaseStatus status;
    private ModerationDecision decision;
    private Instant assignedAt;
    private Instant resolvedAt;
    private String notes;
}