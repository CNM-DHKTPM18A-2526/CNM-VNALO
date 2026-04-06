package iuh.cnm.vnalo.analytics_service.scheduler;

import iuh.cnm.vnalo.analytics_service.service.AnalyticsDataRetentionService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
@RequiredArgsConstructor
public class AnalyticsRetentionScheduler {
    private final AnalyticsDataRetentionService retentionService;

    @Scheduled(cron = "${analytics.retention.cron:0 30 0 * * *}")
    public void purgeExpiredData() {
        retentionService.purgeExpiredData(Instant.now());
    }
}