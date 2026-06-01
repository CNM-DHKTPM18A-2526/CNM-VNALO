package iuh.cnm.vnalo.core_service.model.dto.response.admin;

import java.util.List;

public record AdminMonitoringEventPageResponse(
        int page,
        int limit,
        boolean hasMore,
        List<AdminMonitoringEventResponse> items
) {}