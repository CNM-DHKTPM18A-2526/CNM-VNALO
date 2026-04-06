package iuh.cnm.vnalo.analytics_service.scheduler;

import iuh.cnm.vnalo.analytics_service.service.AnalyticsCacheInvalidationService;
import iuh.cnm.vnalo.analytics_service.service.DailyMetricAggregationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.ZoneOffset;

@Component
@RequiredArgsConstructor
@Slf4j
public class DailyAggregationScheduler {
    private final DailyMetricAggregationService aggregationService;
    private final AnalyticsCacheInvalidationService cacheInvalidationService;

    @Scheduled(cron = "0 10 0 * * *")
    public void aggregateYesterday() {
        LocalDate targetDate = LocalDate.now(ZoneOffset.UTC).minusDays(1);
        log.info("daily_aggregation_scheduler_start targetDate={} timezone=UTC", targetDate);
        aggregationService.aggregateForDate(targetDate);
        cacheInvalidationService.invalidateReadCaches("daily_aggregation");
        log.info("daily_aggregation_scheduler_done targetDate={} timezone=UTC", targetDate);
    }
}