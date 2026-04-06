package iuh.cnm.vnalo.analytics_service.exception;

import iuh.cnm.vnalo.analytics_service.model.dto.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Handle custom API exceptions (business logic validation, etc.)
     */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleApiException(ApiException e) {
        log.warn("API exception: {} - {}", e.getErrorCode().getCode(), e.getMessage());
        HttpStatus status = e.getErrorCode() == ErrorCode.ANALYTICS_FORBIDDEN
                ? HttpStatus.FORBIDDEN
                : HttpStatus.BAD_REQUEST;
        return ResponseEntity.status(status)
                .body(ApiResponse.error(e.getMessage(), e.getErrorCode().getCode()));
    }

    /**
     * Handle type conversion errors (e.g., invalid LocalDate format)
     * Spring automatically converts @RequestParam values and raises this on failure
     */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethodArgumentTypeMismatch(
            MethodArgumentTypeMismatchException e) {
        String message = String.format(
                "Invalid %s parameter: '%s' - expected %s",
                e.getName(),
                e.getValue(),
                e.getRequiredType().getSimpleName()
        );
        log.warn("Type mismatch: {}", message);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error(message, ErrorCode.ANALYTICS_INVALID_DATE_RANGE.getCode()));
    }

    /**
     * Handle generic exceptions
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleGenericException(Exception e) {
        log.error("Unexpected error", e);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.error("Internal server error", "INTERNAL_ERROR"));
    }
}