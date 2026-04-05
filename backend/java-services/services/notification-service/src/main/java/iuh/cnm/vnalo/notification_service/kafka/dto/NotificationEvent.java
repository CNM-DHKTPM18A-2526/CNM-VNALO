package iuh.cnm.vnalo.notification_service.kafka.dto;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.OffsetDateTime;
import java.util.UUID;

public record NotificationEvent(
        UUID eventId,
        String eventType,
        UUID userId,
        String title,
        String body,
        JsonNode data,
        OffsetDateTime createdAt
) {}