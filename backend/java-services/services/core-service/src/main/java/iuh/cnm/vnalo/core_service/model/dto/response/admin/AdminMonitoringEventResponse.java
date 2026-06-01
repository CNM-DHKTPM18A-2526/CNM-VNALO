package iuh.cnm.vnalo.core_service.model.dto.response.admin;

import java.time.Instant;
import java.util.UUID;

public record AdminMonitoringEventResponse(
        UUID auditId,
        String eventType,
        String sessionType,
        String trustLevel,
        String platform,
        String deviceName,
        String deviceIdMasked,
        String detail,
        Instant createdAt
) {}
