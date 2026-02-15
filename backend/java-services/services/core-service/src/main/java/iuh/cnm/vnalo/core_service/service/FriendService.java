package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.FriendRequestResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.FriendResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.FriendRequest;
import iuh.cnm.vnalo.core_service.model.entity.social.Friendship;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.enums.FriendRequestStatus;
import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import iuh.cnm.vnalo.core_service.repository.social.BlockListRepository;
import iuh.cnm.vnalo.core_service.repository.social.FriendRequestRepository;
import iuh.cnm.vnalo.core_service.repository.social.FriendshipRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Service for managing friend requests and friendships.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FriendService {

    private final FriendRequestRepository friendRequestRepository;
    private final FriendshipRepository friendshipRepository;
    private final BlockListRepository blockListRepository;
    private final UserProfileRepository userProfileRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;

    /**
     * Send a friend request to another user.
     * Validates privacy settings, block status, and existing relationships.
     */
    @Transactional
    public FriendRequest sendFriendRequest(UUID fromUserId, UUID toUserId, String message, FriendshipSource source) {
        log.info("Sending friend request: {} -> {} via {}", fromUserId, toUserId, source);

        // Cannot add self as friend
        if (fromUserId.equals(toUserId)) {
            throw new ApiException(ErrorCode.SOCIAL_CANNOT_ADD_SELF);
        }

        // Target user must exist
        if (!userProfileRepository.existsById(toUserId)) {
            throw new ApiException(ErrorCode.USER_NOT_FOUND);
        }

        // Cannot send if already friends
        if (friendshipRepository.areFriends(fromUserId, toUserId)) {
            throw new ApiException(ErrorCode.SOCIAL_ALREADY_FRIENDS);
        }

        // Cannot send if pending request exists (either direction)
        if (friendRequestRepository.existsPendingBetween(fromUserId, toUserId)) {
            throw new ApiException(ErrorCode.SOCIAL_REQUEST_ALREADY_SENT);
        }

        // Cannot send if either user has blocked the other
        if (blockListRepository.existsBlockBetween(fromUserId, toUserId)) {
            throw new ApiException(ErrorCode.SOCIAL_USER_BLOCKED);
        }

        // Check recipient's privacy settings
        UserPrivacySetting privacySettings = userPrivacySettingRepository.findById(toUserId)
                .orElseGet(() -> UserPrivacySetting.createDefault(toUserId));

        if (!canSendFriendRequest(source, privacySettings)) {
            throw new ApiException(ErrorCode.SOCIAL_PRIVACY_RESTRICTION);
        }

        FriendRequest request = FriendRequest.builder()
                .userIdFrom(fromUserId)
                .userIdTo(toUserId)
                .message(message)
                .source(source)
                .status(FriendRequestStatus.PENDING)
                .build();

        return friendRequestRepository.save(request);
    }

    /**
     * Check if friend request is allowed based on source and privacy settings.
     */
    private boolean canSendFriendRequest(FriendshipSource source, UserPrivacySetting settings) {
        if (source == null) {
            return true; // Default allow if no source specified
        }
        return switch (source) {
            case CONTACT_IMPORT -> settings.getAllowFriendRequestByPhone();
            case QR -> settings.getAllowFriendRequestByQrCode();
            case GROUP -> settings.getAllowFriendRequestBySharedGroup();
            case SUGGESTION -> settings.getAllowFriendRequestBySuggestion();
            case SEARCH -> true; // Search is always allowed
        };
    }

    /**
     * Accept a friend request.
     */
    @Transactional
    public Friendship acceptFriendRequest(UUID requestId, UUID userId) {
        FriendRequest request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND));

        if (!request.getUserIdTo().equals(userId)) {
            throw new ApiException(ErrorCode.SOCIAL_NOT_REQUEST_RECIPIENT);
        }

        if (!request.isPending()) {
            throw new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND);
        }

        request.accept();
        friendRequestRepository.save(request);

        Friendship friendship = Friendship.create(request.getUserIdFrom(), request.getUserIdTo(), request.getSource());
        return friendshipRepository.save(friendship);
    }

    /**
     * Decline a friend request.
     */
    @Transactional
    public void declineFriendRequest(UUID requestId, UUID userId) {
        FriendRequest request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND));

        if (!request.getUserIdTo().equals(userId)) {
            throw new ApiException(ErrorCode.SOCIAL_NOT_REQUEST_RECIPIENT);
        }

        if (!request.isPending()) {
            throw new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND);
        }

        request.decline();
        friendRequestRepository.save(request);
    }

    @Transactional
    public void cancelFriendRequest(UUID requestId, UUID userId) {
        FriendRequest request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND));

        if (!request.getUserIdFrom().equals(userId)) {
            throw new ApiException(ErrorCode.SOCIAL_NOT_REQUEST_SENDER);
        }

        if (!request.isPending()) {
            throw new ApiException(ErrorCode.SOCIAL_REQUEST_NOT_FOUND);
        }

        request.cancel();
        friendRequestRepository.save(request);
    }

    @Transactional(readOnly = true)
    public Page<FriendRequestResponse> getPendingRequests(UUID userId, Pageable pageable) {
        return friendRequestRepository.findPendingRequestsToUser(userId, pageable)
                .map(this::mapToFriendRequestResponse);
    }

    @Transactional(readOnly = true)
    public Page<FriendRequestResponse> getSentRequests(UUID userId, Pageable pageable) {
        return friendRequestRepository.findPendingSentRequests(userId, pageable)
                .map(this::mapToFriendRequestResponse);
    }

    @Transactional(readOnly = true)
    public Page<FriendResponse> getFriends(UUID userId, Pageable pageable) {
        return friendshipRepository.findFriendships(userId, pageable)
                .map(friendship -> mapToFriendResponse(friendship, userId));
    }

    @Transactional
    public void unfriend(UUID userId, UUID friendId) {
        if (!friendshipRepository.areFriends(userId, friendId)) {
            throw new ApiException(ErrorCode.SOCIAL_NOT_FRIENDS);
        }
        friendshipRepository.deleteFriendship(userId, friendId);
    }

    @Transactional(readOnly = true)
    public boolean areFriends(UUID userA, UUID userB) {
        return friendshipRepository.areFriends(userA, userB);
    }

    @Transactional(readOnly = true)
    public long countFriends(UUID userId) {
        return friendshipRepository.countFriends(userId);
    }

    @Transactional(readOnly = true)
    public long countPendingRequests(UUID userId) {
        return friendRequestRepository.countPendingRequests(userId);
    }

    private FriendRequestResponse mapToFriendRequestResponse(FriendRequest request) {
        UserProfile fromUser = userProfileRepository.findById(request.getUserIdFrom()).orElse(null);
        UserProfile toUser = userProfileRepository.findById(request.getUserIdTo()).orElse(null);

        return FriendRequestResponse.builder()
                .id(request.getRequestId())
                .fromUserId(request.getUserIdFrom())
                .fromUserDisplayName(fromUser != null ? fromUser.getDisplayName() : null)
                .fromUserAvatarUrl(fromUser != null ? fromUser.getAvatarUrl() : null)
                .toUserId(request.getUserIdTo())
                .toUserDisplayName(toUser != null ? toUser.getDisplayName() : null)
                .toUserAvatarUrl(toUser != null ? toUser.getAvatarUrl() : null)
                .message(request.getMessage())
                .source(request.getSource())
                .status(request.getStatus())
                .createdAt(request.getCreatedAt())
                .respondedAt(request.getRespondedAt())
                .build();
    }

    private FriendResponse mapToFriendResponse(Friendship friendship, UUID currentUserId) {
        UUID friendId = friendship.getFriendId(currentUserId);
        UserProfile friendProfile = userProfileRepository.findById(friendId).orElse(null);

        return FriendResponse.builder()
                .friendshipId(friendship.getFriendshipId())
                .friendId(friendId)
                .displayName(friendProfile != null ? friendProfile.getDisplayName() : null)
                .avatarUrl(friendProfile != null ? friendProfile.getAvatarUrl() : null)
                .statusMessage(friendProfile != null ? friendProfile.getStatusMessage() : null)
                .nickname(friendship.getNicknameForFriend(currentUserId))
                .source(friendship.getSource())
                .friendsSince(friendship.getCreatedAt())
                .build();
    }
}
