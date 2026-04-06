package iuh.cnm.vnalo.core_service.exception;

public enum ErrorCode {
    // General
    INTERNAL_ERROR("ERR_500", "Internal server error"),
    VALIDATION_ERROR("ERR_400", "Validation failed"),
    RESOURCE_NOT_FOUND("ERR_404", "Resource not found"),
    ACCESS_DENIED("ERR_403", "Access denied"),
    UNAUTHORIZED("ERR_401", "Unauthorized"),

    // Authentication
    AUTH_INVALID_CREDENTIALS("AUTH_001", "Invalid credentials"),
    AUTH_ACCOUNT_DISABLED("AUTH_002", "Account is disabled"),
    AUTH_ACCOUNT_LOCKED("AUTH_003", "Account is locked"),
    AUTH_TOKEN_EXPIRED("AUTH_004", "Token has expired"),
    AUTH_TOKEN_INVALID("AUTH_005", "Invalid token"),
    AUTH_REFRESH_TOKEN_EXPIRED("AUTH_006", "Refresh token has expired"),
    AUTH_REFRESH_TOKEN_REVOKED("AUTH_007", "Refresh token has been revoked"),
    AUTH_PHONE_ALREADY_EXISTS("AUTH_008", "Phone number already registered"),
    AUTH_OTP_EXPIRED("AUTH_009", "OTP has expired"),
    AUTH_OTP_INVALID("AUTH_010", "Invalid OTP"),
    AUTH_OTP_MAX_ATTEMPTS("AUTH_011", "Maximum OTP attempts exceeded"),
    AUTH_OTP_RATE_LIMITED("AUTH_012", "Too many OTP requests, please try again later"),
    AUTH_OTP_COOLDOWN("AUTH_013", "Please wait before requesting another OTP"),
    AUTH_OTP_REQUIRED("AUTH_014", "OTP verification is required"),
    AUTH_PASSWORD_MISMATCH("AUTH_015", "Current password is incorrect"),
    AUTH_PASSWORD_POLICY("AUTH_016", "New password does not meet requirements"),
    AUTH_ACCOUNT_NOT_FOUND_BY_PHONE("AUTH_017", "No account found with this phone number"),
    AUTH_EMAIL_ALREADY_EXISTS("AUTH_018", "Email already registered"),
    AUTH_ACCOUNT_NOT_FOUND_BY_EMAIL("AUTH_019", "No account found with this email"),
    AUTH_OTP_DELIVERY_FAILED("AUTH_020", "Unable to deliver OTP"),

    // User
    USER_NOT_FOUND("USER_001", "User not found"),
    USER_PROFILE_NOT_FOUND("USER_002", "User profile not found"),
    USER_PHONE_NOT_VERIFIED("USER_003", "Phone number not verified"),
    USER_UPDATE_FAILED("USER_004", "Failed to update user"),

    // Social
    SOCIAL_CANNOT_ADD_SELF("SOCIAL_001", "Cannot add yourself as friend"),
    SOCIAL_ALREADY_FRIENDS("SOCIAL_002", "Already friends with this user"),
    SOCIAL_REQUEST_ALREADY_SENT("SOCIAL_003", "Friend request already sent"),
    SOCIAL_REQUEST_NOT_FOUND("SOCIAL_004", "Friend request not found"),
    SOCIAL_NOT_REQUEST_RECIPIENT("SOCIAL_005", "You are not the recipient of this request"),
    SOCIAL_NOT_FRIENDS("SOCIAL_006", "Not friends with this user"),
    SOCIAL_USER_BLOCKED("SOCIAL_007", "You have blocked this user"),
    SOCIAL_BLOCKED_BY_USER("SOCIAL_008", "You are blocked by this user"),
    SOCIAL_ALREADY_BLOCKED("SOCIAL_009", "User is already blocked"),
    SOCIAL_PRIVACY_RESTRICTION("SOCIAL_010", "Cannot perform action due to privacy settings"),
    SOCIAL_NOT_BLOCKED("SOCIAL_011", "User is not blocked"),
    SOCIAL_NOT_REQUEST_SENDER("SOCIAL_012", "You are not the sender of this request");

    private final String code;
    private final String message;

    ErrorCode(String code, String message) {
        this.code = code;
        this.message = message;
    }

    public String getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }
}
