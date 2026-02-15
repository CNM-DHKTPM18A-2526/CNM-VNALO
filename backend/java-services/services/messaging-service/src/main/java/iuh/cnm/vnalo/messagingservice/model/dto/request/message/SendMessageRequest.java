package iuh.cnm.vnalo.messagingservice.model.dto.request.message;

import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class SendMessageRequest {

    @NotNull(message = "Conversation ID is required")
    private UUID conversationId;

    @NotNull(message = "Message type is required")
    private MessageType type;

    private String content;

    private UUID replyToMessageId;

    private String attachments; // JSON string for simplicity in MVP
}
