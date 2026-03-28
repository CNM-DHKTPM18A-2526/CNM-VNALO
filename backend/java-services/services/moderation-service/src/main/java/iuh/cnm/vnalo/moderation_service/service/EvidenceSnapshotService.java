package iuh.cnm.vnalo.moderation_service.service;

import iuh.cnm.vnalo.moderation_service.model.enums.ReportTargetType;
import iuh.cnm.vnalo.moderation_service.query.SharedMessageQueryService;
import iuh.cnm.vnalo.moderation_service.query.SharedUserQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class EvidenceSnapshotService {
    private final SharedMessageQueryService sharedMessageQueryService;
    private final SharedUserQueryService sharedUserQueryService;

    public String buildSnapshot(ReportTargetType targetType, UUID targetId) {
        return switch (targetType) {
            case MESSAGE -> sharedMessageQueryService.getMessageSnapshotJson(targetId);
            case USER -> sharedUserQueryService.getUserSnapshotJson(targetId);
        };
    }
}