package iuh.cnm.vnalo.moderation_service.mapper;

import iuh.cnm.vnalo.moderation_service.dto.ModerationActionDTO;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAction;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;

@Component
public class ModerationActionMapper {

    public ModerationActionDTO toDTO(ModerationAction entity) {
        if (entity == null) {
            return null;
        }
        return ModerationActionDTO.builder()
                .id(entity.getId())
                .actionType(entity.getActionType())
                .reason(entity.getReason())
                .moderatorId(entity.getCreatedBy())
                .createdAt(entity.getCreatedAt())
                .build();
    }

    public List<ModerationActionDTO> toDTOList(List<ModerationAction> entities) {
        if (entities == null) {
            return Collections.emptyList();
        }
        return entities.stream().map(this::toDTO).toList();
    }
}
