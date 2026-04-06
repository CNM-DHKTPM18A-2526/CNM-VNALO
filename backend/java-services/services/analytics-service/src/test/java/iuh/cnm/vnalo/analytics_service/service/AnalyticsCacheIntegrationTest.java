package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.config.AnalyticsCacheNames;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.cache.CacheManager;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDate;

import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@SpringBootTest
@ActiveProfiles("test")
class AnalyticsCacheIntegrationTest {

    @Autowired
    private AnalyticsOverviewService overviewService;

    @Autowired
    private AnalyticsCacheInvalidationService cacheInvalidationService;

    @Autowired
    private CacheManager cacheManager;

    @MockBean
    private SharedUserAnalyticsQueryService userQueryService;

    @MockBean
    private SharedConversationAnalyticsQueryService conversationQueryService;

    @MockBean
    private SharedMessageAnalyticsQueryService messageQueryService;

    @MockBean
    private SharedModerationAnalyticsQueryService moderationQueryService;

    @BeforeEach
    void setUp() {
        clearCaches();
        when(userQueryService.countRegisteredUsers(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any())).thenReturn(10L);
        when(conversationQueryService.countCreatedConversations(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any())).thenReturn(5L);
        when(messageQueryService.countMessagesSent(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any())).thenReturn(50L);
        when(moderationQueryService.countReports(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any())).thenReturn(2L);
        when(moderationQueryService.countModerationActions(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any())).thenReturn(1L);
    }

    @Test
    void getOverview_shouldUseCacheForSameDateRange() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 31);

        overviewService.getOverview(from, to);
        overviewService.getOverview(from, to);

        verify(userQueryService, times(1)).countRegisteredUsers(from, to);
        verify(conversationQueryService, times(1)).countCreatedConversations(from, to);
        verify(messageQueryService, times(1)).countMessagesSent(from, to);
        verify(moderationQueryService, times(1)).countReports(from, to);
        verify(moderationQueryService, times(1)).countModerationActions(from, to);
    }

    @Test
    void invalidateReadCaches_shouldForceOverviewRecompute() {
        LocalDate from = LocalDate.of(2026, 3, 1);
        LocalDate to = LocalDate.of(2026, 3, 31);

        overviewService.getOverview(from, to);
        cacheInvalidationService.invalidateReadCaches("test");
        overviewService.getOverview(from, to);

        verify(userQueryService, times(2)).countRegisteredUsers(from, to);
    }

    private void clearCaches() {
        var overviewCache = cacheManager.getCache(AnalyticsCacheNames.OVERVIEW);
        if (overviewCache != null) {
            overviewCache.clear();
        }
        var dashboardCache = cacheManager.getCache(AnalyticsCacheNames.DASHBOARD);
        if (dashboardCache != null) {
            dashboardCache.clear();
        }
    }
}
