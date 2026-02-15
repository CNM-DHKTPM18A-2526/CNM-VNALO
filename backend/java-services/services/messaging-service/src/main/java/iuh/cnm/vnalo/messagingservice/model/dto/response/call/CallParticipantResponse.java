package iuh.cnm.vnalo.messagingservice.model.dto.response.call;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class CallParticipantResponse {
    private UUID userId;
    private String role;
    private String status;
    private Instant joinedAt;
    private Instant leftAt;
    private Boolean isVideoEnabled;
    private Boolean isAudioEnabled;
    private Boolean isScreenSharing;
}
