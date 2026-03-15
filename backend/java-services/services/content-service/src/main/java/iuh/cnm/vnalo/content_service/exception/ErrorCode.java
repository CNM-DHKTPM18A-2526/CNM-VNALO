package iuh.cnm.vnalo.content_service.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    POST_NOT_FOUND("CONTENT_001", "Post not found", HttpStatus.NOT_FOUND),
    COMMENT_NOT_FOUND("CONTENT_002", "Comment not found", HttpStatus.NOT_FOUND),
    INVALID_REQUEST("CONTENT_003", "Invalid request", HttpStatus.BAD_REQUEST),
    FORBIDDEN("CONTENT_004", "You do not have permission to perform this action", HttpStatus.FORBIDDEN),
    INTERNAL_ERROR("CONTENT_999", "Internal server error", HttpStatus.INTERNAL_SERVER_ERROR);

    private final String code;
    private final String message;
    private final HttpStatus status;
}