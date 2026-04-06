package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsDailyMetric;
import iuh.cnm.vnalo.analytics_service.model.entity.AnalyticsEvent;
import iuh.cnm.vnalo.analytics_service.model.entity.BackfillJob;
import iuh.cnm.vnalo.analytics_service.model.enums.AnalyticsEventType;
import iuh.cnm.vnalo.analytics_service.model.enums.BackfillJobStatus;
import iuh.cnm.vnalo.analytics_service.model.enums.MetricKey;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsDailyMetricRepository;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsEventRepository;
import iuh.cnm.vnalo.analytics_service.repository.BackfillJobRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;

import java.time.Instant;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "analytics.retention.enabled=true",
        "analytics.retention.events-days=30",
        "analytics.retention.daily-metrics-days=365",
        "analytics.retention.backfill-jobs-days=60"
})
class AnalyticsDataRetentionServiceIntegrationTest {

    @Autowired
    private AnalyticsDataRetentionService retentionService;

    @Autowired
    private AnalyticsEventRepository analyticsEventRepository;

    @Autowired
    private AnalyticsDailyMetricRepository analyticsDailyMetricRepository;

    @Autowired
    private BackfillJobRepository backfillJobRepository;

    @BeforeEach
    void cleanUp() {
        backfillJobRepository.deleteAll();
        analyticsDailyMetricRepository.deleteAll();
        analyticsEventRepository.deleteAll();
    }

    @Test
    void purgeExpiredData_shouldDeleteOnlyExpiredRecords() {
        Instant now = Instant.parse("2026-04-05T00:00:00Z");

        AnalyticsEvent oldEvent = AnalyticsEvent.builder()
                .eventType(AnalyticsEventType.MESSAGE_SENT)
                .sourceService("core-service")
                .occurredAt(now.minusSeconds(31L * 24 * 60 * 60))
                .payloadJson("{}")
                .build();
        AnalyticsEvent freshEvent = AnalyticsEvent.builder()
                .eventType(AnalyticsEventType.MESSAGE_SENT)
                .sourceService("core-service")
                .occurredAt(now.minusSeconds(5L * 24 * 60 * 60))
                .payloadJson("{}")
                .build();
        analyticsEventRepository.save(oldEvent);
        analyticsEventRepository.save(freshEvent);

        AnalyticsDailyMetric oldMetric = AnalyticsDailyMetric.builder()
                .metricDate(LocalDate.of(2024, 4, 4))
                .metricKey(MetricKey.MESSAGES_SENT)
                .dimensionKey(null)
                .dimensionValue(null)
                .metricValue(10L)
                .build();
        AnalyticsDailyMetric freshMetric = AnalyticsDailyMetric.builder()
                .metricDate(LocalDate.of(2026, 4, 1))
                .metricKey(MetricKey.MESSAGES_SENT)
                .dimensionKey(null)
                .dimensionValue(null)
                .metricValue(15L)
                .build();
        analyticsDailyMetricRepository.save(oldMetric);
        analyticsDailyMetricRepository.save(freshMetric);

        BackfillJob oldJob = BackfillJob.builder()
                .fromDate(LocalDate.of(2025, 1, 1))
                .toDate(LocalDate.of(2025, 1, 2))
                .status(BackfillJobStatus.COMPLETED)
                .totalDays(2)
                .processedDays(2)
                .finishedAt(now.minusSeconds(61L * 24 * 60 * 60))
                .build();
        BackfillJob freshJob = BackfillJob.builder()
                .fromDate(LocalDate.of(2026, 4, 1))
                .toDate(LocalDate.of(2026, 4, 2))
                .status(BackfillJobStatus.COMPLETED)
                .totalDays(2)
                .processedDays(2)
                .finishedAt(now.minusSeconds(10L * 24 * 60 * 60))
                .build();
        backfillJobRepository.save(oldJob);
        backfillJobRepository.save(freshJob);

        retentionService.purgeExpiredData(now);

        assertThat(analyticsEventRepository.count()).isEqualTo(1);
        assertThat(analyticsDailyMetricRepository.count()).isEqualTo(1);
        assertThat(backfillJobRepository.count()).isEqualTo(1);
        assertThat(analyticsEventRepository.findAll().get(0).getOccurredAt()).isEqualTo(freshEvent.getOccurredAt());
        assertThat(analyticsDailyMetricRepository.findAll().get(0).getMetricDate()).isEqualTo(freshMetric.getMetricDate());
        assertThat(backfillJobRepository.findAll().get(0).getFromDate()).isEqualTo(freshJob.getFromDate());
    }
}