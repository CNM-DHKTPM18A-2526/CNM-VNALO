package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateModerationActionRequest;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAction;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationCase;
import iuh.cnm.vnalo.moderation_service.repository.ModerationActionRepository;
import iuh.cnm.vnalo.moderation_service.repository.ModerationCaseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ModerationActionService {
    private final ModerationActionRepository actionRepository;
    private final ModerationCaseRepository caseRepository;
    private final AuditLogService auditLogService;

    @Transactional
    public UUID createAction(CreateModerationActionRequest request, UUID actorUserId) {
        ModerationCase moderationCase = caseRepository.findById(request.getCaseId())
                .orElseThrow(() -> new ApiException(ErrorCode.MODERATION_CASE_NOT_FOUND));

        ModerationAction action = actionRepository.save(
                ModerationAction.builder()
                        .caseId(request.getCaseId())
                        .actionType(request.getActionType())
                        .targetUserId(request.getTargetUserId())
                        .targetMessageId(request.getTargetMessageId())
                        .targetConversationId(request.getTargetConversationId())
                        .reason(request.getReason())
                        .createdBy(actorUserId)
                        .build()
        );

        auditLogService.log(moderationCase.getReportId(), request.getCaseId(), "ACTION_CREATED",
                null,
                "{\"actionType\":\"" + request.getActionType() + "\"}",
                actorUserId);

        return action.getId();
    }
}