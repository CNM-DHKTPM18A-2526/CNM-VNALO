package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleGrantRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleRevokeRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminRoleAssignmentResponse;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.admin.AdminRbacService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/admin/rbac")
@RequiredArgsConstructor
public class AdminRbacController {
    private final AdminRbacService adminRbacService;

    @GetMapping("/assignments")
    public ResponseEntity<ApiResponse<List<AdminRoleAssignmentResponse>>> listAssignments(@AuthenticationPrincipal UserPrincipal currentUser) {
        return ResponseEntity.ok(ApiResponse.success("Admin role assignments retrieved", adminRbacService.listAssignments(resolveUserId(currentUser))));
    }

    @PostMapping("/assignments")
    public ResponseEntity<ApiResponse<AdminRoleAssignmentResponse>> grantRole(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody AdminRoleGrantRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.success("Admin role granted", adminRbacService.grantRole(resolveUserId(currentUser), request)));
    }

    @DeleteMapping("/assignments")
    public ResponseEntity<ApiResponse<AdminRoleAssignmentResponse>> revokeRole(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody AdminRoleRevokeRequest request
    ) {
        return ResponseEntity.ok(ApiResponse.success("Admin role revoked", adminRbacService.revokeRole(resolveUserId(currentUser), request)));
    }

    private UUID resolveUserId(UserPrincipal currentUser) {
        if (currentUser == null) {
            throw new ApiException(ErrorCode.UNAUTHORIZED, "Authentication is required");
        }
        return currentUser.getId();
    }
}
