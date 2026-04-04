package iuh.cnm.vnalo.moderation_service.security;

import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.entity.ModerationAdminUser;
import iuh.cnm.vnalo.moderation_service.model.enums.ModerationAdminRole;
import iuh.cnm.vnalo.moderation_service.repository.ModerationAdminUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ModeratorGuardService {
    private final ModerationAdminUserRepository adminUserRepository;

    public void requireModerator(UUID userId) {
        ModerationAdminUser user = adminUserRepository.findByUserIdAndIsActiveTrue(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.MODERATION_FORBIDDEN));

        if (user.getRole() != ModerationAdminRole.MODERATOR && user.getRole() != ModerationAdminRole.ADMIN) {
            throw new ApiException(ErrorCode.MODERATION_FORBIDDEN);
        }
    }

    public void requireAdmin(UUID userId) {
        ModerationAdminUser user = adminUserRepository.findByUserIdAndIsActiveTrue(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.MODERATION_FORBIDDEN));

        if (user.getRole() != ModerationAdminRole.ADMIN) {
            throw new ApiException(ErrorCode.MODERATION_FORBIDDEN);
        }
    }
}