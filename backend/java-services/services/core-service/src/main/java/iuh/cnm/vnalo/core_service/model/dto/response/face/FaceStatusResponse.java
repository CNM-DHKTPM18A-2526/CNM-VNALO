package iuh.cnm.vnalo.core_service.model.dto.response.face;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

/**
 * Response DTO for face enrollment status query.
 */
@Data
@Builder
public class FaceStatusResponse {

    private boolean enrolled;
    private Instant enrolledAt;
    private Integer version;
    private String errorCode;
    private String message;
}
