package iuh.cnm.vnalo.core_service.model.dto.response.admin;

import java.time.Instant;

public record AdminMonitoringTrendPointResponse(
        Instant bucket,
        long total,
        long warning,
        long error
) {}