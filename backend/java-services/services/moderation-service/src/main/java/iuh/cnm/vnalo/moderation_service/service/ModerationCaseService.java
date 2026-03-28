package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.dto.ModerationCaseDTO;
import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveCaseRequest;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationCaseStatus;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationReportRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ModerationCaseService {
    private final ModerationCaseRepository caseRepository;
    private final ModerationReportRepository reportRepository;
    private final AuditLogService auditLogService;

    @Transactional
    public void assignCase(UUID reportId, UUID moderatorId, UUID actorUserId) {
        ModerationCase moderationCase = caseRepository.findByReportId(reportId)
                .orElseThrow(() -> new ApiException(ErrorCode.MODERATION_CASE_NOT_FOUND));

        UUID oldAssignee = moderationCase.getAssignedModeratorId();

        moderationCase.setAssignedModeratorId(moderatorId);
        moderationCase.setStatus(ModerationCaseStatus.ASSIGNED);
        caseRepository.save(moderationCase);

        auditLogService.log(reportId, moderationCase.getId(), "CASE_ASSIGNED",
                "{\"assignedModeratorId\":\"" + oldAssignee + "\"}",
                "{\"assignedModeratorId\":\"" + moderatorId + "\"}",
                actorUserId);
    }

    @Transactional
    public void resolveCase(UUID caseId, ResolveCaseRequest request, UUID actorUserId) {
        ModerationCase moderationCase = caseRepository.findById(caseId)
                .orElseThrow(() -> new ApiException(ErrorCode.MODERATION_CASE_NOT_FOUND));

        moderationCase.setDecision(request.getDecision());
        moderationCase.setNote(request.getNote());
        moderationCase.setStatus(ModerationCaseStatus.RESOLVED);
        moderationCase.setResolvedAt(Instant.now());
        caseRepository.save(moderationCase);

        auditLogService.log(moderationCase.getReportId(), caseId, "CASE_RESOLVED",
                null,
                "{\"decision\":\"" + request.getDecision() + "\"}",
                actorUserId);
    }

    public ModerationCaseDTO mapToDTO(ModerationCase moderationCase) {
        return ModerationCaseDTO.builder()
                .id(moderationCase.getId())
                .reportId(moderationCase.getReportId())
                .moderatorId(moderationCase.getAssignedModeratorId() != null ? moderationCase.getAssignedModeratorId().toString() : null)
                .status(moderationCase.getStatus())
                .decision(moderationCase.getDecision())
                .assignedAt(moderationCase.getCreatedAt()) // Use createdAt as assignedAt
                .resolvedAt(moderationCase.getResolvedAt())
                .notes(moderationCase.getNote())
                .build();
    }
}