package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateReportRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ReportResponse;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReportEvidence;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportEvidenceRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class ReportServiceIntegrationTest {

    @Autowired
    private ReportService reportService;

    @Autowired
    private ModerationReportRepository reportRepository;

    @Autowired
    private ModerationCaseRepository caseRepository;

    @Autowired
    private ModerationReportEvidenceRepository evidenceRepository;

    @MockBean
    private EvidenceSnapshotService evidenceSnapshotService;

    @Test
    void createReport_shouldPersistReportCaseAndEvidence() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();

        when(evidenceSnapshotService.buildSnapshot(any(), any()))
                .thenReturn("{\"targetId\":\"" + targetId + "\"}");

        CreateReportRequest request = CreateReportRequest.builder()
                .targetType(ReportTargetType.USER)
                .targetId(targetId)
                .reasonCode("HARASSMENT")
                .description("Integration test report")
                .build();

        ReportResponse response = reportService.createReport(reporterId, request);

        assertThat(response).isNotNull();
        assertThat(response.getReportId()).isNotNull();
        assertThat(response.getStatus()).isEqualTo(ReportStatus.OPEN);
        assertThat(response.getCaseId()).isNotNull();
        assertThat(response.getCreatedAt()).isNotNull();

        ModerationReport report = reportRepository.findById(response.getReportId()).orElse(null);
        assertThat(report).isNotNull();
        assertThat(report.getReporterUserId()).isEqualTo(reporterId);
        assertThat(report.getTargetId()).isEqualTo(targetId);
        assertThat(report.getReasonCode()).isEqualTo("HARASSMENT");

        ModerationCase moderationCase = caseRepository.findByReportId(report.getId()).orElse(null);
        assertThat(moderationCase).isNotNull();
        assertThat(moderationCase.getId()).isEqualTo(response.getCaseId());

        ModerationReportEvidence evidence = evidenceRepository.findByReportId(report.getId()).orElse(null);
        assertThat(evidence).isNotNull();
        assertThat(evidence.getSnapshotJson()).contains("targetId");
    }
}