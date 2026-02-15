package iuh.cnm.vnalo.messagingservice.model.dto.request.call;

import iuh.cnm.vnalo.messagingservice.model.enums.call.CallType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class InitiateCallRequest {

    @NotNull(message = "Conversation ID is required")
    private UUID conversationId;

    @NotNull(message = "Call type is required")
    private CallType callType;

    private List<UUID> participantIds;
}
