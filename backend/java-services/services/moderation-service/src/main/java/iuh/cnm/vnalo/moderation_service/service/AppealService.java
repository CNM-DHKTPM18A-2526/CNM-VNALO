package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.request.ResolveAppealRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.AppealResponse;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAppeal;
import iuh.cnm.vnalo.moderation_service.model.enums.AppealStatus;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAppealRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AppealService {
    private final ModerationAppealRepository appealRepository;
    private final AuditLogService auditLogService;

    @Transactional
    public AppealResponse createAppeal(UUID userId, UUID caseId, CreateAppealRequest request) {
        ModerationAppeal appeal = ModerationAppeal.builder()
                .caseId(caseId)
                .userId(userId)
                .reason(request.getReason())
                .status(AppealStatus.PENDING)
                .build();

        appeal = appealRepository.save(appeal);

        auditLogService.log(null, caseId, "APPEAL_CREATED", null,
            "{\"appealId\":\"" + appeal.getId() + "\",\"caseId\":\"" + caseId + "\",\"status\":\"PENDING\"}",
            userId);

        return AppealResponse.from(appeal);
    }

    @Transactional
    public void resolveAppeal(UUID appealId, ResolveAppealRequest request, UUID moderatorId) {
        ModerationAppeal appeal = appealRepository.findById(appealId)
                .orElseThrow(() -> new RuntimeException("Appeal not found"));

        appeal.setStatus(request.getStatus());
        appeal.setModeratorResponse(request.getResponse());
        appeal.setModeratorId(moderatorId);

        appealRepository.save(appeal);

        auditLogService.log(null, appeal.getCaseId(), "APPEAL_RESOLVED", null,
            "{\"appealId\":\"" + appealId + "\",\"status\":\"" + request.getStatus() + "\"}",
            moderatorId);
    }

    public Page<AppealResponse> getAppeals(int page, int size) {
        return appealRepository.findAll(PageRequest.of(page, size))
                .map(AppealResponse::from);
    }
}