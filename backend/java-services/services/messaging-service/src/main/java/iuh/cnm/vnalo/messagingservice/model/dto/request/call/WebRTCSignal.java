package iuh.cnm.vnalo.messagingservice.model.dto.request.call;

import lombok.Data;

import java.util.UUID;

/**
 * WebRTC signaling messages exchanged via STOMP WebSocket.
 */
@Data
public class WebRTCSignal {

    public enum SignalType {
        OFFER,          // SDP offer from caller
        ANSWER,         // SDP answer from callee
        ICE_CANDIDATE,  // ICE candidate exchange
        HANGUP          // Call hangup signal
    }

    private UUID callId;
    private UUID targetUserId;
    private SignalType type;

    /**
     * SDP description (for OFFER/ANSWER) or ICE candidate JSON string.
     * For OFFER/ANSWER: contains the full SDP string.
     * For ICE_CANDIDATE: contains the ICE candidate JSON (candidate, sdpMid, sdpMLineIndex).
     */
    private String payload;
}
