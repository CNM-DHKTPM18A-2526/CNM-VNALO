package iuh.cnm.vnalo.moderation_service.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {
    // General
    INTERNAL_ERROR("ERR_500", "Internal server error", HttpStatus.INTERNAL_SERVER_ERROR),
    VALIDATION_ERROR("ERR_400", "Validation failed", HttpStatus.BAD_REQUEST),
    RESOURCE_NOT_FOUND("ERR_404", "Resource not found", HttpStatus.NOT_FOUND),
    ACCESS_DENIED("ERR_403", "Access denied", HttpStatus.FORBIDDEN),
    UNAUTHORIZED("ERR_401", "Unauthorized", HttpStatus.UNAUTHORIZED),

    // Moderation
    MODERATION_REPORT_NOT_FOUND("MOD_001", "Report not found", HttpStatus.NOT_FOUND),
    MODERATION_CASE_NOT_FOUND("MOD_002", "Moderation case not found", HttpStatus.NOT_FOUND),
    MODERATION_ACTION_NOT_FOUND("MOD_003", "Moderation action not found", HttpStatus.NOT_FOUND),
    MODERATION_INVALID_TARGET_TYPE("MOD_004", "Invalid target type", HttpStatus.BAD_REQUEST),
    MODERATION_CASE_ALREADY_ASSIGNED("MOD_005", "Case is already assigned", HttpStatus.BAD_REQUEST),
    MODERATION_INSUFFICIENT_PERMISSIONS("MOD_006", "Insufficient permissions for this action", HttpStatus.FORBIDDEN),
    MODERATION_REPORT_ALREADY_RESOLVED("MOD_007", "Report is already resolved", HttpStatus.BAD_REQUEST),
    MODERATION_INVALID_STATUS_TRANSITION("MOD_008", "Invalid status transition", HttpStatus.BAD_REQUEST),
    MODERATION_TARGET_NOT_FOUND("MOD_009", "Moderation target not found", HttpStatus.NOT_FOUND),
    MODERATION_FORBIDDEN("MOD_010", "Access forbidden", HttpStatus.FORBIDDEN);

    private final String code;
    private final String message;
    private final HttpStatus status;

    ErrorCode(String code, String message, HttpStatus status) {
        this.code = code;
        this.message = message;
        this.status = status;
    }

    public String getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }

    public HttpStatus getStatus() {
        return status;
    }
}