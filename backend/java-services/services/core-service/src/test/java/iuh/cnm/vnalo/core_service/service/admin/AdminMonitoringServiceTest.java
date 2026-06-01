package iuh.cnm.vnalo.core_service.service.admin;

import iuh.cnm.vnalo.core_service.config.AdminMonitoringProperties;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringSummaryResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import iuh.cnm.vnalo.core_service.repository.ai.AiChatHistoryRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthLegalConsentRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthOtpRepository;
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
import java.util.Optional;
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
                new AdminMonitoringProperties(List.of("Admin@vnalo.fit"))
        );
    }

    @Test
    void shouldDenyAccessWhenEmailNotAllowlisted() {
        AuthAccount account = AuthAccount.builder()
                .email("user@vnalo.fit")
                .phone("+84900000000")
                .passwordHash("hash")
                .status(AccountStatus.ACTIVE)
                .build();
        account.setId(adminId);
        when(authAccountRepository.findById(adminId)).thenReturn(Optional.of(account));

        ApiException exception = assertThrows(ApiException.class, () -> service.getSummary(adminId));

        assertEquals(ErrorCode.ACCESS_DENIED, exception.getErrorCode());
    }

    @Test
    void shouldReturnSummaryForAllowlistedEmail() {
        AuthAccount account = AuthAccount.builder()
                .email("admin@vnalo.fit")
                .phone("+84900000000")
                .passwordHash("hash")
                .status(AccountStatus.ACTIVE)
                .build();
        account.setId(adminId);
        when(authAccountRepository.findById(adminId)).thenReturn(Optional.of(account));
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
        when(authSessionAuditRepository.count()).thenReturn(12L);
        when(authSessionAuditRepository.countByCreatedAtAfter(any(Instant.class))).thenReturn(6L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("LOGIN_SUCCESS"), any(Instant.class))).thenReturn(3L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("LOGIN_FAILED"), any(Instant.class))).thenReturn(1L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("SESSION_REVOKED_LOGOUT"), any(Instant.class))).thenReturn(1L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("SESSION_REVOKED_LOGOUT_ALL"), any(Instant.class))).thenReturn(0L);
        when(authSessionAuditRepository.countByEventTypeSince(eq("QR_LOGIN_APPROVED"), any(Instant.class))).thenReturn(2L);
        when(authOtpRepository.countByCreatedAtAfter(any(Instant.class))).thenReturn(9L);
        when(authOtpRepository.countByPurposeAndCreatedAtAfter(eq(OtpPurpose.REGISTER), any(Instant.class))).thenReturn(4L);
        when(authOtpRepository.countByPurposeAndCreatedAtAfter(eq(OtpPurpose.RESET_PASSWORD), any(Instant.class))).thenReturn(2L);
        when(authOtpRepository.countByVerifiedAtAfter(any(Instant.class))).thenReturn(5L);
        when(aiChatHistoryRepository.countByCreatedAtAfter(any(OffsetDateTime.class))).thenReturn(7L);
        when(aiChatHistoryRepository.countByRoleAndCreatedAtAfter(eq("user"), any(OffsetDateTime.class))).thenReturn(4L);
        when(aiChatHistoryRepository.countByRoleAndCreatedAtAfter(eq("assistant"), any(OffsetDateTime.class))).thenReturn(3L);
        when(aiChatHistoryRepository.countDistinctUsersSince(any(OffsetDateTime.class))).thenReturn(2L);
        when(authQrLoginSessionRepository.countByCreatedAtAfter(any(Instant.class))).thenReturn(5L);
        when(authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.PENDING)).thenReturn(1L);
        when(authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.REJECTED)).thenReturn(0L);
        when(authQrLoginSessionRepository.countByApprovedAtAfter(any(Instant.class))).thenReturn(2L);
        when(authQrLoginSessionRepository.countByConsumedAtAfter(any(Instant.class))).thenReturn(2L);
        when(authLegalConsentRepository.countByGrantedTrue()).thenReturn(18L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrue("TERMS_OF_USE")).thenReturn(9L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrue("PRIVACY_POLICY")).thenReturn(9L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter(eq("TERMS_OF_USE"), any(Instant.class))).thenReturn(4L);
        when(authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter(eq("PRIVACY_POLICY"), any(Instant.class))).thenReturn(4L);

        AdminMonitoringSummaryResponse summary = service.getSummary(adminId);

        assertNotNull(summary.generatedAt());
        assertEquals("ADMIN_ALLOWLIST", summary.accessMode());
        assertEquals(10L, summary.accounts().total());
        assertEquals(7L, summary.ai().messagesLast24Hours());
        assertEquals(1L, summary.qr().pendingNow());
        assertEquals(18L, summary.consent().grantedTotal());
    }

    @Test
    void shouldMaskDeviceIdAndTrimDetailsInRecentEvents() {
        AuthAccount account = AuthAccount.builder()
                .email("admin@vnalo.fit")
                .phone("+84900000000")
                .passwordHash("hash")
                .status(AccountStatus.ACTIVE)
                .build();
        account.setId(adminId);
        AuthSessionAudit audit = AuthSessionAudit.builder()
                .eventType("SESSION_REFRESHED")
                .sessionType("WEB")
                .trustLevel("TRUSTED")
                .platform("WEB")
                .deviceName("Chrome on Windows")
                .deviceId("device-abcdef-123456")
                .detail("x".repeat(180))
                .build();
        when(authAccountRepository.findById(adminId)).thenReturn(Optional.of(account));
        when(authSessionAuditRepository.findAllByOrderByCreatedAtDesc(any(Pageable.class))).thenReturn(List.of(audit));

        List<AdminMonitoringEventResponse> events = service.getRecentEvents(adminId, 1000);

        assertEquals(1, events.size());
        assertEquals("dev***456", events.get(0).deviceIdMasked());
        assertTrue(events.get(0).detail().endsWith("..."));
        verify(authSessionAuditRepository).findAllByOrderByCreatedAtDesc(any(Pageable.class));
    }
}