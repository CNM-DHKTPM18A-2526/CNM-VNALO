package iuh.cnm.vnalo.analytics_service.model.dto.response;

import iuh.cnm.vnalo.analytics_service.model.enums.BackfillJobStatus;
import lombok.Builder;
import lombok.Getter;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Builder
@Getter
public class BackfillJobResponse {
    private UUID jobId;
    private LocalDate fromDate;
    private LocalDate toDate;
    private BackfillJobStatus status;
    private int totalDays;
    private int processedDays;
    private Instant startedAt;
    private Instant finishedAt;
    private String errorMessage;
}