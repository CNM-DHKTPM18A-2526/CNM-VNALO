package iuh.cnm.vnalo.messagingservice.model.dto.response.conversation;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class ConversationInboxResponse {
    private UUID conversationId;
    private String title;
    private String avatarUrl;
    private String type;
    private String lastMessagePreview;
    private UUID lastMessageSenderId;
    private String lastMessageType;
    private Instant lastMessageAt;
    private Integer unreadCount;
    private Boolean isPinned;
    private Boolean isMuted;
    // For DIRECT conversations: the other member's userId (so frontend can look up name/avatar)
    private UUID otherMemberId;
}
