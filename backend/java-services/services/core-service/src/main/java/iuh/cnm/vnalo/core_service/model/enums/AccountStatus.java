package iuh.cnm.vnalo.core_service.model.enums;

/**
 * Account status types.
 */
public enum AccountStatus {
    /**
     * Account is active and fully operational.
     */
    ACTIVE,

    /**
     * Account is temporarily locked (auto-unlock after cooldown period).
     */
    LOCKED,

    /**
     * Account is disabled by admin (requires manual reactivation).
     */
    DISABLED,

    /**
     * Account is pending verification (OTP/email not yet verified).
     */
    PENDING_VERIFICATION
}
