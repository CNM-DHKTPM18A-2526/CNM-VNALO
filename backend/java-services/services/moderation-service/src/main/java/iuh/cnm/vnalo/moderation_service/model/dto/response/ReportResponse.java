package iuh.cnm.vnalo.moderation_service.model.dto.response;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import lombok.Builder;
import lombok.Getter;

import java.time.Instant;
import java.util.UUID;

@Builder
@Getter
public class ReportResponse {
    private UUID reportId;
    private ReportStatus status;
    private UUID caseId;
    private Instant createdAt;
}