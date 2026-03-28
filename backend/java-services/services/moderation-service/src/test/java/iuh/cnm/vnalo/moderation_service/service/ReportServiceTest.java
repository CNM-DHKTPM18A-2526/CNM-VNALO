package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateReportRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ReportResponse;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportPriority;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import iuh.cnm.vnalo.moderation_service.repository.ModerationActionRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportEvidenceRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReportServiceTest {

    @Mock
    private ModerationReportRepository reportRepository;

    @Mock
    private ModerationReportEvidenceRepository evidenceRepository;

    @Mock
    private ModerationCaseRepository caseRepository;

    @Mock
    private ModerationActionRepository actionRepository;

    @Mock
    private EvidenceSnapshotService evidenceSnapshotService;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private ModerationCaseService moderationCaseService;

    @InjectMocks
    private ReportService reportService;

    @Test
    void createReport_shouldCreateReportSuccessfully() {
        UUID reporterId = UUID.randomUUID();

        CreateReportRequest request = CreateReportRequest.builder()
                .targetType(ReportTargetType.USER)
                .targetId(UUID.randomUUID())
                .reasonCode("HARASSMENT")
                .description("Test report")
                .build();

        UUID reportId = UUID.randomUUID();
        UUID caseId = UUID.randomUUID();
        Instant createdAt = Instant.now();

        ModerationReport savedReport = ModerationReport.builder()
                .id(reportId)
                .reporterUserId(reporterId)
                .targetType(ReportTargetType.USER)
                .targetId(request.getTargetId())
                .reasonCode("HARASSMENT")
                .description("Test report")
                .status(ReportStatus.OPEN)
                .priority(ReportPriority.MEDIUM)
                .createdAt(createdAt)
                .build();

        ModerationCase savedCase = ModerationCase.builder()
                .id(caseId)
                .reportId(reportId)
                .status(ModerationCaseStatus.OPEN)
                .decision(ModerationDecision.PENDING)
                .createdAt(createdAt)
                .build();

        when(evidenceSnapshotService.buildSnapshot(any(), any())).thenReturn("{}");
        when(reportRepository.existsByReporterUserIdAndTargetTypeAndTargetIdAndReasonCodeAndCreatedAtAfter(
                any(), any(), any(), any(), any())).thenReturn(false);
        when(reportRepository.saveAndFlush(any())).thenReturn(savedReport);
        when(caseRepository.save(any())).thenReturn(savedCase);

        ReportResponse response = reportService.createReport(reporterId, request);

        assertThat(response).isNotNull();
        assertThat(response.getReportId()).isEqualTo(reportId);
        assertThat(response.getStatus()).isEqualTo(ReportStatus.OPEN);
        assertThat(response.getCaseId()).isEqualTo(caseId);
        assertThat(response.getCreatedAt()).isEqualTo(createdAt);
    }

    @Test
    void createReport_shouldThrowException_whenDuplicateReportExists() {
        UUID reporterId = UUID.randomUUID();

        CreateReportRequest request = CreateReportRequest.builder()
                .targetType(ReportTargetType.USER)
                .targetId(UUID.randomUUID())
                .reasonCode("HARASSMENT")
                .description("Test report")
                .build();

        when(reportRepository.existsByReporterUserIdAndTargetTypeAndTargetIdAndReasonCodeAndCreatedAtAfter(
                any(), any(), any(), any(), any())).thenReturn(true);

        assertThatThrownBy(() -> reportService.createReport(reporterId, request))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("already reported");
    }
}