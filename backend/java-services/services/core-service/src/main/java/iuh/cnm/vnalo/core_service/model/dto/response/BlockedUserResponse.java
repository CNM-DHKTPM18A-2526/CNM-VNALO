package iuh.cnm.vnalo.core_service.model.dto.response;

import java.time.Instant;
import java.util.UUID;

/**
 * DTO for blocked user information.
 */
public record BlockedUserResponse(
        UUID userId,
        String displayName,
        String avatarUrl,
        Boolean blockMessages,
        Boolean blockCalls,
        Boolean blockAndHideLogs,
        Instant blockedAt
) {}
