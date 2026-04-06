package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.config.AnalyticsRetentionProperties;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsDailyMetricRepository;
import iuh.cnm.vnalo.analytics_service.repository.AnalyticsEventRepository;
import iuh.cnm.vnalo.analytics_service.repository.BackfillJobRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
@Slf4j
public class AnalyticsDataRetentionService {
    private final AnalyticsRetentionProperties retentionProperties;
    private final AnalyticsEventRepository analyticsEventRepository;
    private final AnalyticsDailyMetricRepository analyticsDailyMetricRepository;
    private final BackfillJobRepository backfillJobRepository;

    @Transactional
    public void purgeExpiredData(Instant now) {
        if (!retentionProperties.isEnabled()) {
            log.info("analytics_retention_cleanup_skipped reason=disabled");
            return;
        }

        Instant eventCutoff = now.minusSeconds((long) retentionProperties.getEventsDays() * 24 * 60 * 60);
        LocalDate dailyMetricCutoff = LocalDate.ofInstant(now, ZoneOffset.UTC).minusDays(retentionProperties.getDailyMetricsDays());
        Instant backfillJobCutoff = now.minusSeconds((long) retentionProperties.getBackfillJobsDays() * 24 * 60 * 60);

        long deletedEvents = analyticsEventRepository.deleteByOccurredAtBefore(eventCutoff);
        long deletedDailyMetrics = analyticsDailyMetricRepository.deleteByMetricDateBefore(dailyMetricCutoff);
        long deletedBackfillJobs = backfillJobRepository.deleteByFinishedAtBefore(backfillJobCutoff);

        log.info(
                "analytics_retention_cleanup_done deletedEvents={} deletedDailyMetrics={} deletedBackfillJobs={} eventCutoff={} dailyMetricCutoff={} backfillJobCutoff={}",
                deletedEvents,
                deletedDailyMetrics,
                deletedBackfillJobs,
                eventCutoff,
                dailyMetricCutoff,
                backfillJobCutoff
        );
    }
}