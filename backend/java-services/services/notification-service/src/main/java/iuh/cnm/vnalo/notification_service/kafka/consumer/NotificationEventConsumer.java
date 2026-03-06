package iuh.cnm.vnalo.notification_service.kafka.consumer;

import iuh.cnm.vnalo.notification_service.kafka.dto.NotificationEvent;
import iuh.cnm.vnalo.notification_service.model.dto.CreateNotificationRequest;
import iuh.cnm.vnalo.notification_service.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationEventConsumer {

    private final NotificationService notificationService;

    @KafkaListener(
            topics = "${vnalo.kafka.topics.notifications}",
            containerFactory = "notificationKafkaListenerContainerFactory"
    )
public void consume(NotificationEvent event, Acknowledgment ack) {
    try {
        log.info("Consume NotificationEvent eventId={} type={} userId={}",
                event.eventId(), event.eventType(), event.userId());

        CreateNotificationRequest req = new CreateNotificationRequest();
        req.setUserId(event.userId());
        req.setType(event.eventType());
        req.setTitle(event.title());
        req.setBody(event.body());
        req.setData(event.data());

        notificationService.send(req);

        // ✅ chỉ ACK khi xử lý thành công
        ack.acknowledge();
    } catch (Exception e) {
        log.error("Consume failed eventId={} error={}", event.eventId(), e.getMessage(), e);
        // ❌ không ACK -> để Kafka retry/DLT
        throw e;
    }
}
}