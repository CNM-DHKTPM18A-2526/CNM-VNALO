package iuh.cnm.vnalo.moderation_service.mapper;

import iuh.cnm.vnalo.moderation_service.dto.ReportDTO;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.UUID;

@Component
public class ReportMapper {

    public ReportDTO toDTO(ModerationReport entity) {
        if (entity == null) {
            return null;
        }
        return ReportDTO.builder()
                .id(entity.getId())
                .targetType(entity.getTargetType())
                .targetId(entity.getTargetId())
                .reporterId(entity.getReporterUserId())
                .reason(entity.getReasonCode())
                .description(entity.getDescription())
                .evidence(Collections.emptyList())
                .status(entity.getStatus())
                .createdAt(entity.getCreatedAt())
                .updatedAt(null)
                .build();
    }

    public ReportDTO toDTO(ModerationReport entity, List<String> evidence) {
        if (entity == null) {
            return null;
        }
        return ReportDTO.builder()
                .id(entity.getId())
                .targetType(entity.getTargetType())
                .targetId(entity.getTargetId())
                .reporterId(entity.getReporterUserId())
                .reason(entity.getReasonCode())
                .description(entity.getDescription())
                .evidence(evidence != null ? evidence : Collections.emptyList())
                .status(entity.getStatus())
                .createdAt(entity.getCreatedAt())
                .updatedAt(null)
                .build();
    }

    public List<ReportDTO> toDTOList(List<ModerationReport> entities) {
        if (entities == null) {
            return Collections.emptyList();
        }
        return entities.stream().map(this::toDTO).toList();
    }
}
