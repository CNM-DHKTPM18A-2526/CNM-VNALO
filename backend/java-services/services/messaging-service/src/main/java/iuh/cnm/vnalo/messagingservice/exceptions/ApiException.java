package iuh.cnm.vnalo.messagingservice.exceptions;

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
        super(errorCode.getMessage());
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
            case UNAUTHORIZED -> HttpStatus.UNAUTHORIZED;
            case ACCESS_DENIED, CONV_INSUFFICIENT_PERMISSION -> HttpStatus.FORBIDDEN;
            case RESOURCE_NOT_FOUND, CONV_NOT_FOUND, MSG_NOT_FOUND, CALL_NOT_FOUND,
                 NOTIF_NOT_FOUND, POLL_NOT_FOUND, POLL_OPTION_NOT_FOUND,
                 REACTION_NOT_FOUND, MSG_NOT_PINNED -> HttpStatus.NOT_FOUND;
            case VALIDATION_ERROR -> HttpStatus.BAD_REQUEST;
            case CONV_ALREADY_EXISTS, CONV_DIRECT_ALREADY_EXISTS, REACTION_ALREADY_EXISTS,
                 POLL_ALREADY_VOTED, NOTIF_DEVICE_TOKEN_EXISTS, MSG_ALREADY_PINNED -> HttpStatus.CONFLICT;
            case CONV_NOT_MEMBER, CONV_CANNOT_LEAVE_OWNER, MSG_NOT_SENDER,
                 CALL_NOT_PARTICIPANT -> HttpStatus.FORBIDDEN;
            case CONV_MEMBER_LIMIT_REACHED, CONV_USER_BANNED, CALL_ALREADY_ONGOING,
                 CALL_ALREADY_ENDED, CALL_USER_BUSY, MSG_ALREADY_DELETED,
                 POLL_ALREADY_CLOSED -> HttpStatus.UNPROCESSABLE_ENTITY;
            default -> HttpStatus.INTERNAL_SERVER_ERROR;
        };
    }
}
