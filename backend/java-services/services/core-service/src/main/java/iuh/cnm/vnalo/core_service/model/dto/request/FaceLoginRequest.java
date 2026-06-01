package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for face login.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FaceLoginRequest {

    @NotNull(message = "Verification Token is required")
    private String verificationToken;

    @NotNull(message = "Device ID is required")
    private String deviceId;

    private String deviceName;

    private String platform;

}
