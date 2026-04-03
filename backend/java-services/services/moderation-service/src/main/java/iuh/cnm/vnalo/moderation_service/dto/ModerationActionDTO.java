package iuh.cnm.vnalo.moderation_service.dto;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationActionType;
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
public class ModerationActionDTO {
    private UUID id;
    private ModerationActionType actionType;
    private String reason;
    private UUID moderatorId;
    private Instant createdAt;
}