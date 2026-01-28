package iuh.cnm.vnalo.core_service.model.dto.response;

import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for friend information.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FriendResponse {

    private UUID friendshipId;
    private UUID friendId;
    private String displayName;
    private String avatarUrl;
    private String statusMessage;
    private String nickname;
    private FriendshipSource source;
    private Instant friendsSince;
}
