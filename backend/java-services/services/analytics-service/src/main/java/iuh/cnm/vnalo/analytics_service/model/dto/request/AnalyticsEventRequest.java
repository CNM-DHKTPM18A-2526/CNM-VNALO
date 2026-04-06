package iuh.cnm.vnalo.analytics_service.model.dto.request;

import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Getter @Setter
public class AnalyticsEventRequest {
    @NotNull
    private AnalyticsEventType eventType;

    private UUID actorUserId;

    @Size(max = 30)
    private String targetType;

    private UUID targetId;

    @NotBlank
    @Size(max = 50)
    private String sourceService;

    @NotNull
    private Instant occurredAt;

    private String payloadJson;
}