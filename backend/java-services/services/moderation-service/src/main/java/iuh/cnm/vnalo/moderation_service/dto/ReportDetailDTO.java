package iuh.cnm.vnalo.moderation_service.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportDetailDTO {
    private ReportDTO report;
    private ModerationCaseDTO moderationCase;
    private List<ModerationActionDTO> actions;
}