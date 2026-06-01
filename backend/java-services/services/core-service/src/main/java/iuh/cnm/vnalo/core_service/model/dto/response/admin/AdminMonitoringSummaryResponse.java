package iuh.cnm.vnalo.core_service.model.dto.response.admin;

import java.time.Instant;

public record AdminMonitoringSummaryResponse(
        Instant generatedAt,
        String accessMode,
        AccountStats accounts,
        SessionStats sessions,
        AuditStats audits,
        OtpStats otp,
        AiStats ai,
        QrStats qr
) {
    public record AccountStats(long total, long active, long locked, long disabled, long pendingVerification, long withFailedLogins, long failedLoginAttemptsTotal) {}
    public record SessionStats(long activeRefreshTokens, long revokedLast24Hours, long activeMobileSessions) {}
    public record AuditStats(long totalEvents, long last24Hours, long loginSuccessLast24Hours, long loginFailureLast24Hours, long logoutLast24Hours, long qrApprovalLast24Hours) {}
    public record OtpStats(long last24Hours, long registerLast24Hours, long resetPasswordLast24Hours, long verifiedLast24Hours) {}
    public record AiStats(long messagesLast24Hours, long userPromptsLast24Hours, long assistantRepliesLast24Hours, long distinctActiveUsersLast24Hours) {}
    public record QrStats(long createdLast24Hours, long pendingNow, long approvedLast24Hours, long consumedLast24Hours, long rejectedTotal) {}
}
