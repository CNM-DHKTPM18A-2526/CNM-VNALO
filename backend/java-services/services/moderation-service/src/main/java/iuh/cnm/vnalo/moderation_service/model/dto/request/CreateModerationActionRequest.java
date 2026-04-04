package iuh.cnm.vnalo.moderation_service.model.dto.request;

import iuh.cnm.vnalo.moderation_service.model.enums.ModerationActionType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

@Getter
@Setter
public class CreateModerationActionRequest {
    @NotNull
    private UUID caseId;

    @NotNull
    private ModerationActionType actionType;

    private UUID targetUserId;
    private UUID targetMessageId;
    private UUID targetConversationId;

    @Size(max = 1000)
    private String reason;
}