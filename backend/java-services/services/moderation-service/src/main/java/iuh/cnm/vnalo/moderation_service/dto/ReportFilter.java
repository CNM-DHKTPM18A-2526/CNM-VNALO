package iuh.cnm.vnalo.moderation_service.dto;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
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
public class ReportFilter {
    private ReportTargetType targetType;
    private ReportStatus status;
    private UUID reporterId;
    private UUID targetId;
    private Instant createdAfter;
    private Instant createdBefore;
}