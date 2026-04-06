package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.entity.BackfillJob;
import iuh.cnm.vnalo.analytics_service.model.enums.BackfillJobStatus;
import iuh.cnm.vnalo.analytics_service.repository.BackfillJobRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@SpringBootTest
@ActiveProfiles("test")
@Import(BackfillJobServiceIntegrationTest.MetricsTestConfig.class)
class BackfillJobServiceIntegrationTest {

    @Autowired
    private BackfillJobService backfillJobService;

    @Autowired
    private BackfillJobRepository backfillJobRepository;

    @Autowired
    private MeterRegistry meterRegistry;

    @MockBean
    private DailyMetricAggregationService aggregationService;

    @MockBean
    private AnalyticsCacheInvalidationService cacheInvalidationService;

    @BeforeEach
    void cleanUp() {
        backfillJobRepository.deleteAll();
        ((SimpleMeterRegistry) meterRegistry).clear();
    }

    @Test
    void runBackfill_shouldPersistCompletedJobWithProgress() {
        var response = backfillJobService.runBackfill(LocalDate.of(2026, 3, 16), LocalDate.of(2026, 3, 18));

        assertThat(response.getStatus()).isEqualTo(BackfillJobStatus.COMPLETED);
        assertThat(response.getTotalDays()).isEqualTo(3);
        assertThat(response.getProcessedDays()).isEqualTo(3);

        Optional<BackfillJob> savedJob = backfillJobRepository.findById(response.getJobId());
        assertThat(savedJob).isPresent();
        assertThat(savedJob.get().getStatus()).isEqualTo(BackfillJobStatus.COMPLETED);
        assertThat(savedJob.get().getProcessedDays()).isEqualTo(3);
        verify(aggregationService, times(3)).aggregateForDate(any(LocalDate.class));

        assertThat(counterValue("analytics.backfill.jobs.started")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.jobs.completed")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.jobs.failed")).isEqualTo(0.0);
        assertThat(counterValue("analytics.backfill.days.processed")).isEqualTo(3.0);
        assertThat(timerCount("analytics.backfill.duration", "outcome", "completed")).isEqualTo(1L);
        verify(cacheInvalidationService).invalidateReadCaches("backfill_completed");
    }

    @Test
    void runBackfill_shouldResumeFailedJobFromNextDay() {
        org.mockito.Mockito.doNothing()
                .doThrow(new RuntimeException("boom"))
                .doNothing()
                .doNothing()
                .when(aggregationService).aggregateForDate(any(LocalDate.class));

        try {
            backfillJobService.runBackfill(LocalDate.of(2026, 3, 16), LocalDate.of(2026, 3, 18));
        } catch (RuntimeException ignored) {
        }

        BackfillJob failedJob = backfillJobRepository.findAll().get(0);
        assertThat(failedJob.getStatus()).isEqualTo(BackfillJobStatus.FAILED);
        assertThat(failedJob.getProcessedDays()).isEqualTo(1);

        var retriedResponse = backfillJobService.runBackfill(LocalDate.of(2026, 3, 16), LocalDate.of(2026, 3, 18));

        assertThat(retriedResponse.getJobId()).isEqualTo(failedJob.getId());
        assertThat(retriedResponse.getStatus()).isEqualTo(BackfillJobStatus.COMPLETED);
        assertThat(retriedResponse.getProcessedDays()).isEqualTo(3);

        BackfillJob savedJob = backfillJobRepository.findById(failedJob.getId()).orElseThrow();
        assertThat(savedJob.getStatus()).isEqualTo(BackfillJobStatus.COMPLETED);
        assertThat(savedJob.getErrorMessage()).isNull();
        assertThat(savedJob.getProcessedDays()).isEqualTo(3);

        List<LocalDate> invokedDates = org.mockito.Mockito.mockingDetails(aggregationService)
                .getInvocations()
                .stream()
                .map(invocation -> (LocalDate) invocation.getArgument(0))
                .toList();
        assertThat(invokedDates).containsExactly(
                LocalDate.of(2026, 3, 16),
                LocalDate.of(2026, 3, 17),
                LocalDate.of(2026, 3, 17),
                LocalDate.of(2026, 3, 18)
        );
        assertThat(backfillJobRepository.count()).isEqualTo(1);
        assertThat(counterValue("analytics.backfill.jobs.started")).isEqualTo(2.0);
        assertThat(counterValue("analytics.backfill.jobs.completed")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.jobs.failed")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.days.processed")).isEqualTo(3.0);
        assertThat(timerCount("analytics.backfill.duration", "outcome", "failed")).isEqualTo(1L);
        assertThat(timerCount("analytics.backfill.duration", "outcome", "completed")).isEqualTo(1L);
        verify(cacheInvalidationService).invalidateReadCaches("backfill_completed");
    }

    @Test
    void runBackfill_shouldReturnExistingCompletedJobWithoutReprocessing() {
        var firstResponse = backfillJobService.runBackfill(LocalDate.of(2026, 3, 16), LocalDate.of(2026, 3, 18));
        var secondResponse = backfillJobService.runBackfill(LocalDate.of(2026, 3, 16), LocalDate.of(2026, 3, 18));

        assertThat(secondResponse.getJobId()).isEqualTo(firstResponse.getJobId());
        assertThat(secondResponse.getStatus()).isEqualTo(BackfillJobStatus.COMPLETED);
        assertThat(secondResponse.getProcessedDays()).isEqualTo(3);
        assertThat(backfillJobRepository.count()).isEqualTo(1);
        verify(aggregationService, times(3)).aggregateForDate(any(LocalDate.class));
        assertThat(counterValue("analytics.backfill.jobs.started")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.jobs.reused")).isEqualTo(1.0);
        assertThat(counterValue("analytics.backfill.days.processed")).isEqualTo(3.0);
        verify(cacheInvalidationService, times(1)).invalidateReadCaches("backfill_completed");
    }

    private double counterValue(String name) {
        Counter counter = meterRegistry.find(name).counter();
        return counter == null ? 0.0 : counter.count();
    }

    private long timerCount(String name, String tagKey, String tagValue) {
        Timer timer = meterRegistry.find(name).tag(tagKey, tagValue).timer();
        return timer == null ? 0L : timer.count();
    }

    @TestConfiguration
    static class MetricsTestConfig {
        @Bean
        @Primary
        MeterRegistry meterRegistry() {
            return new SimpleMeterRegistry();
        }
    }
}