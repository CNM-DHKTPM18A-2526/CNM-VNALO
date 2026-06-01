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
import iuh.cnm.vnalo.core_service.repository.auth.AuthLegalConsentRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthOtpRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthQrLoginSessionRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthSessionAuditRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminMonitoringService {
    private static final int DEFAULT_WINDOW_HOURS = 24;
    private static final int MIN_WINDOW_HOURS = 1;
    private static final int MAX_WINDOW_HOURS = 168;

    private final AuthAccountRepository authAccountRepository;
    private final AuthLegalConsentRepository authLegalConsentRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AuthSessionAuditRepository authSessionAuditRepository;
    private final AuthOtpRepository authOtpRepository;
    private final AuthQrLoginSessionRepository authQrLoginSessionRepository;
    private final AiChatHistoryRepository aiChatHistoryRepository;
    private final AdminMonitoringProperties adminMonitoringProperties;

    @Transactional(readOnly = true)
    public AdminMonitoringSummaryResponse getSummary(UUID requesterId, Integer windowHours) {
        assertMonitoringAccess(requesterId);
        Instant now = Instant.now();
        Instant since = resolveSince(windowHours, now);
        OffsetDateTime sinceOffset = OffsetDateTime.ofInstant(since, ZoneOffset.UTC);

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
                        refreshTokenRepository.countRevokedSince(since),
                        refreshTokenRepository.countActiveMobileSessions(now)
                ),
                new AdminMonitoringSummaryResponse.AuditStats(
                        authSessionAuditRepository.count(),
                        authSessionAuditRepository.countByCreatedAtAfter(since),
                        authSessionAuditRepository.countByEventTypeSince("LOGIN_SUCCESS", since),
                        authSessionAuditRepository.countByEventTypeSince("LOGIN_FAILED", since),
                        authSessionAuditRepository.countByEventTypeSince("SESSION_REVOKED_LOGOUT", since)
                                + authSessionAuditRepository.countByEventTypeSince("SESSION_REVOKED_LOGOUT_ALL", since),
                        authSessionAuditRepository.countByEventTypeSince("QR_LOGIN_APPROVED", since)
                ),
                new AdminMonitoringSummaryResponse.OtpStats(
                        authOtpRepository.countByCreatedAtAfter(since),
                        authOtpRepository.countByPurposeAndCreatedAtAfter(OtpPurpose.REGISTER, since),
                        authOtpRepository.countByPurposeAndCreatedAtAfter(OtpPurpose.RESET_PASSWORD, since),
                        authOtpRepository.countByVerifiedAtAfter(since)
                ),
                new AdminMonitoringSummaryResponse.AiStats(
                        aiChatHistoryRepository.countByCreatedAtAfter(sinceOffset),
                        aiChatHistoryRepository.countByRoleAndCreatedAtAfter("user", sinceOffset),
                        aiChatHistoryRepository.countByRoleAndCreatedAtAfter("assistant", sinceOffset),
                        aiChatHistoryRepository.countDistinctUsersSince(sinceOffset)
                ),
                new AdminMonitoringSummaryResponse.QrStats(
                        authQrLoginSessionRepository.countByCreatedAtAfter(since),
                        authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.PENDING),
                        authQrLoginSessionRepository.countByApprovedAtAfter(since),
                        authQrLoginSessionRepository.countByConsumedAtAfter(since),
                        authQrLoginSessionRepository.countByStatus(QrLoginSessionStatus.REJECTED)
                ),
                new AdminMonitoringSummaryResponse.ConsentStats(
                        authLegalConsentRepository.countByGrantedTrue(),
                        authLegalConsentRepository.countByConsentTypeAndGrantedTrue("TERMS_OF_USE"),
                        authLegalConsentRepository.countByConsentTypeAndGrantedTrue("PRIVACY_POLICY"),
                        authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter("TERMS_OF_USE", since),
                        authLegalConsentRepository.countByConsentTypeAndGrantedTrueAndGrantedAtAfter("PRIVACY_POLICY", since)
                )
        );
    }

    @Transactional(readOnly = true)
    public List<AdminMonitoringEventResponse> getRecentEvents(UUID requesterId, int limit, Integer windowHours, String eventType, String platform) {
        assertMonitoringAccess(requesterId);
        int pageSize = Math.max(1, Math.min(limit, 50));
        Instant since = resolveSince(windowHours, Instant.now());
        String normalizedEventType = normalizeOptionalFilter(eventType);
        String normalizedPlatform = normalizeOptionalFilter(platform);
        return authSessionAuditRepository.findMonitoringEvents(
                        since,
                        normalizedEventType,
                        normalizedPlatform,
                        PageRequest.of(0, pageSize)
                )
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

    private Instant resolveSince(Integer windowHours, Instant now) {
        int safeWindowHours = windowHours == null ? DEFAULT_WINDOW_HOURS : Math.max(MIN_WINDOW_HOURS, Math.min(windowHours, MAX_WINDOW_HOURS));
        return now.minusSeconds(safeWindowHours * 60L * 60L);
    }

    private String normalizeOptionalFilter(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }
        return value.trim();
    }

    private String normalizeEmail(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }

    private AdminMonitoringEventResponse toEventResponse(AuthSessionAudit event) {
        return new AdminMonitoringEventResponse(
                event.getAuditId(),
                event.getEventType(),
                event.getSessionType(),
                event.getTrustLevel(),
                event.getPlatform(),
                sanitizeDeviceName(event.getDeviceName()),
                maskDeviceId(event.getDeviceId()),
                sanitizeDetail(event.getDetail()),
                resolveSeverity(event),
                event.getCreatedAt()
        );
    }

    private String resolveSeverity(AuthSessionAudit event) {
        String eventType = event.getEventType() == null ? "" : event.getEventType().toUpperCase(Locale.ROOT);
        if (eventType.contains("FAILED") || eventType.contains("REJECTED") || eventType.contains("LOCKED")) {
            return "error";
        }
        if (eventType.contains("REVOKED") || eventType.contains("PENDING") || eventType.contains("CHALLENGE")) {
            return "warning";
        }
        return "info";
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
