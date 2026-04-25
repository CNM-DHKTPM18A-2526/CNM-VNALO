package iuh.cnm.vnalo.notification_service.redis;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.notification_service.model.dto.CreateNotificationRequest;
import iuh.cnm.vnalo.notification_service.service.NotificationService;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class CallOfflineRedisSubscriber implements MessageListener {

    private static final String CALL_OFFLINE_CHANNEL = "CALL_OFFLINE";
    private static final String EVENT_CALL_OFFER = "call.offer";

    private final RedisMessageListenerContainer listenerContainer;
    private final NotificationService notificationService;
    private final ObjectMapper objectMapper;

    @PostConstruct
    public void subscribe() {
        listenerContainer.addMessageListener(this, new ChannelTopic(CALL_OFFLINE_CHANNEL));
        log.info("Subscribed to Redis channel {}", CALL_OFFLINE_CHANNEL);
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            String raw = new String(message.getBody());
            JsonNode envelope = objectMapper.readTree(raw);
            String event = envelope.path("event").asText("");
            if (!EVENT_CALL_OFFER.equals(event)) {
                return;
            }

            String targetUserIdRaw = envelope.path("targetUserId").asText(null);
            if (targetUserIdRaw == null || targetUserIdRaw.isBlank()) {
                log.warn("CALL_OFFLINE payload missing targetUserId: {}", raw);
                return;
            }

            UUID targetUserId = UUID.fromString(targetUserIdRaw);
            JsonNode payload = envelope.path("payload");
            String callerId = payload.path("senderUserId").asText("Unknown");
            String callId = payload.path("callId").asText("");
            String conversationId = payload.path("conversationId").asText("");

            CreateNotificationRequest request = new CreateNotificationRequest();
            request.setUserId(targetUserId);
            request.setType("CALL_OFFLINE");
            request.setTitle("Cuộc gọi đến");
            request.setBody("Bạn có cuộc gọi đến trên VNALO");
            request.setData(objectMapper.createObjectNode()
                    .put("type", "call_offer")
                    .put("callId", callId)
                    .put("conversationId", conversationId)
                    .put("senderUserId", callerId));

            notificationService.send(request);
            log.info("Processed CALL_OFFLINE for targetUserId={} callId={}", targetUserId, callId);
        } catch (Exception ex) {
            log.error("Failed to process CALL_OFFLINE Redis message", ex);
        }
    }
}
