package iuh.cnm.vnalo.messagingservice.model.dto.response.message;

import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.message.MessageType;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class MessageResponse {
    private UUID messageId;
    private UUID conversationId;
    private UUID senderId;
    private MessageType type;
    private String content;
    private UUID replyToMessageId;
    private String attachments;
    private MessageStatus status;
    private Boolean isDeleted;
    private Instant createdAt;
}
