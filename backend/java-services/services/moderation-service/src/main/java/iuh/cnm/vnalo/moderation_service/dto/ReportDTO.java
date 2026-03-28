package iuh.cnm.vnalo.moderation_service.dto;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportDTO {
    private UUID id;
    private ReportTargetType targetType;
    private UUID targetId;
    private UUID reporterId;
    private String reason;
    private String description;
    private List<String> evidence;
    private ReportStatus status;
    private Instant createdAt;
    private Instant updatedAt;
}