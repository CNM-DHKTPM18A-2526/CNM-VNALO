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
import java.util.Map;

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
    private final iuh.cnm.vnalo.core_service.kafka.producer.KafkaProducerService kafkaProducerService;

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

        FriendRequest saved = friendRequestRepository.save(request);
        
        // Notify recipient about the new friend request
        kafkaProducerService.sendRealtimeEvent(toUserId.toString(), "friend.request.received", Map.of("fromUserId", fromUserId.toString()));
        
        return saved;
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
        Friendship saved = friendshipRepository.save(friendship);
        
        // Notify both users about the new friendship
        kafkaProducerService.sendRealtimeEvent(request.getUserIdFrom().toString(), "friendship.updated", Map.of("friendId", request.getUserIdTo().toString()));
        kafkaProducerService.sendRealtimeEvent(request.getUserIdTo().toString(), "friendship.updated", Map.of("friendId", request.getUserIdFrom().toString()));
        
        return saved;
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
        Page<FriendRequest> requests = friendRequestRepository.findPendingRequestsToUser(userId, pageable);
        return mapToFriendRequestResponsePage(requests);
    }

    @Transactional(readOnly = true)
    public Page<FriendRequestResponse> getSentRequests(UUID userId, Pageable pageable) {
        Page<FriendRequest> requests = friendRequestRepository.findPendingSentRequests(userId, pageable);
        return mapToFriendRequestResponsePage(requests);
    }

    @Transactional(readOnly = true)
    public Page<FriendResponse> getFriends(UUID userId, Pageable pageable) {
        Page<Friendship> friendships = friendshipRepository.findFriendships(userId, pageable);
        return mapToFriendResponsePage(friendships, userId);
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

    private Page<FriendRequestResponse> mapToFriendRequestResponsePage(Page<FriendRequest> requests) {
        if (requests.isEmpty()) {
            return Page.empty(requests.getPageable());
        }

        java.util.Set<UUID> userIds = new java.util.HashSet<>();
        for (FriendRequest request : requests) {
            userIds.add(request.getUserIdFrom());
            userIds.add(request.getUserIdTo());
        }

        java.util.Map<UUID, UserProfile> userProfileMap = userProfileRepository.findAllById(userIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(UserProfile::getId, p -> p));

        return requests.map(request -> {
            UserProfile fromUser = userProfileMap.get(request.getUserIdFrom());
            UserProfile toUser = userProfileMap.get(request.getUserIdTo());

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
        });
    }

    private Page<FriendResponse> mapToFriendResponsePage(Page<Friendship> friendships, UUID currentUserId) {
        if (friendships.isEmpty()) {
            return Page.empty(friendships.getPageable());
        }

        java.util.Set<UUID> friendIds = new java.util.HashSet<>();
        for (Friendship friendship : friendships) {
            friendIds.add(friendship.getFriendId(currentUserId));
        }

        java.util.Map<UUID, UserProfile> userProfileMap = userProfileRepository.findAllById(friendIds)
                .stream()
                .collect(java.util.stream.Collectors.toMap(UserProfile::getId, p -> p));

        return friendships.map(friendship -> {
            UUID friendId = friendship.getFriendId(currentUserId);
            UserProfile friendProfile = userProfileMap.get(friendId);

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
        });
    }
}
