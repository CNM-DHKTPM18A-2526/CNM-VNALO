package iuh.cnm.vnalo.messagingservice.model.dto.response.message;

import iuh.cnm.vnalo.messagingservice.model.enums.message.PollStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class PollResponse {
    private UUID pollId;
    private UUID conversationId;
    private String question;
    private List<PollOptionResponse> options;
    private Boolean allowMultipleVotes;
    private LocalDateTime expiresAt;
    private PollStatus status; // OPEN, CLOSED
    private UUID createdBy;
    private LocalDateTime createdAt;
    
    @Data
    @Builder
    public static class PollOptionResponse {
        private UUID optionId;
        private String optionText;
        private Integer voteCount;
        private Boolean isVotedByCurrentUser; // Helper for UI
    }
}
