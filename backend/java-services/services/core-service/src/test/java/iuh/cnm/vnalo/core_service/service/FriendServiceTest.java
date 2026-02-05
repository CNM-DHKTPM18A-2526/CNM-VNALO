package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("FriendService Unit Tests")
class FriendServiceTest {

    @Mock
    private FriendRequestRepository friendRequestRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private BlockListRepository blockListRepository;

    @Mock
    private UserProfileRepository userProfileRepository;

    @Mock
    private UserPrivacySettingRepository userPrivacySettingRepository;

    @InjectMocks
    private FriendService friendService;

    private UUID userId1;
    private UUID userId2;
    private UUID requestId;

    @BeforeEach
    void setUp() {
        userId1 = UUID.randomUUID();
        userId2 = UUID.randomUUID();
        requestId = UUID.randomUUID();
    }

    @Nested
    @DisplayName("Send Friend Request Tests")
    class SendFriendRequestTests {

        @Test
        @DisplayName("Should send friend request successfully")
        void shouldSendFriendRequestSuccessfully() {
            // Given
            when(userProfileRepository.existsById(userId2)).thenReturn(true);
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(userId1, userId2)).thenReturn(false);
            when(blockListRepository.existsBlockBetween(userId1, userId2)).thenReturn(false);
            when(userPrivacySettingRepository.findById(userId2))
                    .thenReturn(Optional.of(UserPrivacySetting.createDefault(userId2)));
            when(friendRequestRepository.save(any(FriendRequest.class))).thenAnswer(inv -> {
                FriendRequest req = inv.getArgument(0);
                req.setRequestId(requestId);
                return req;
            });

            // When
            FriendRequest result = friendService.sendFriendRequest(userId1, userId2, "Hi!", FriendshipSource.SEARCH);

            // Then
            assertNotNull(result);
            assertEquals(userId1, result.getUserIdFrom());
            assertEquals(userId2, result.getUserIdTo());
            assertEquals(FriendRequestStatus.PENDING, result.getStatus());
            verify(friendRequestRepository).save(any(FriendRequest.class));
        }

        @Test
        @DisplayName("Should throw exception when adding self")
        void shouldThrowException_WhenAddingSelf() {
            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.sendFriendRequest(userId1, userId1, null, FriendshipSource.SEARCH));

            assertEquals(ErrorCode.SOCIAL_CANNOT_ADD_SELF, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when target user not found")
        void shouldThrowException_WhenTargetUserNotFound() {
            // Given
            when(userProfileRepository.existsById(userId2)).thenReturn(false);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.sendFriendRequest(userId1, userId2, null, FriendshipSource.SEARCH));

            assertEquals(ErrorCode.USER_NOT_FOUND, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when already friends")
        void shouldThrowException_WhenAlreadyFriends() {
            // Given
            when(userProfileRepository.existsById(userId2)).thenReturn(true);
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.sendFriendRequest(userId1, userId2, null, FriendshipSource.SEARCH));

            assertEquals(ErrorCode.SOCIAL_ALREADY_FRIENDS, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when pending request exists")
        void shouldThrowException_WhenPendingRequestExists() {
            // Given
            when(userProfileRepository.existsById(userId2)).thenReturn(true);
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(userId1, userId2)).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.sendFriendRequest(userId1, userId2, null, FriendshipSource.SEARCH));

            assertEquals(ErrorCode.SOCIAL_REQUEST_ALREADY_SENT, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when user is blocked")
        void shouldThrowException_WhenUserIsBlocked() {
            // Given
            when(userProfileRepository.existsById(userId2)).thenReturn(true);
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(false);
            when(friendRequestRepository.existsPendingBetween(userId1, userId2)).thenReturn(false);
            when(blockListRepository.existsBlockBetween(userId1, userId2)).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.sendFriendRequest(userId1, userId2, null, FriendshipSource.SEARCH));

            assertEquals(ErrorCode.SOCIAL_USER_BLOCKED, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Accept Friend Request Tests")
    class AcceptFriendRequestTests {

        @Test
        @DisplayName("Should accept friend request successfully")
        void shouldAcceptFriendRequestSuccessfully() {
            // Given
            FriendRequest request = FriendRequest.builder()
                    .userIdFrom(userId1)
                    .userIdTo(userId2)
                    .status(FriendRequestStatus.PENDING)
                    .source(FriendshipSource.SEARCH)
                    .build();
            request.setRequestId(requestId);

            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(request));
            when(friendRequestRepository.save(any(FriendRequest.class))).thenAnswer(inv -> inv.getArgument(0));
            when(friendshipRepository.save(any(Friendship.class))).thenAnswer(inv -> {
                Friendship f = inv.getArgument(0);
                f.setFriendshipId(UUID.randomUUID());
                return f;
            });

            // When
            Friendship result = friendService.acceptFriendRequest(requestId, userId2);

            // Then
            assertNotNull(result);
            verify(friendRequestRepository).save(any(FriendRequest.class));
            verify(friendshipRepository).save(any(Friendship.class));
        }

        @Test
        @DisplayName("Should throw exception when request not found")
        void shouldThrowException_WhenRequestNotFound() {
            // Given
            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.empty());

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.acceptFriendRequest(requestId, userId2));

            assertEquals(ErrorCode.SOCIAL_REQUEST_NOT_FOUND, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when not the recipient")
        void shouldThrowException_WhenNotTheRecipient() {
            // Given
            FriendRequest request = FriendRequest.builder()
                    .userIdFrom(userId1)
                    .userIdTo(userId2)
                    .status(FriendRequestStatus.PENDING)
                    .build();
            request.setRequestId(requestId);

            when(friendRequestRepository.findById(requestId)).thenReturn(Optional.of(request));

            // When & Then - userId1 tries to accept (but userId2 is the recipient)
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.acceptFriendRequest(requestId, userId1));

            assertEquals(ErrorCode.SOCIAL_NOT_REQUEST_RECIPIENT, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Unfriend Tests")
    class UnfriendTests {

        @Test
        @DisplayName("Should unfriend successfully")
        void shouldUnfriendSuccessfully() {
            // Given
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(true);

            // When
            friendService.unfriend(userId1, userId2);

            // Then
            verify(friendshipRepository).deleteFriendship(userId1, userId2);
        }

        @Test
        @DisplayName("Should throw exception when not friends")
        void shouldThrowException_WhenNotFriends() {
            // Given
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(false);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> friendService.unfriend(userId1, userId2));

            assertEquals(ErrorCode.SOCIAL_NOT_FRIENDS, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Are Friends Tests")
    class AreFriendsTests {

        @Test
        @DisplayName("Should return true when users are friends")
        void shouldReturnTrue_WhenUsersAreFriends() {
            // Given
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(true);

            // When
            boolean result = friendService.areFriends(userId1, userId2);

            // Then
            assertTrue(result);
        }

        @Test
        @DisplayName("Should return false when users are not friends")
        void shouldReturnFalse_WhenUsersAreNotFriends() {
            // Given
            when(friendshipRepository.areFriends(userId1, userId2)).thenReturn(false);

            // When
            boolean result = friendService.areFriends(userId1, userId2);

            // Then
            assertFalse(result);
        }
    }
}
