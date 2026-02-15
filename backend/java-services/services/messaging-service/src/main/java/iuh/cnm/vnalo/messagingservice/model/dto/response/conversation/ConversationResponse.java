package iuh.cnm.vnalo.messagingservice.model.dto.response.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.conversation.ConversationType;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class ConversationResponse {
    private UUID conversationId;
    private ConversationType type;
    private String title;
    private String avatarUrl;
    private String description;
    private ConversationStatus status;
    private UUID createdBy;
    private Integer memberLimit;
    private Instant createdAt;
    private Instant updatedAt;
}
