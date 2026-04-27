package iuh.cnm.vnalo.core_service.kafka.producer;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
@Slf4j
@RequiredArgsConstructor
public class KafkaProducerService {

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private static final String REALTIME_TOPIC = "vnalo.realtime.events";

    /**
     * Send a realtime event to Kafka to be consumed by the realtime-gateway.
     * 
     * @param userId The ID of the user to receive the event
     * @param type The event type (e.g., "friendship.updated")
     * @param payload The event data
     */
    public void sendRealtimeEvent(String userId, String type, Object payload) {
        try {
            Map<String, Object> event = Map.of(
                "type", type,
                "userId", userId,
                "payload", payload
            );
            
            log.info("Publishing realtime event to Kafka: type={}, userId={}", type, userId);
            kafkaTemplate.send(REALTIME_TOPIC, userId, event);
        } catch (Exception e) {
            log.error("Failed to publish realtime event to Kafka: {}", e.getMessage(), e);
        }
    }
}
