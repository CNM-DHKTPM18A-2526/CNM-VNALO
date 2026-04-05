package iuh.cnm.vnalo.moderation_service.controller;

import iuh.cnm.vnalo.moderation_service.model.dto.request.CreateAdminUserRequest;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.moderation_service.exception.ApiException;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.security.ModerationPrincipal;
import iuh.cnm.vnalo.moderation_service.security.ModeratorGuardService;
import iuh.cnm.vnalo.moderation_service.service.AdminUserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/admin/users")
@RequiredArgsConstructor
public class AdminUserController {
    private final ModeratorGuardService moderatorGuardService;
    private final AdminUserService adminUserService;

    @PostMapping
    public ApiResponse<Void> createAdminUser(
            Authentication authentication,
            @Valid @RequestBody CreateAdminUserRequest request
    ) {
        UUID currentUserId = resolveCurrentUserId(authentication);
        moderatorGuardService.requireAdmin(currentUserId);
        adminUserService.createAdminUser(request);
        return ApiResponse.success("Admin user created successfully", null);
    }

    private UUID resolveCurrentUserId(Authentication authentication) {
        if (authentication == null || authentication.getPrincipal() == null) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }

        Object principal = authentication.getPrincipal();
        if (principal instanceof ModerationPrincipal moderationPrincipal) {
            return moderationPrincipal.getId();
        }
        if (principal instanceof String principalId) {
            try {
                return UUID.fromString(principalId);
            } catch (IllegalArgumentException ex) {
                throw new ApiException(ErrorCode.UNAUTHORIZED);
            }
        }
        if (principal instanceof UserDetails userDetails) {
            try {
                return UUID.fromString(userDetails.getUsername());
            } catch (IllegalArgumentException ex) {
                throw new ApiException(ErrorCode.UNAUTHORIZED);
            }
        }

        throw new ApiException(ErrorCode.UNAUTHORIZED);
    }
}