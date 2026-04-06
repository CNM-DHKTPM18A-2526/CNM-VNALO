package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.config.AnalyticsCacheNames;
import iuh.cnm.vnalo.analytics_service.model.dto.response.AnalyticsOverviewResponse;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.time.LocalDate;

@Service
@RequiredArgsConstructor
public class AnalyticsOverviewService {
    private final SharedUserAnalyticsQueryService userQueryService;
    private final SharedConversationAnalyticsQueryService conversationQueryService;
    private final SharedMessageAnalyticsQueryService messageQueryService;
    private final SharedModerationAnalyticsQueryService moderationQueryService;

    @Cacheable(cacheNames = AnalyticsCacheNames.OVERVIEW, key = "#from.toString() + ':' + #to.toString()")
    public AnalyticsOverviewResponse getOverview(LocalDate from, LocalDate to) {
        return AnalyticsOverviewResponse.builder()
                .usersRegistered(userQueryService.countRegisteredUsers(from, to))
                .conversationsCreated(conversationQueryService.countCreatedConversations(from, to))
                .messagesSent(messageQueryService.countMessagesSent(from, to))
                .reportsCreated(moderationQueryService.countReports(from, to))
                .moderationActionsTaken(moderationQueryService.countModerationActions(from, to))
                .build();
    }
}