package iuh.cnm.vnalo.core_service.model.enums;

/**
 * Purpose of OTP (One-Time Password) generation.
 */
public enum OtpPurpose {
    /**
     * New account registration verification.
     */
    REGISTER,

    /**
     * Password reset verification.
     */
    RESET_PASSWORD,

    /**
     * Two-factor authentication login.
     */
    LOGIN,

    /**
     * Phone number change verification.
     */
    CHANGE_PHONE,

    /**
     * Email address change verification.
     */
    CHANGE_EMAIL
}
