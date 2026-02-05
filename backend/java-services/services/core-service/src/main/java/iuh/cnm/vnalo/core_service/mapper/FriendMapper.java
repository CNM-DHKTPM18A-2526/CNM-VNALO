package iuh.cnm.vnalo.core_service.mapper;

import iuh.cnm.vnalo.core_service.model.dto.response.FriendRequestResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.FriendResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.FriendRequest;
import iuh.cnm.vnalo.core_service.model.entity.social.Friendship;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Mapper for converting between Friend entities and DTOs.
 */
@Component
public class FriendMapper {

    /**
     * Map FriendRequest entity to FriendRequestResponse.
     *
     * @param request     the friend request entity
     * @param fromProfile the sender's profile (optional)
     * @param toProfile   the recipient's profile (optional)
     * @return FriendRequestResponse DTO
     */
    public FriendRequestResponse toFriendRequestResponse(FriendRequest request, 
                                                          UserProfile fromProfile, 
                                                          UserProfile toProfile) {
        if (request == null) {
            return null;
        }
        
        return FriendRequestResponse.builder()
                .id(request.getRequestId())
                .fromUserId(request.getUserIdFrom())
                .fromUserDisplayName(fromProfile != null ? fromProfile.getDisplayName() : null)
                .fromUserAvatarUrl(fromProfile != null ? fromProfile.getAvatarUrl() : null)
                .toUserId(request.getUserIdTo())
                .toUserDisplayName(toProfile != null ? toProfile.getDisplayName() : null)
                .toUserAvatarUrl(toProfile != null ? toProfile.getAvatarUrl() : null)
                .message(request.getMessage())
                .status(request.getStatus())
                .createdAt(request.getCreatedAt())
                .respondedAt(request.getRespondedAt())
                .build();
    }

    /**
     * Map Friendship entity to FriendResponse.
     *
     * @param friendship    the friendship entity
     * @param currentUserId the current user's ID
     * @param friendProfile the friend's profile
     * @return FriendResponse DTO
     */
    public FriendResponse toFriendResponse(Friendship friendship, 
                                           UUID currentUserId, 
                                           UserProfile friendProfile) {
        if (friendship == null) {
            return null;
        }
        
        UUID friendId = friendship.getFriendId(currentUserId);
        String nickname = friendship.getNicknameForFriend(currentUserId);
        
        return FriendResponse.builder()
                .friendshipId(friendship.getFriendshipId())
                .friendId(friendId)
                .displayName(friendProfile != null ? friendProfile.getDisplayName() : null)
                .avatarUrl(friendProfile != null ? friendProfile.getAvatarUrl() : null)
                .nickname(nickname)
                .source(friendship.getSource())
                .friendsSince(friendship.getCreatedAt())
                .build();
    }
}
