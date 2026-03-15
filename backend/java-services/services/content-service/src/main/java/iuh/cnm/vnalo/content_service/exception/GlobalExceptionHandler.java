package iuh.cnm.vnalo.content_service.exception;

import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<?> handleApiException(ApiException ex) {
        ErrorCode errorCode = ex.getErrorCode();

        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", OffsetDateTime.now());
        body.put("code", errorCode.getCode());
        body.put("message", errorCode.getMessage());

        return ResponseEntity.status(errorCode.getStatus()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<?> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("timestamp", OffsetDateTime.now());
        body.put("code", ErrorCode.INVALID_REQUEST.getCode());
        body.put("message", ErrorCode.INVALID_REQUEST.getMessage());

        Map<String, String> errors = new HashMap<>();
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            errors.put(fieldError.getField(), fieldError.getDefaultMessage());
        }
        body.put("errors", errors);

        return ResponseEntity.badRequest().body(body);
    }

   @ExceptionHandler(Exception.class)
public ResponseEntity<?> handleException(Exception ex) {
    ex.printStackTrace();

    Map<String, Object> body = new HashMap<>();
    body.put("timestamp", OffsetDateTime.now());
    body.put("code", ErrorCode.INTERNAL_ERROR.getCode());
    body.put("message", ex.getMessage());

    return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.getStatus()).body(body);
}
}