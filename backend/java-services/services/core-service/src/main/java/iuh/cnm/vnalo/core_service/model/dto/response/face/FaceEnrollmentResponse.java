package iuh.cnm.vnalo.core_service.model.dto.response.face;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

/**
 * Response DTO for face enrollment operations.
 */
@Data
@Builder
public class FaceEnrollmentResponse {

    private boolean success;
    private Instant enrolledAt;
    private Double livenessScore;
    private Integer version;
    private String errorCode;
    private String message;
}
