package iuh.cnm.vnalo.moderation_service.exception;

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
        return code.getStatus();
    }
}