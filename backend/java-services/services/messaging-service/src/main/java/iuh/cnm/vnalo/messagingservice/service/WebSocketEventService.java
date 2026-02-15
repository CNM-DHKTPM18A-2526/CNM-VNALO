package iuh.cnm.vnalo.messagingservice.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;

/**
 * Service for pushing real-time events via WebSocket.
 * 
 * Topic patterns:
 * - /topic/conversation/{conversationId} — new messages, typing indicators, etc.
 * - /topic/user/{userId} — personal notifications, inbox updates, call events
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WebSocketEventService {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Send an event to all subscribers of a conversation topic.
     * Frontend subscribes: /topic/conversation/{conversationId}
     */
    public void sendToConversation(UUID conversationId, String eventType, Object payload) {
        String destination = "/topic/conversation/" + conversationId;
        Map<String, Object> event = Map.of(
                "type", eventType,
                "data", payload
        );
        messagingTemplate.convertAndSend(destination, event);
        log.debug("WS event [{}] sent to conversation {}", eventType, conversationId);
    }

    /**
     * Send an event to a specific user's personal topic.
     * Frontend subscribes: /topic/user/{userId}
     */
    public void sendToUser(UUID userId, String eventType, Object payload) {
        String destination = "/topic/user/" + userId;
        Map<String, Object> event = Map.of(
                "type", eventType,
                "data", payload
        );
        messagingTemplate.convertAndSend(destination, event);
        log.debug("WS event [{}] sent to user {}", eventType, userId);
    }
}
