package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsDailyMetric;
import iuh.cnm.vnalo.analytics_service.model.enums.MetricKey;
import iuh.cnm.vnalo.analytics_service.query.SharedConversationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedMessageAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedModerationAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.query.SharedUserAnalyticsQueryService;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsDailyMetricRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
@RequiredArgsConstructor
public class DailyMetricAggregationService {
    private final AnalyticsDailyMetricRepository dailyMetricRepository;
    private final SharedUserAnalyticsQueryService userQueryService;
    private final SharedConversationAnalyticsQueryService conversationQueryService;
    private final SharedMessageAnalyticsQueryService messageQueryService;
    private final SharedModerationAnalyticsQueryService moderationQueryService;

    @Transactional
    public void aggregateForDate(LocalDate date) {
        upsert(date, MetricKey.USERS_REGISTERED, null, null,
                userQueryService.countRegisteredUsers(date, date));

        upsert(date, MetricKey.CONVERSATIONS_CREATED, null, null,
                conversationQueryService.countCreatedConversations(date, date));

        upsert(date, MetricKey.MESSAGES_SENT, null, null,
                messageQueryService.countMessagesSent(date, date));

        upsert(date, MetricKey.REPORTS_CREATED, null, null,
                moderationQueryService.countReports(date, date));

        upsert(date, MetricKey.MODERATION_ACTIONS_TAKEN, null, null,
                moderationQueryService.countModerationActions(date, date));
    }

    private void upsert(LocalDate date, MetricKey metricKey, String dimensionKey, String dimensionValue, long value) {
        AnalyticsDailyMetric metric = dailyMetricRepository
                .findByMetricDateAndMetricKeyAndDimensionKeyAndDimensionValue(date, metricKey, dimensionKey, dimensionValue)
                .orElse(
                        AnalyticsDailyMetric.builder()
                                .metricDate(date)
                                .metricKey(metricKey)
                                .dimensionKey(dimensionKey)
                                .dimensionValue(dimensionValue)
                                .build()
                );

        metric.setMetricValue(value);
        dailyMetricRepository.save(metric);
    }
}