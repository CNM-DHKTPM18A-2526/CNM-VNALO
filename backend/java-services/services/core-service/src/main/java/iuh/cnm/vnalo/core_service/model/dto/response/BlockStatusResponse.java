package iuh.cnm.vnalo.core_service.model.dto.response;

/**
 * DTO for block status between two users.
 */
public record BlockStatusResponse(
        boolean youBlocked,
        boolean blockedYou
) {}
