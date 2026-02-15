package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.call.WebRTCSignal;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.Map;
import java.util.UUID;

/**
 * WebRTC signaling controller using STOMP WebSocket.
 *
 * Client sends signals to:   /app/call.signal
 * Server relays signals to:  /topic/user/{targetUserId}
 *
 * Flow:
 * 1. Caller sends OFFER → server relays to target user
 * 2. Callee sends ANSWER → server relays back to caller
 * 3. Both exchange ICE_CANDIDATE → server relays to peer
 * 4. Either sends HANGUP → server relays to peer
 */
@Controller
@RequiredArgsConstructor
@Slf4j
public class CallSignalingController {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Handle incoming WebRTC signaling messages from clients.
     * Clients send to: /app/call.signal
     */
    @MessageMapping("/call.signal")
    public void handleSignal(@Payload WebRTCSignal signal, Principal principal) {
        UUID senderId = UUID.fromString(principal.getName());
        UUID targetUserId = signal.getTargetUserId();

        log.debug("WebRTC signal [{}] from {} to {} for call {}",
                signal.getType(), senderId, targetUserId, signal.getCallId());

        // Relay the signal to the target user with sender info
        String destination = "/topic/user/" + targetUserId;
        Map<String, Object> event = Map.of(
                "type", "WEBRTC_SIGNAL",
                "data", Map.of(
                        "callId", signal.getCallId(),
                        "senderId", senderId,
                        "signalType", signal.getType().name(),
                        "payload", signal.getPayload() != null ? signal.getPayload() : ""
                )
        );

        messagingTemplate.convertAndSend(destination, event);
    }
}
