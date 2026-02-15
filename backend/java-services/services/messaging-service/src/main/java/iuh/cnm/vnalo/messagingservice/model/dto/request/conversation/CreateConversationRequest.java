package iuh.cnm.vnalo.messagingservice.model.dto.request.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
public class CreateConversationRequest {

    @NotNull(message = "Conversation type is required")
    private ConversationType type;

    @Size(max = 100, message = "Title must not exceed 100 characters")
    private String title;

    private String avatarUrl;

    @Size(max = 500, message = "Description must not exceed 500 characters")
    private String description;

    @NotNull(message = "Member IDs are required")
    @Size(min = 1, message = "At least one member is required")
    private List<UUID> memberIds;
}
