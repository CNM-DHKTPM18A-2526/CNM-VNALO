package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Builder
@Getter
public class BehavioralAnalyticsSummaryResponse {
    private long eventsTotal;
    private long activeUsers;
    private long sessionsStarted;
    private long sessionsEnded;
    private long screenViews;
    private long featureUses;
    private long clientErrors;
    private long apiErrors;
    private long aiPrompts;
    private long aiFailures;
    private long faceAuthAttempts;
    private long activeUsersLast5Minutes;
    private long activeUsersLast30Minutes;
    private double averageSessionDurationMinutes;
    private double medianSessionDurationMinutes;
    private double p95SessionDurationMinutes;
    private List<EventCountResponse> topEvents;
    private List<EventCountResponse> topScreens;
    private List<EventCountResponse> topFeatures;
    private List<EventCountResponse> hourlyUsage;
}
