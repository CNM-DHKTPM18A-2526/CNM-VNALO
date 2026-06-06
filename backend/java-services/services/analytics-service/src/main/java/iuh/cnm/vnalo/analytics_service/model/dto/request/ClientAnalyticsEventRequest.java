package iuh.cnm.vnalo.analytics_service.model.dto.request;

import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.Map;

@Getter
@Setter
public class ClientAnalyticsEventRequest {
    @NotNull
    private AnalyticsEventType eventType;

    @Size(max = 64)
    private String sessionId;

    @Size(max = 32)
    private String platform;

    @Size(max = 120)
    private String screenName;

    @Size(max = 120)
    private String featureName;

    private Long durationMs;

    private Instant occurredAt;

    @Size(max = 40)
    private String appVersion;

    @Size(max = 40)
    private String locale;

    @Size(max = 24)
    private String timezone;

    private Map<String, Object> metadata;
}
