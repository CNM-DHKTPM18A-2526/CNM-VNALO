package iuh.cnm.vnalo.messagingservice.model.dto.response.notification;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class NotificationResponse {
    private UUID notificationId;
    private String type;
    private String title;
    private String body;
    private String imageUrl;
    private String actionType;
    private String actionData;
    private Boolean isRead;
    private Instant readAt;
    private Instant createdAt;
}
