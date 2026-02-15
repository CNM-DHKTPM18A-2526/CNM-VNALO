package iuh.cnm.vnalo.messagingservice.model.dto.response.call;

import iuh.cnm.vnalo.messagingservice.model.enums.call.CallStatus;
import iuh.cnm.vnalo.messagingservice.model.enums.call.CallType;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class CallResponse {
    private UUID callId;
    private UUID conversationId;
    private CallType callType;
    private UUID initiatorId;
    private CallStatus status;
    private Instant startedAt;
    private Instant connectedAt;
    private Instant endedAt;
    private Integer durationSeconds;
    private String endReason;
    private List<CallParticipantResponse> participants;
}
