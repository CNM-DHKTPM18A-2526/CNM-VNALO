package iuh.cnm.vnalo.core_service.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ApiException extends RuntimeException {

    private final ErrorCode errorCode;
    private final HttpStatus status;
    private final String details;

    public ApiException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
        this.status = resolveStatus(errorCode);
        this.details = null;
    }

    public ApiException(ErrorCode errorCode, String details) {
        super(errorCode.getMessage() + ": " + details);
        this.errorCode = errorCode;
        this.status = resolveStatus(errorCode);
        this.details = details;
    }

    public ApiException(ErrorCode errorCode, HttpStatus status) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
        this.status = status;
        this.details = null;
    }

    private HttpStatus resolveStatus(ErrorCode code) {
        return switch (code) {
            case INTERNAL_ERROR -> HttpStatus.INTERNAL_SERVER_ERROR;
            case VALIDATION_ERROR -> HttpStatus.BAD_REQUEST;
            case RESOURCE_NOT_FOUND, USER_NOT_FOUND, USER_PROFILE_NOT_FOUND,
                 SOCIAL_REQUEST_NOT_FOUND -> HttpStatus.NOT_FOUND;
            case ACCESS_DENIED, SOCIAL_NOT_REQUEST_RECIPIENT, SOCIAL_PRIVACY_RESTRICTION,
                 SOCIAL_USER_BLOCKED, SOCIAL_BLOCKED_BY_USER -> HttpStatus.FORBIDDEN;
            case UNAUTHORIZED, AUTH_INVALID_CREDENTIALS, AUTH_TOKEN_EXPIRED,
                 AUTH_TOKEN_INVALID, AUTH_REFRESH_TOKEN_EXPIRED,
                 AUTH_REFRESH_TOKEN_REVOKED -> HttpStatus.UNAUTHORIZED;
            case AUTH_ACCOUNT_DISABLED, AUTH_ACCOUNT_LOCKED -> HttpStatus.FORBIDDEN;
            case AUTH_PHONE_ALREADY_EXISTS, SOCIAL_ALREADY_FRIENDS,
                 SOCIAL_REQUEST_ALREADY_SENT, SOCIAL_ALREADY_BLOCKED,
                 FACE_ALREADY_ENROLLED -> HttpStatus.CONFLICT;
            case FACE_RATE_LIMITED -> HttpStatus.TOO_MANY_REQUESTS;
            case FACE_SERVICE_UNAVAILABLE -> HttpStatus.SERVICE_UNAVAILABLE;
            default -> HttpStatus.BAD_REQUEST;
        };
    }
}
