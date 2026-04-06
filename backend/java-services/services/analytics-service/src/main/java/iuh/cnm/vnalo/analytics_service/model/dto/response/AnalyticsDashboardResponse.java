package iuh.cnm.vnalo.analytics_service.model.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Builder
@Getter
public class AnalyticsDashboardResponse {
    private AnalyticsOverviewResponse overview;
    private ActiveUserSummaryResponse activeUsers;
    private List<DailyTrendPointResponse> messagesPerDay;
    private List<DailyTrendPointResponse> mediaPerDay;
    private List<DailyTrendPointResponse> groupsPerDay;
    private List<TopActiveUserResponse> topActiveUsers;
}
