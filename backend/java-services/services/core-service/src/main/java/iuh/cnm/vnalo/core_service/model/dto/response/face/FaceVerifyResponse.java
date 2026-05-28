package iuh.cnm.vnalo.core_service.model.dto.response.face;

import lombok.Builder;
import lombok.Data;

/**
 * Response DTO for face verification.
 */
@Data
@Builder
public class FaceVerifyResponse {

    private boolean verified;
    private Double confidence;
    private Double threshold;
    private String decision;
    private Long inferenceTimeMs;
    private String errorCode;
    private String message;
    private String verificationToken;
}
