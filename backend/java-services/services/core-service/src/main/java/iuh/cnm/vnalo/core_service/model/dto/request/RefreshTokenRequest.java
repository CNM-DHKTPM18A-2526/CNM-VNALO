package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for token refresh.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RefreshTokenRequest {

    /**
     * Current refresh token.
     */
    @NotBlank(message = "Refresh token is required")
    private String refreshToken;
}
