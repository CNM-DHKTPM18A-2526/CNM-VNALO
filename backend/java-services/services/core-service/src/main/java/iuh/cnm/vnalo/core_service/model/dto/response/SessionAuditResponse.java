package iuh.cnm.vnalo.core_service.model.dto.response;

import java.time.Instant;
import java.util.UUID;

public record SessionAuditResponse(
        UUID auditId,
        UUID tokenId,
        String eventType,
        String sessionType,
        String trustLevel,
        String platform,
        String deviceId,
        String deviceName,
        String ipAddress,
        String detail,
        Instant createdAt
) {
}
