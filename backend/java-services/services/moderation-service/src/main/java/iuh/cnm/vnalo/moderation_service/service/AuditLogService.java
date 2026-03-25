package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAuditLog;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAuditLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuditLogService {
    private final ModerationAuditLogRepository auditLogRepository;

    public void log(UUID reportId, UUID caseId, String action, String oldValueJson, String newValueJson, UUID actorUserId) {
        auditLogRepository.save(
                ModerationAuditLog.builder()
                        .reportId(reportId)
                        .caseId(caseId)
                        .action(action)
                        .oldValueJson(oldValueJson)
                        .newValueJson(newValueJson)
                        .performedBy(actorUserId)
                        .build()
        );
    }
}