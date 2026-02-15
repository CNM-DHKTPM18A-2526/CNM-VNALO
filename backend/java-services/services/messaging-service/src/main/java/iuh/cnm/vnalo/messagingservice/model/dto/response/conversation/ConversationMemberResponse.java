package iuh.cnm.vnalo.messagingservice.model.dto.response.conversation;

import iuh.cnm.vnalo.messagingservice.model.enums.conversation.MemberRole;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class ConversationMemberResponse {
    private UUID userId;
    private MemberRole role;
    private String nickname;
    private Instant joinedAt;
}
