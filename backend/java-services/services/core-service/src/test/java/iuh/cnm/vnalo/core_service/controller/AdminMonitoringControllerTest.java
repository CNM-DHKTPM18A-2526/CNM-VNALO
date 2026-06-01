package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringSummaryResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.admin.AdminMonitoringService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminMonitoringControllerTest {

    private final AdminMonitoringService adminMonitoringService = mock(AdminMonitoringService.class);
    private final AdminMonitoringController controller = new AdminMonitoringController(adminMonitoringService);

    @Test
    void shouldRejectSummaryWhenPrincipalIsMissing() {
        ApiException exception = assertThrows(ApiException.class, () -> controller.getSummary(null, 24));

        assertEquals(ErrorCode.UNAUTHORIZED, exception.getErrorCode());
    }

    @Test
    void shouldRejectEventsWhenPrincipalIsMissing() {
        ApiException exception = assertThrows(ApiException.class, () -> controller.getRecentEvents(null, 12, 24, null, null));

        assertEquals(ErrorCode.UNAUTHORIZED, exception.getErrorCode());
    }

    @Test
    void shouldPassAuthenticatedUserIdToSummaryService() {
        UserPrincipal principal = principal(UUID.randomUUID());
        AdminMonitoringSummaryResponse summary = new AdminMonitoringSummaryResponse(
                Instant.now(),
                "ADMIN_ALLOWLIST",
                new AdminMonitoringSummaryResponse.AccountStats(1, 1, 0, 0, 0, 0, 0),
                new AdminMonitoringSummaryResponse.SessionStats(0, 0, 0),
                new AdminMonitoringSummaryResponse.AuditStats(0, 0, 0, 0, 0, 0),
                new AdminMonitoringSummaryResponse.OtpStats(0, 0, 0, 0),
                new AdminMonitoringSummaryResponse.AiStats(0, 0, 0, 0),
                new AdminMonitoringSummaryResponse.QrStats(0, 0, 0, 0, 0),
                new AdminMonitoringSummaryResponse.ConsentStats(0, 0, 0, 0, 0)
        );
        when(adminMonitoringService.getSummary(principal.getId(), 24)).thenReturn(summary);

        ResponseEntity<ApiResponse<AdminMonitoringSummaryResponse>> response = controller.getSummary(principal, 24);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(summary, response.getBody().getData());
        verify(adminMonitoringService).getSummary(principal.getId(), 24);
    }

    @Test
    void shouldPassAuthenticatedUserIdToEventsService() {
        UserPrincipal principal = principal(UUID.randomUUID());
        when(adminMonitoringService.getRecentEvents(principal.getId(), 20, 72, "LOGIN_FAILED", "WEB")).thenReturn(List.of());

        ResponseEntity<ApiResponse<List<AdminMonitoringEventResponse>>> response = controller.getRecentEvents(principal, 20, 72, "LOGIN_FAILED", "WEB");

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals(List.of(), response.getBody().getData());
        verify(adminMonitoringService).getRecentEvents(principal.getId(), 20, 72, "LOGIN_FAILED", "WEB");
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