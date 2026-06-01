package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleGrantRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.admin.AdminRoleRevokeRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminRoleAssignmentResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.admin.AdminRbacService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminRbacControllerTest {
    private final AdminRbacService adminRbacService = mock(AdminRbacService.class);
    private final AdminRbacController controller = new AdminRbacController(adminRbacService);

    @Test
    void shouldRejectWhenPrincipalMissing() {
        ApiException exception = assertThrows(ApiException.class, () -> controller.listAssignments(null));
        assertEquals(ErrorCode.UNAUTHORIZED, exception.getErrorCode());
    }

    @Test
    void shouldListAssignments() {
        UserPrincipal principal = principal(UUID.randomUUID());
        List<AdminRoleAssignmentResponse> assignments = List.of(new AdminRoleAssignmentResponse(principal.getId(), "admin@vnalo.fit", "SUPER_ADMIN", Instant.now(), null, null));
        when(adminRbacService.listAssignments(principal.getId())).thenReturn(assignments);

        ResponseEntity<ApiResponse<List<AdminRoleAssignmentResponse>>> response = controller.listAssignments(principal);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(assignments, response.getBody().getData());
        verify(adminRbacService).listAssignments(principal.getId());
    }

    @Test
    void shouldGrantRole() {
        UserPrincipal principal = principal(UUID.randomUUID());
        AdminRoleGrantRequest request = new AdminRoleGrantRequest("user@vnalo.fit", "SUPER_ADMIN", null);
        AdminRoleAssignmentResponse assignment = new AdminRoleAssignmentResponse(principal.getId(), "user@vnalo.fit", "SUPER_ADMIN", Instant.now(), principal.getId(), null);
        when(adminRbacService.grantRole(principal.getId(), request)).thenReturn(assignment);

        ResponseEntity<ApiResponse<AdminRoleAssignmentResponse>> response = controller.grantRole(principal, request);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(assignment, response.getBody().getData());
        verify(adminRbacService).grantRole(principal.getId(), request);
    }

    @Test
    void shouldRevokeRole() {
        UserPrincipal principal = principal(UUID.randomUUID());
        AdminRoleRevokeRequest request = new AdminRoleRevokeRequest("user@vnalo.fit", "SUPER_ADMIN");
        AdminRoleAssignmentResponse assignment = new AdminRoleAssignmentResponse(principal.getId(), "user@vnalo.fit", "SUPER_ADMIN", Instant.now(), principal.getId(), null);
        when(adminRbacService.revokeRole(principal.getId(), request)).thenReturn(assignment);

        ResponseEntity<ApiResponse<AdminRoleAssignmentResponse>> response = controller.revokeRole(principal, request);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(assignment, response.getBody().getData());
        verify(adminRbacService).revokeRole(principal.getId(), request);
    }

    private UserPrincipal principal(UUID id) {
        AuthAccount account = AuthAccount.builder()
                .phone("+84900000000")
                .email("admin@vnalo.fit")
                .passwordHash("hash")
                .status(AccountStatus.ACTIVE)
                .build();
        account.setId(id);
        return UserPrincipal.create(account);
    }
}
