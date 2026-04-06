package iuh.cnm.vnalo.analytics_service.service;

import iuh.cnm.vnalo.analytics_service.model.dto.response.BackfillJobResponse;
import iuh.cnm.vnalo.analytics_service.model.entity.BackfillJob;
import iuh.cnm.vnalo.analytics_service.model.enums.BackfillJobStatus;
import iuh.cnm.vnalo.analytics_service.repository.BackfillJobRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class BackfillJobService {
    private final BackfillJobRepository backfillJobRepository;
    private final DailyMetricAggregationService aggregationService;
    private final AnalyticsCacheInvalidationService cacheInvalidationService;
    private final MeterRegistry meterRegistry;

    public BackfillJobResponse runBackfill(LocalDate from, LocalDate to) {
        BackfillJob job = loadOrCreateJob(from, to);

        if (job.getStatus() == BackfillJobStatus.COMPLETED) {
            meterRegistry.counter("analytics.backfill.jobs.reused").increment();
            return toResponse(job);
        }

        if (job.getStatus() == BackfillJobStatus.FAILED) {
            job = reopenJob(job.getId());
        }

        Instant attemptStartedAt = Instant.now();
        Timer.Sample attemptTimer = Timer.start(meterRegistry);
        meterRegistry.counter("analytics.backfill.jobs.started").increment();
        log.info("backfill_job_started jobId={} fromDate={} toDate={} totalDays={} processedDays={} resumed={}",
                job.getId(), from, to, job.getTotalDays(), job.getProcessedDays(), job.getProcessedDays() > 0);

        try {
            int processedDays = job.getProcessedDays();
            LocalDate cursor = from.plusDays(processedDays);
            while (!cursor.isAfter(to)) {
                aggregationService.aggregateForDate(cursor);
                processedDays++;
                updateProgress(job.getId(), processedDays);
                meterRegistry.counter("analytics.backfill.days.processed").increment();
                log.info("backfill_job_progress jobId={} processedDays={}/{} currentDate={}",
                        job.getId(), processedDays, job.getTotalDays(), cursor);
                cursor = cursor.plusDays(1);
            }

            BackfillJobResponse response = completeJob(job.getId());
                cacheInvalidationService.invalidateReadCaches("backfill_completed");
            meterRegistry.counter("analytics.backfill.jobs.completed").increment();
            attemptTimer.stop(Timer.builder("analytics.backfill.duration")
                    .tag("outcome", "completed")
                    .register(meterRegistry));
            log.info("backfill_job_completed jobId={} fromDate={} toDate={} processedDays={} durationMs={}",
                    job.getId(), from, to, response.getProcessedDays(), Duration.between(attemptStartedAt, Instant.now()).toMillis());
            return response;
        } catch (RuntimeException exception) {
            failJob(job.getId(), exception.getMessage());
            meterRegistry.counter("analytics.backfill.jobs.failed").increment();
            attemptTimer.stop(Timer.builder("analytics.backfill.duration")
                    .tag("outcome", "failed")
                    .register(meterRegistry));
            log.warn("backfill_job_failed jobId={} fromDate={} toDate={} processedDays={} error={}",
                    job.getId(), from, to, job.getProcessedDays(), exception.getMessage());
            throw exception;
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    protected BackfillJob loadOrCreateJob(LocalDate from, LocalDate to) {
        Optional<BackfillJob> existingJob = backfillJobRepository.findFirstByFromDateAndToDateOrderByStartedAtDesc(from, to);
        if (existingJob.isPresent()) {
            return existingJob.get();
        }

        BackfillJob job = BackfillJob.builder()
                .fromDate(from)
                .toDate(to)
                .status(BackfillJobStatus.RUNNING)
                .totalDays((int) ChronoUnit.DAYS.between(from, to) + 1)
                .processedDays(0)
                .build();
        return backfillJobRepository.saveAndFlush(job);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    protected BackfillJob reopenJob(java.util.UUID jobId) {
        BackfillJob job = backfillJobRepository.findById(jobId).orElseThrow();
        job.setStatus(BackfillJobStatus.RUNNING);
        job.setErrorMessage(null);
        job.setFinishedAt(null);
        return backfillJobRepository.saveAndFlush(job);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    protected void updateProgress(java.util.UUID jobId, int processedDays) {
        BackfillJob job = backfillJobRepository.findById(jobId).orElseThrow();
        job.setProcessedDays(processedDays);
        backfillJobRepository.saveAndFlush(job);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    protected BackfillJobResponse completeJob(java.util.UUID jobId) {
        BackfillJob job = backfillJobRepository.findById(jobId).orElseThrow();
        job.setStatus(BackfillJobStatus.COMPLETED);
        job.setProcessedDays(job.getTotalDays());
        job.setFinishedAt(java.time.Instant.now());
        backfillJobRepository.saveAndFlush(job);
        return toResponse(job);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    protected void failJob(java.util.UUID jobId, String errorMessage) {
        BackfillJob job = backfillJobRepository.findById(jobId).orElseThrow();
        job.setStatus(BackfillJobStatus.FAILED);
        job.setErrorMessage(errorMessage);
        job.setFinishedAt(java.time.Instant.now());
        backfillJobRepository.saveAndFlush(job);
    }

    private BackfillJobResponse toResponse(BackfillJob job) {
        return BackfillJobResponse.builder()
                .jobId(job.getId())
                .fromDate(job.getFromDate())
                .toDate(job.getToDate())
                .status(job.getStatus())
                .totalDays(job.getTotalDays())
                .processedDays(job.getProcessedDays())
                .startedAt(job.getStartedAt())
                .finishedAt(job.getFinishedAt())
                .errorMessage(job.getErrorMessage())
                .build();
    }
}