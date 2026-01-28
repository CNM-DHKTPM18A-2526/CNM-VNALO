package iuh.cnm.vnalo.core_service.model.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

/**
 * Request DTO for sending a friend request.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FriendRequestDto {

    /**
     * Target user ID to send friend request to.
     */
    @NotNull(message = "Target user ID is required")
    private UUID toUserId;

    /**
     * Optional message to include with the request.
     */
    @Size(max = 200, message = "Message cannot exceed 200 characters")
    private String message;
}
