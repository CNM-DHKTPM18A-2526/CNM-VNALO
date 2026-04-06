package iuh.cnm.vnalo.analytics_service.scheduler;

import iuh.cnm.vnalo.analytics_service.service.AnalyticsCacheInvalidationService;
import iuh.cnm.vnalo.analytics_service.service.DailyMetricAggregationService;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.ZoneOffset;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class DailyAggregationSchedulerTest {

    @Test
    void aggregateYesterday_shouldCallAggregationForUtcYesterday() {
        DailyMetricAggregationService aggregationService = mock(DailyMetricAggregationService.class);
        AnalyticsCacheInvalidationService cacheInvalidationService = mock(AnalyticsCacheInvalidationService.class);
        DailyAggregationScheduler scheduler = new DailyAggregationScheduler(aggregationService, cacheInvalidationService);

        LocalDate expectedDate = LocalDate.now(ZoneOffset.UTC).minusDays(1);

        scheduler.aggregateYesterday();

        verify(aggregationService).aggregateForDate(expectedDate);
        verify(cacheInvalidationService).invalidateReadCaches("daily_aggregation");
    }
}
