package iuh.cnm.vnalo.core_service.service.admin;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventPageResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringSummaryResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringTrendPointResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import iuh.cnm.vnalo.core_service.repository.ai.AiChatHistoryRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthLegalConsentRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthOtpRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthPermissionRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthQrLoginSessionRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthSessionAuditRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminMonitoringServiceTest {

    @Mock private AuthAccountRepository authAccountRepository;
    @Mock private AuthLegalConsentRepository authLegalConsentRepository;
    @Mock private RefreshTokenRepository refreshTokenRepository;
    @Mock private AuthSessionAuditRepository authSessionAuditRepository;
    @Mock private AuthOtpRepository authOtpRepository;
    @Mock private AuthQrLoginSessionRepository authQrLoginSessionRepository;
    @Mock private AiChatHistoryRepository aiChatHistoryRepository;
    @Mock private AuthPermissionRepository authPermissionRepository;

    private UUID adminId;
    private AdminMonitoringService service;

    @BeforeEach
    void setUp() {
        adminId = UUID.randomUUID();
        service = new AdminMonitoringService(
                authAccountRepository,
                authLegalConsentRepository,
                refreshTokenRepository,
                authSessionAuditRepository,
                authOtpRepository,
                authQrLoginSessionRepository,
                aiChatHistoryRepository,
                authPermissionRepository
        );
    }

    @Test
    void shouldDenyAccessWhenPermissionMissing() {
        when(authPermissionRepository.accountHasPermission(adminId, AdminMonitoringService.PERMISSION_MONITORING_VIEW)).thenReturn(false);

        ApiException exception = assertThrows(ApiException.class, () -> service.getSummary(adminId, 24));

        assertEquals(ErrorCode.ACCESS_DENIED, exception.getErrorCode());
    }

    @Test
    void shouldReturnSummaryForAuthorizedAdmin() {
        when(authPermissionRepository.accountHasPermission(adminId, AdminMonitoringService.PERMISSION_MONITORING_VIEW)).thenReturn(true);
        when(authAccountRepository.count()).thenReturn(10L);
        when(authAccountRepository.countByStatus(AccountStatus.ACTIVE)).thenReturn(8L);
        when(authAccountRepository.countByStatus(AccountStatus.LOCKED)).thenReturn(1L);
        when(authAccountRepository.countByStatus(AccountStatus.DISABLED)).thenReturn(0L);
        when(authAccountRepository.countByStatus(AccountStatus.PENDING_VERIFICATION)).thenReturn(1L);
        when(authAccountRepository.countAccountsWithFailedLogins()).thenReturn(2L);
        when(authAccountRepository.sumFailedLoginCount()).thenReturn(5L);
        when(refreshTokenRepository.countActiveTokens(any(Instant.class))).thenReturn(4L);
        when(refreshTokenRepository.countRevokedSince(any(Instant.class))).thenReturn(1L);
        when(refreshTokenRepository.countActiveMobileSessions(any(Instant.class))).thenReturn(2L);
        when(authSessionAuditRepository.count()).thenReturn(20L);
        when(authSessionAuditRepository.countByCreatedAtAfter(any(Instant.class))).thenReturn(10L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("LOGIN_SUCCESS"), any(Instant.class))).thenReturn(6L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("LOGIN_FAILED"), any(Instant.class))).thenReturn(1L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("SESSION_REVOKED_LOGOUT"), any(Instant.class))).thenReturn(1L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("SESSION_REVOKED_LOGOUT_ALL"), any(Instant.class))).thenReturn(1L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("QR_LOGIN_APPROVED"), any(Instant.class))).thenReturn(2L);
        when(authOtpRepository.countByPurposeAndCreatedAtAfter(eq(OtpPurpose.REGISTER), any(Instant.class))).thenReturn(3L);
        when(authOtpRepository.countByPurposeAndCreatedAtAfter(eq(OtpPurpose.RESET_PASSWORD), any(Instant.class))).thenReturn(2L);
        when(authOtpRepository.countByVerifiedAtAfter(any(Instant.class))).thenReturn(5L);
        when(aiChatHistoryRepository.countByCreatedAtAfter(any(OffsetDateTime.class))).thenReturn(9L);
        when(aiChatHistoryRepository.countByRoleAndCreatedAtAfter(eq("user"), any(OffsetDateTime.class))).thenReturn(4L);
        when(aiChatHistoryRepository.countByRoleAndCreatedAtAfter(eq("assistant"), any(OffsetDateTime.class))).thenReturn(5L);
        when(aiChatHistoryRepository.countDistinctUsersSince(any(OffsetDateTime.class))).thenReturn(3L);
        when(authQrLoginSessionRepository.countByCreatedAtAfter(any(Instant.class))).thenReturn(6L);
        when(authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.PENDING)).thenReturn(2L);
        when(authQrLoginSessionRepository.countByApprovedAtAfter(any(Instant.class))).thenReturn(4L);
        when(authQrLoginSessionRepository.countByConsumedAtAfter(any(Instant.class))).thenReturn(3L);
        when(authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.REJECTED)).thenReturn(1L);
        when(authLegalConsentRepository.countByGrantedTrue()).thenReturn(9L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrue("TERMS_OF_USE")).thenReturn(5L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrue("PRIVACY_POLICY")).thenReturn(4L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter(eq("TERMS_OF_USE"), any(Instant.class))).thenReturn(2L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter(eq("PRIVACY_POLICY"), any(Instant.class))).thenReturn(2L);

        AdminMonitoringSummaryResponse summary = service.getSummary(adminId, 24);

        assertNotNull(summary);
        assertEquals(AdminMonitoringService.ACCESS_MODE_RBAC, summary.accessMode());
        assertEquals(8L, summary.accounts().active());
        assertEquals(3L, summary.ai().distinctActiveUsersLast24Hours());
        assertEquals(2L, summary.consent().termsLast24Hours());
    }

    @Test
    void shouldReturnPagedEventsWithSeverityAndHasMore() {
        when(authPermissionRepository.accountHasPermission(adminId, AdminMonitoringService.PERMISSION_MONITORING_VIEW)).thenReturn(true);
        AuthSessionAudit failed = AuthSessionAudit.builder()
                .eventType("LOGIN_FAILED")
                .platform("WEB")
                .deviceName("Chrome on Windows")
                .deviceId("device-abcdef-123456")
                .detail("x".repeat(180))
                .createdAt(Instant.now())
                .build();
        AuthSessionAudit revoked = AuthSessionAudit.builder()
                .eventType("SESSION_REVOKED_LOGOUT")
                .platform("WEB")
                .deviceName("Chrome on Windows")
                .deviceId("device-abcdef-654321")
                .detail("logout all sessions")
                .createdAt(Instant.now().minusSeconds(60))
                .build();
        when(authSessionAuditRepository.findMonitoringEvents(any(Instant.class), eq("LOGIN_FAILED"), eq("WEB"), any(Pageable.class)))
                .thenReturn(List.of(failed, revoked));

        AdminMonitoringEventPageResponse response = service.getRecentEvents(adminId, 1, 0, 24, "LOGIN_FAILED", "WEB");

        assertEquals(0, response.page());
        assertEquals(1, response.limit());
        assertTrue(response.hasMore());
        assertEquals(1, response.items().size());
        AdminMonitoringEventResponse event = response.items().get(0);
        assertEquals("error", event.severity());
        assertEquals("dev***456", event.deviceIdMasked());
        assertTrue(event.detail().endsWith("..."));
        verify(authSessionAuditRepository).findMonitoringEvents(any(Instant.class), eq("LOGIN_FAILED"), eq("WEB"), any(Pageable.class));
    }

    @Test
    void shouldReturnTrendPoints() {
        when(authPermissionRepository.accountHasPermission(adminId, AdminMonitoringService.PERMISSION_MONITORING_VIEW)).thenReturn(true);
        AuthSessionAuditRepository.MonitoringTrendProjection projection = new AuthSessionAuditRepository.MonitoringTrendProjection() {
            @Override public Instant getBucket() { return Instant.parse("2026-06-01T08:00:00Z"); }
            @Override public long getTotal() { return 5; }
            @Override public long getWarning() { return 2; }
            @Override public long getError() { return 1; }
        };
        when(authSessionAuditRepository.findMonitoringTrend(any(Instant.class), eq("hour"), eq("LOGIN_FAILED"), eq("WEB")))
                .thenReturn(List.of(projection));

        List<AdminMonitoringTrendPointResponse> trend = service.getEventTrend(adminId, 24, "LOGIN_FAILED", "WEB");

        assertEquals(1, trend.size());
        assertEquals(5L, trend.get(0).total());
        assertEquals(2L, trend.get(0).warning());
        assertEquals(1L, trend.get(0).error());
    }
}