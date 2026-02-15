package iuh.cnm.vnalo.core_service.model.dto.response;

import iuh.cnm.vnalo.core_service.model.enums.FriendRequestStatus;
import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

/**
 * Response DTO for friend request information.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FriendRequestResponse {

    private UUID id;
    private UUID fromUserId;
    private String fromUserDisplayName;
    private String fromUserAvatarUrl;
    private UUID toUserId;
    private String toUserDisplayName;
    private String toUserAvatarUrl;
    private String message;
    private FriendshipSource source;
    private FriendRequestStatus status;
    private Instant createdAt;
    private Instant respondedAt;
}
