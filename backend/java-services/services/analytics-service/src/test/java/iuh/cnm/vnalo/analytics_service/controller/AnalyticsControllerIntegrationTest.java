package iuh.cnm.vnalo.analytics_service.controller;

import iuh.cnm.vnalo.analytics_service.model.dto.response.ActiveUserSummaryResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.AnalyticsDashboardResponse;
import iuh.cnm.vnalo.analytics_service.model.dto.response.TopActiveUserResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsDashboardService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsOverviewService;
import iuh.cnm.vnalo.analytics_service.service.AnalyticsTrendService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@SpringBootTest
@ActiveProfiles("test")
class AnalyticsControllerIntegrationTest {

    @Autowired
    private AnalyticsDashboardService dashboardService;

    @MockBean
    private SharedUserAnalyticsQueryService userQueryService;

    @MockBean
    private AnalyticsOverviewService overviewService;

    @MockBean
    private AnalyticsTrendService trendService;

    @Test
    void getActiveUserSummary_shouldCalculateDauWauMauUsingQueryService() {
        when(userQueryService.countDistinctActiveUsers(eq(LocalDate.of(2026, 3, 18)), eq(LocalDate.of(2026, 3, 18))))
                .thenReturn(12L);
        when(userQueryService.countDistinctActiveUsers(eq(LocalDate.of(2026, 3, 12)), eq(LocalDate.of(2026, 3, 18))))
                .thenReturn(34L);
        when(userQueryService.countDistinctActiveUsers(eq(LocalDate.of(2026, 2, 17)), eq(LocalDate.of(2026, 3, 18))))
                .thenReturn(56L);

        ActiveUserSummaryResponse response = dashboardService.getActiveUserSummary(
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 18)
        );

        assertThat(response.getDau()).isEqualTo(12L);
        assertThat(response.getWau()).isEqualTo(34L);
        assertThat(response.getMau()).isEqualTo(56L);
    }

    @Test
    void getTopActiveUsers_shouldReturnQueryResults() {
        TopActiveUserResponse topUser = TopActiveUserResponse.builder()
                .userId(UUID.fromString("11111111-1111-1111-1111-111111111111"))
                .displayName("user-a")
                .messageCount(99)
                .build();

        when(userQueryService.getTopActiveUsers(any(LocalDate.class), any(LocalDate.class), eq(5)))
                .thenReturn(List.of(topUser));

        List<TopActiveUserResponse> response = dashboardService.getTopActiveUsers(
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 18),
                5
        );

        assertThat(response).hasSize(1);
        assertThat(response.get(0).getDisplayName()).isEqualTo("user-a");
        assertThat(response.get(0).getMessageCount()).isEqualTo(99L);
    }

    @Test
    void getDashboard_shouldReturnDashboardBundle() {
        ActiveUserSummaryResponse summary = ActiveUserSummaryResponse.builder().dau(10).wau(20).mau(30).build();
        AnalyticsDashboardResponse dashboard = AnalyticsDashboardResponse.builder()
                .activeUsers(summary)
                .topActiveUsers(List.of())
                .build();

        when(overviewService.getOverview(any(LocalDate.class), any(LocalDate.class))).thenReturn(null);
        when(userQueryService.countDistinctActiveUsers(any(LocalDate.class), any(LocalDate.class))).thenReturn(10L);
        when(userQueryService.getTopActiveUsers(any(LocalDate.class), any(LocalDate.class), eq(7))).thenReturn(List.of());
        when(trendService.getMessageTrend(any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());
        when(trendService.getMediaTrend(any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());
        when(trendService.getGroupCreationTrend(any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());

        AnalyticsDashboardResponse response = dashboardService.getDashboard(
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 18),
                7
        );

        assertThat(response).isNotNull();
        assertThat(response.getActiveUsers()).isNotNull();
        assertThat(response.getActiveUsers().getDau()).isEqualTo(10L);
        assertThat(response.getTopActiveUsers()).isEmpty();
    }
}
