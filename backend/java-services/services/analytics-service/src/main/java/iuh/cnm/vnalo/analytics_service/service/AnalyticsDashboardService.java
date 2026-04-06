package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.config.AnalyticsCacheNames;
import iuh.cnm.vnalo.analytics_service.model.dto.response.ActiveUserSummaryResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.AnalyticsDashboardResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.TopActiveUserResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AnalyticsDashboardService {
    private final SharedUserAnalyticsQueryService userQueryService;
    private final AnalyticsOverviewService overviewService;
    private final AnalyticsTrendService trendService;

    public ActiveUserSummaryResponse getActiveUserSummary(LocalDate from, LocalDate to) {
        return ActiveUserSummaryResponse.builder()
                .dau(userQueryService.countDistinctActiveUsers(to, to))
                .wau(userQueryService.countDistinctActiveUsers(to.minusDays(6), to))
                .mau(userQueryService.countDistinctActiveUsers(to.minusDays(29), to))
                .build();
    }

        @Cacheable(cacheNames = AnalyticsCacheNames.DASHBOARD,
            key = "#from.toString() + ':' + #to.toString() + ':' + #topLimit")
    public AnalyticsDashboardResponse getDashboard(LocalDate from, LocalDate to, int topLimit) {
        return AnalyticsDashboardResponse.builder()
                .overview(overviewService.getOverview(from, to))
                .activeUsers(getActiveUserSummary(from, to))
                .messagesPerDay(trendService.getMessageTrend(from, to))
                .mediaPerDay(trendService.getMediaTrend(from, to))
                .groupsPerDay(trendService.getGroupCreationTrend(from, to))
                .topActiveUsers(userQueryService.getTopActiveUsers(from, to, topLimit))
                .build();
    }

    public List<TopActiveUserResponse> getTopActiveUsers(LocalDate from, LocalDate to, int topLimit) {
        return userQueryService.getTopActiveUsers(from, to, topLimit);
    }
}
