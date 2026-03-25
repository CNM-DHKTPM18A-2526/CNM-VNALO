package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.dto.ModerationActionDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportDetailDTO;
import iuh.cnm.vnalo.moderation_service.dto.ReportFilter;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateReportRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ReportResponse;
import iuh.cnm.vnalo.moderation_service.exception.BusinessException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAction;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReport;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationReportEvidence;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationDecision;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportPriority;
import iuh.cnm.vnalo.moderation_service.model.enums.ReportStatus;
import iuh.cnm.vnalo.moderation_service.repository.ModerationActionRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportEvidenceRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ReportService {
    private final ModerationReportRepository reportRepository;
    private final ModerationReportEvidenceRepository evidenceRepository;
    private final ModerationCaseRepository caseRepository;
    private final ModerationActionRepository actionRepository;
    private final EvidenceSnapshotService evidenceSnapshotService;
    private final AuditLogService auditLogService;
    private final ModerationCaseService moderationCaseService;

    @Transactional
    public ReportResponse createReport(UUID reporterUserId, CreateReportRequest request) {
        Instant twentyFourHoursAgo = Instant.now().minus(24, ChronoUnit.HOURS);

        boolean hasRecentReport =
                reportRepository.existsByReporterUserIdAndTargetTypeAndTargetIdAndReasonCodeAndCreatedAtAfter(
                        reporterUserId,
                        request.getTargetType(),
                        request.getTargetId(),
                        request.getReasonCode(),
                        twentyFourHoursAgo
                );

        if (hasRecentReport) {
            throw new BusinessException(
                    ErrorCode.VALIDATION_ERROR,
                    "You have already reported this content with the same reason within the last 24 hours"
            );
        }

        String snapshot = evidenceSnapshotService.buildSnapshot(request.getTargetType(), request.getTargetId());

        ModerationReport report = ModerationReport.builder()
                .reporterUserId(reporterUserId)
                .targetType(request.getTargetType())
                .targetId(request.getTargetId())
                .reasonCode(request.getReasonCode())
                .description(request.getDescription())
                .status(ReportStatus.OPEN)
                .priority(ReportPriority.MEDIUM)
                .build();

        report = reportRepository.saveAndFlush(report);

        evidenceRepository.save(
                ModerationReportEvidence.builder()
                        .reportId(report.getId())
                        .snapshotJson(snapshot)
                        .build()
        );

        ModerationCase moderationCase = caseRepository.save(
                ModerationCase.builder()
                        .reportId(report.getId())
                        .status(ModerationCaseStatus.OPEN)
                        .decision(ModerationDecision.PENDING)
                        .build()
        );

        auditLogService.log(report.getId(), moderationCase.getId(), "REPORT_CREATED", null, snapshot, reporterUserId);

        return ReportResponse.builder()
                .reportId(report.getId())
                .status(report.getStatus())
                .caseId(moderationCase.getId())
                .createdAt(report.getCreatedAt())
                .build();
    }

    public Page<ReportResponse> getMyReports(UUID userId, int page, int size) {
        Pageable pageable = PageRequest.of(page, size);

        return reportRepository.findByReporterUserId(userId, pageable)
                .map(report -> ReportResponse.builder()
                        .reportId(report.getId())
                        .status(report.getStatus())
                        .caseId(null)
                        .createdAt(report.getCreatedAt())
                        .build());
    }

    public Page<ReportDTO> getReports(ReportFilter filter, Pageable pageable) {
        Specification<ModerationReport> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();

            if (filter.getTargetType() != null) {
                predicates.add(cb.equal(root.get("targetType"), filter.getTargetType()));
            }

            if (filter.getStatus() != null) {
                predicates.add(cb.equal(root.get("status"), filter.getStatus()));
            }

            if (filter.getReporterId() != null) {
                predicates.add(cb.equal(root.get("reporterUserId"), filter.getReporterId()));
            }

            if (filter.getTargetId() != null) {
                predicates.add(cb.equal(root.get("targetId"), filter.getTargetId()));
            }

            if (filter.getCreatedAfter() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), filter.getCreatedAfter()));
            }

            if (filter.getCreatedBefore() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("createdAt"), filter.getCreatedBefore()));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        Page<ModerationReport> reports = reportRepository.findAll(spec, pageable);
        return reports.map(this::mapToDTO);
    }

public ReportDetailDTO getReportDetail(UUID reportId) {
    ModerationReport report = reportRepository.findById(reportId)
            .orElseThrow(() -> new BusinessException(ErrorCode.MODERATION_REPORT_NOT_FOUND));

    ModerationCase moderationCase = caseRepository.findByReportId(reportId)
            .orElse(null);

    List<ModerationAction> actions = moderationCase != null
            ? actionRepository.findByCaseIdOrderByCreatedAtDesc(moderationCase.getId())
            : List.of();

    return ReportDetailDTO.builder()
            .report(mapToDTO(report))
            .moderationCase(moderationCase != null ? moderationCaseService.mapToDTO(moderationCase) : null)
            .actions(actions.stream()
                    .map(action -> ModerationActionDTO.builder()
                            .id(action.getId())
                            .actionType(action.getActionType())
                            .reason(action.getReason())
                            .moderatorId(action.getCreatedBy())
                            .createdAt(action.getCreatedAt())
                            .build())
                    .toList())
            .build();
}
    private ReportDTO mapToDTO(ModerationReport report) {
        return ReportDTO.builder()
                .id(report.getId())
                .targetType(report.getTargetType())
                .targetId(report.getTargetId())
                .reporterId(report.getReporterUserId())
                .reason(report.getReasonCode())
                .description(report.getDescription())
                .evidence(null)
                .status(report.getStatus())
                .createdAt(report.getCreatedAt())
                .updatedAt(null)
                .build();
    }
}