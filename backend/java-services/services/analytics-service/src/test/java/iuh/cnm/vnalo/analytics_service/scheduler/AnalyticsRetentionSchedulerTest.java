package iuh.cnm.vnalo.analytics_service.scheduler;

import iuh.cnm.vnalo.analytics_service.service.AnalyticsDataRetentionService;
import org.junit.jupiter.api.Test;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class AnalyticsRetentionSchedulerTest {

    @Test
    void purgeExpiredData_shouldCallRetentionService() {
        AnalyticsDataRetentionService retentionService = mock(AnalyticsDataRetentionService.class);
        AnalyticsRetentionScheduler scheduler = new AnalyticsRetentionScheduler(retentionService);

        scheduler.purgeExpiredData();

        verify(retentionService).purgeExpiredData(any());
    }
}