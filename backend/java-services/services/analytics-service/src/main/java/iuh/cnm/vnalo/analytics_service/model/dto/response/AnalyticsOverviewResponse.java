package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

@Builder
@Getter
public class AnalyticsOverviewResponse {
    private long usersRegistered;
    private long conversationsCreated;
    private long messagesSent;
    private long reportsCreated;
    private long moderationActionsTaken;
}