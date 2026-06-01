package iuh.cnm.vnalo.core_service.service.admin;

import iuh.cnm.vnalo.core_service.config.AdminMonitoringProperties;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringEventResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.admin.AdminMonitoringSummaryResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthSessionAudit;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.model.enums.QrLoginSessionStatus;
import iuh.cnm.vnalo.core_service.repository.ai.AiChatHistoryRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthOtpRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthQrLoginSessionRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthSessionAuditRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminMonitoringService {
    private final AuthAccountRepository authAccountRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AuthSessionAuditRepository authSessionAuditRepository;
    private final AuthOtpRepository authOtpRepository;
    private final AuthQrLoginSessionRepository authQrLoginSessionRepository;
    private final AiChatHistoryRepository aiChatHistoryRepository;
    private final AdminMonitoringProperties adminMonitoringProperties;

    @Transactional(readOnly = true)
    public AdminMonitoringSummaryResponse getSummary(UUID requesterId) {
        assertMonitoringAccess(requesterId);
        Instant now = Instant.now();
        Instant since24h = now.minusSeconds(24 * 60 * 60L);
        OffsetDateTime since24hOffset = OffsetDateTime.ofInstant(since24h, ZoneOffset.UTC);

        return new AdminMonitoringSummaryResponse(
                now,
                "ADMIN_ALLOWLIST",
                new AdminMonitoringSummaryResponse.AccountStats(
                        authAccountRepository.count(),
                        authAccountRepository.countByStatus(AccountStatus.ACTIVE),
                        authAccountRepository.countByStatus(AccountStatus.LOCKED),
                        authAccountRepository.countByStatus(AccountStatus.DISABLED),
                        authAccountRepository.countByStatus(AccountStatus.PENDING_VERIFICATION),
                        authAccountRepository.countAccountsWithFailedLogins(),
                        coalesce(authAccountRepository.sumFailedLoginCount())
                ),
                new AdminMonitoringSummaryResponse.SessionStats(
                        refreshTokenRepository.countActiveTokens(now),
                        refreshTokenRepository.countRevokedSince(since24h),
                        refreshTokenRepository.countActiveMobileSessions(now)
                ),
                new AdminMonitoringSummaryResponse.AuditStats(
                        authSessionAuditRepository.count(),
                        authSessionAuditRepository.countByCreatedAtAfter(since24h),
                        authSessionAuditRepository.countByEventTypeSince("LOGIN_SUCCESS", since24h),
                        authSessionAuditRepository.countByEventTypeSince("LOGIN_FAILED", since24h),
                        authSessionAuditRepository.countByEventTypeSince("SESSION_REVOKED_LOGOUT", since24h) + authSessionAuditRepository.countByEventTypeSince("SESSION_REVOKED_LOGOUT_ALL", since24h),
                        authSessionAuditRepository.countByEventTypeSince("QR_LOGIN_APPROVED", since24h)
                ),
                new AdminMonitoringSummaryResponse.OtpStats(
                        authOtpRepository.countByCreatedAtAfter(since24h),
                        authOtpRepository.countByPurposeAndCreatedAtAfter(OtpPurpose.REGISTER, since24h),
                        authOtpRepository.countByPurposeAndCreatedAtAfter(OtpPurpose.RESET_PASSWORD, since24h),
                        authOtpRepository.countByVerifiedAtAfter(since24h)
                ),
                new AdminMonitoringSummaryResponse.AiStats(
                        aiChatHistoryRepository.countByCreatedAtAfter(since24hOffset),
                        aiChatHistoryRepository.countByRoleAndCreatedAtAfter("user", since24hOffset),
                        aiChatHistoryRepository.countByRoleAndCreatedAtAfter("assistant", since24hOffset),
                        aiChatHistoryRepository.countDistinctUsersSince(since24hOffset)
                ),
                new AdminMonitoringSummaryResponse.QrStats(
                        authQrLoginSessionRepository.countByCreatedAtAfter(since24h),
                        authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.PENDING),
                        authQrLoginSessionRepository.countByApprovedAtAfter(since24h),
                        authQrLoginSessionRepository.countByConsumedAtAfter(since24h),
                        authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.REJECTED)
                )
        );
    }

    @Transactional(readOnly = true)
    public List<AdminMonitoringEventResponse> getRecentEvents(UUID requesterId, int limit) {
        assertMonitoringAccess(requesterId);
        int pageSize = Math.max(1, Math.min(limit, 50));
        return authSessionAuditRepository.findAllByOrderByCreatedAtDesc(PageRequest.of(0, pageSize))
                .stream()
                .map(this::toEventResponse)
                .toList();
    }

    public boolean canAccess(UUID requesterId) {
        if (requesterId == null || adminMonitoringProperties.allowedEmails().isEmpty()) {
            return false;
        }
        return authAccountRepository.findById(requesterId)
                .map(account -> normalizeEmail(account.getEmail()))
                .filter(email -> !email.isBlank())
                .map(email -> adminMonitoringProperties.allowedEmails().stream()
                        .map(this::normalizeEmail)
                        .anyMatch(email::equals))
                .orElse(false);
    }

    private void assertMonitoringAccess(UUID requesterId) {
        if (!canAccess(requesterId)) {
            throw new ApiException(ErrorCode.ACCESS_DENIED, "Admin monitoring access denied");
        }
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private AdminMonitoringEventResponse toEventResponse(AuthSessionAudit event) {
        return new AdminMonitoringEventResponse(
                event.getAuditId(), event.getEventType(), event.getSessionType(), event.getTrustLevel(),
                event.getPlatform(), sanitizeDeviceName(event.getDeviceName()), maskDeviceId(event.getDeviceId()),
                sanitizeDetail(event.getDetail()), event.getCreatedAt()
        );
    }

    private String sanitizeDeviceName(String deviceName) {
        if (deviceName == null || deviceName.isBlank()) return "Unknown device";
        return deviceName.length() > 48 ? deviceName.substring(0, 48) + "..." : deviceName;
    }

    private String maskDeviceId(String deviceId) {
        if (deviceId == null || deviceId.isBlank()) return "N/A";
        if (deviceId.length() <= 6) return "***" + deviceId.substring(Math.max(0, deviceId.length() - 2));
        return deviceId.substring(0, 3) + "***" + deviceId.substring(deviceId.length() - 3);
    }

    private String sanitizeDetail(String detail) {
        if (detail == null || detail.isBlank()) return "";
        return detail.length() > 120 ? detail.substring(0, 120) + "..." : detail;
    }

    private long coalesce(Long value) {
        return value == null ? 0L : value;
    }
}
