package iuh.cnm.vnalo.moderation_service.model.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.http.HttpStatus;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApiResponse<T> {
    private boolean success;
    private String message;
    private T data;
    private Integer code;
    private String errorCode;
    private Object details;

    public static <T> ApiResponse<T> success(String message, T data) {
        return ApiResponse.<T>builder()
                .success(true)
                .message(message)
                .data(data)
                .code(HttpStatus.OK.value())
                .errorCode(null)
                .details(null)
                .build();
    }

    public static <T> ApiResponse<T> error(String errorCode, String message) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .errorCode(errorCode)
                .code(HttpStatus.BAD_REQUEST.value())
                .details(null)
                .build();
    }

    public static <T> ApiResponse<T> error(String errorCode, String message, Object details) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .errorCode(errorCode)
                .code(HttpStatus.BAD_REQUEST.value())
                .details(details)
                .build();
    }

    public static <T> ApiResponse<T> error(String errorCode, String message, HttpStatus status) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .errorCode(errorCode)
                .code(status.value())
                .details(null)
                .build();
    }

    public static <T> ApiResponse<T> error(String errorCode, String message, HttpStatus status, Object details) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .errorCode(errorCode)
                .code(status.value())
                .details(details)
                .build();
    }

    public static <T> ApiResponse<T> error(String message) {
        return ApiResponse.<T>builder()
                .success(false)
                .message(message)
                .errorCode("ERR_400")
                .code(HttpStatus.BAD_REQUEST.value())
                .details(null)
                .build();
    }
}