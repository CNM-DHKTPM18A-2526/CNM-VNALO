package iuh.cnm.vnalo.moderation_service.functional;

import iuh.cnm.vnalo.moderation_service.dto.ReportDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportDetailDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportFilter;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAdminUserRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateModerationActionRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateReportRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveCaseRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.AppealResponse;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ReportResponse;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAction;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAppeal;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationActionType;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationAdminRole;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import iuh.cnm.vnalo.moderation_service.repository.ModerationActionRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAdminUserRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAppealRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportRepository;
import iuh.cnm.vnalo.moderation_service.service.AdminUserService;
import iuh.cnm.vnalo.moderation_service.service.AppealService;
import iuh.cnm.vnalo.moderation_service.service.EvidenceSnapshotService;
import iuh.cnm.vnalo.moderation_service.service.ModerationActionService;
import iuh.cnm.vnalo.moderation_service.service.ModerationCaseService;
import iuh.cnm.vnalo.moderation_service.service.ReportService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class FunctionalCoverageIntegrationTest {

    @Autowired
    private ReportService reportService;

    @Autowired
    private ModerationCaseService moderationCaseService;

    @Autowired
    private ModerationActionService moderationActionService;

    @Autowired
    private AppealService appealService;

    @Autowired
    private AdminUserService adminUserService;

    @Autowired
    private ModerationReportRepository reportRepository;

    @Autowired
    private ModerationCaseRepository caseRepository;

    @Autowired
    private ModerationActionRepository actionRepository;

    @Autowired
    private ModerationAppealRepository appealRepository;

    @Autowired
    private ModerationAdminUserRepository adminUserRepository;

    @MockBean
    private EvidenceSnapshotService evidenceSnapshotService;

    @Test
    void userCanCreateReportSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse response = reportService.createReport(reporterId, buildReportRequest(targetId, "HARASSMENT"));

        assertThat(response.getReportId()).isNotNull();
        assertThat(response.getCaseId()).isNotNull();
        assertThat(response.getStatus()).isEqualTo(ReportStatus.OPEN);

        ModerationReport report = reportRepository.findById(response.getReportId()).orElseThrow();
        assertThat(report.getReporterUserId()).isEqualTo(reporterId);
        assertThat(report.getTargetId()).isEqualTo(targetId);
        assertThat(report.getStatus()).isEqualTo(ReportStatus.OPEN);
    }

    @Test
    void userCanViewOwnReports() {
        UUID reporterId = UUID.randomUUID();
        UUID targetA = UUID.randomUUID();
        UUID targetB = UUID.randomUUID();
        stubSnapshot(targetA);
        reportService.createReport(reporterId, buildReportRequest(targetA, "SPAM"));
        stubSnapshot(targetB);
        reportService.createReport(reporterId, buildReportRequest(targetB, "HARASSMENT"));

        Page<ReportResponse> page = reportService.getMyReports(reporterId, 0, 20);

        assertThat(page.getTotalElements()).isEqualTo(2);
        assertThat(page.getContent()).allMatch(item -> item.getStatus() == ReportStatus.OPEN);
    }

    @Test
    void moderatorCanViewReportListAndDetail() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID actorUserId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "ABUSE"));

        CreateModerationActionRequest actionRequest = new CreateModerationActionRequest();
        actionRequest.setCaseId(created.getCaseId());
        actionRequest.setActionType(ModerationActionType.WARN_USER);
        actionRequest.setTargetUserId(targetId);
        actionRequest.setReason("Warning after review");
        moderationActionService.createAction(actionRequest, actorUserId);

        ReportFilter filter = ReportFilter.builder().status(ReportStatus.OPEN).build();
        Page<ReportDTO> reports = reportService.getReports(filter, PageRequest.of(0, 20));
        ReportDetailDTO detail = reportService.getReportDetail(created.getReportId());

        assertThat(reports.getContent()).isNotEmpty();
        assertThat(reports.getContent()).anyMatch(r -> r.getId().equals(created.getReportId()));
        assertThat(detail.getReport().getId()).isEqualTo(created.getReportId());
        assertThat(detail.getModerationCase()).isNotNull();
        assertThat(detail.getActions()).isNotEmpty();
    }

    @Test
    void moderatorCanAssignCaseSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID assigneeId = UUID.randomUUID();
        UUID actorUserId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "SCAM"));

        moderationCaseService.assignCase(created.getReportId(), assigneeId, actorUserId);

        ModerationCase moderationCase = caseRepository.findByReportId(created.getReportId()).orElseThrow();
        assertThat(moderationCase.getAssignedModeratorId()).isEqualTo(assigneeId);
        assertThat(moderationCase.getStatus()).isEqualTo(ModerationCaseStatus.ASSIGNED);
    }

    @Test
    void moderatorCanResolveCaseSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID actorUserId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "HARASSMENT"));

        ResolveCaseRequest resolveCaseRequest = new ResolveCaseRequest();
        resolveCaseRequest.setDecision(ModerationDecision.WARN);
        resolveCaseRequest.setNote("Confirmed violation");
        moderationCaseService.resolveCase(created.getCaseId(), resolveCaseRequest, actorUserId);

        ModerationCase moderationCase = caseRepository.findById(created.getCaseId()).orElseThrow();
        assertThat(moderationCase.getStatus()).isEqualTo(ModerationCaseStatus.RESOLVED);
        assertThat(moderationCase.getDecision()).isEqualTo(ModerationDecision.WARN);
        assertThat(moderationCase.getResolvedAt()).isNotNull();
    }

    @Test
    void moderatorCanCreateModerationActionSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID actorUserId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "ABUSE"));

        CreateModerationActionRequest request = new CreateModerationActionRequest();
        request.setCaseId(created.getCaseId());
        request.setActionType(ModerationActionType.FLAG_MESSAGE);
        request.setTargetUserId(targetId);
        request.setReason("Flagged abusive content");

        UUID actionId = moderationActionService.createAction(request, actorUserId);

        ModerationAction action = actionRepository.findById(actionId).orElseThrow();
        assertThat(action.getCaseId()).isEqualTo(created.getCaseId());
        assertThat(action.getActionType()).isEqualTo(ModerationActionType.FLAG_MESSAGE);
        assertThat(action.getCreatedBy()).isEqualTo(actorUserId);
    }

    @Test
    void userCanCreateAppealSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID appealUserId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "SPAM"));

        CreateAppealRequest request = CreateAppealRequest.builder()
                .reason("Please review this decision")
                .build();

        AppealResponse response = appealService.createAppeal(appealUserId, created.getCaseId(), request);

        assertThat(response.getId()).isNotNull();
        assertThat(response.getCaseId()).isEqualTo(created.getCaseId());
        assertThat(response.getStatus()).isEqualTo(AppealStatus.PENDING);

        ModerationAppeal appeal = appealRepository.findById(response.getId()).orElseThrow();
        assertThat(appeal.getUserId()).isEqualTo(appealUserId);
    }

    @Test
    void moderatorCanViewAndResolveAppealSuccessfully() {
        UUID reporterId = UUID.randomUUID();
        UUID targetId = UUID.randomUUID();
        UUID appealUserId = UUID.randomUUID();
        UUID moderatorId = UUID.randomUUID();
        stubSnapshot(targetId);

        ReportResponse created = reportService.createReport(reporterId, buildReportRequest(targetId, "SPAM"));

        AppealResponse createdAppeal = appealService.createAppeal(
                appealUserId,
                created.getCaseId(),
                CreateAppealRequest.builder().reason("Need re-check").build());

        Page<AppealResponse> appealsBefore = appealService.getAppeals(0, 20);
        assertThat(appealsBefore.getContent()).anyMatch(item -> item.getId().equals(createdAppeal.getId()));

        ResolveAppealRequest resolveRequest = ResolveAppealRequest.builder()
                .status(AppealStatus.APPROVED)
                .response("Approved after review")
                .build();
        appealService.resolveAppeal(createdAppeal.getId(), resolveRequest, moderatorId);

        ModerationAppeal appeal = appealRepository.findById(createdAppeal.getId()).orElseThrow();
        assertThat(appeal.getStatus()).isEqualTo(AppealStatus.APPROVED);
        assertThat(appeal.getModeratorId()).isEqualTo(moderatorId);
        assertThat(appeal.getModeratorResponse()).isEqualTo("Approved after review");
    }

    @Test
    void adminCanCreateModeratorAndAdminSuccessfully() {
        UUID moderatorUserId = UUID.randomUUID();
        UUID adminUserId = UUID.randomUUID();

        CreateAdminUserRequest moderatorRequest = new CreateAdminUserRequest();
        moderatorRequest.setUserId(moderatorUserId);
        moderatorRequest.setRole(ModerationAdminRole.MODERATOR);
        adminUserService.createAdminUser(moderatorRequest);

        CreateAdminUserRequest adminRequest = new CreateAdminUserRequest();
        adminRequest.setUserId(adminUserId);
        adminRequest.setRole(ModerationAdminRole.ADMIN);
        adminUserService.createAdminUser(adminRequest);

        ModerationAdminUser moderator = adminUserRepository.findById(moderatorUserId).orElseThrow();
        ModerationAdminUser admin = adminUserRepository.findById(adminUserId).orElseThrow();

        assertThat(moderator.getRole()).isEqualTo(ModerationAdminRole.MODERATOR);
        assertThat(admin.getRole()).isEqualTo(ModerationAdminRole.ADMIN);
        assertThat(moderator.getIsActive()).isTrue();
        assertThat(admin.getIsActive()).isTrue();
    }

    private CreateReportRequest buildReportRequest(UUID targetId, String reasonCode) {
        return CreateReportRequest.builder()
                .targetType(ReportTargetType.USER)
                .targetId(targetId)
                .reasonCode(reasonCode)
                .description("Functional coverage test")
                .build();
    }

    private void stubSnapshot(UUID targetId) {
        when(evidenceSnapshotService.buildSnapshot(any(), any()))
                .thenReturn("{\"targetId\":\"" + targetId + "\"}");
    }
}