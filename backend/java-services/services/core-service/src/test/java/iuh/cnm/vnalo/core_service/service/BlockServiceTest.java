package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.BlockedUserResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.BlockList;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.repository.social.BlockListRepository;
import iuh.cnm.vnalo.core_service.repository.social.FriendshipRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("BlockService Unit Tests")
class BlockServiceTest {

    @Mock
    private BlockListRepository blockListRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private UserProfileRepository userProfileRepository;

    @InjectMocks
    private BlockService blockService;

    private UUID blockerId;
    private UUID blockedId;

    @BeforeEach
    void setUp() {
        blockerId = UUID.randomUUID();
        blockedId = UUID.randomUUID();
    }

    @Nested
    @DisplayName("Block User Tests")
    class BlockUserTests {

        @Test
        @DisplayName("Should block user successfully")
        void shouldBlockUserSuccessfully() {
            // Given
            when(userProfileRepository.existsById(blockedId)).thenReturn(true);
            when(blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(false);
            when(friendshipRepository.areFriends(blockerId, blockedId)).thenReturn(false);
            when(blockListRepository.save(any(BlockList.class))).thenAnswer(inv -> inv.getArgument(0));

            // When
            blockService.blockUser(blockerId, blockedId, true, true, false);

            // Then
            verify(blockListRepository).save(any(BlockList.class));
        }

        @Test
        @DisplayName("Should remove friendship when blocking a friend")
        void shouldRemoveFriendship_WhenBlockingFriend() {
            // Given
            when(userProfileRepository.existsById(blockedId)).thenReturn(true);
            when(blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(false);
            when(friendshipRepository.areFriends(blockerId, blockedId)).thenReturn(true);
            when(blockListRepository.save(any(BlockList.class))).thenAnswer(inv -> inv.getArgument(0));

            // When
            blockService.blockUser(blockerId, blockedId, true, true, false);

            // Then
            verify(blockListRepository).save(any(BlockList.class));
            verify(friendshipRepository).deleteFriendship(blockerId, blockedId);
        }

        @Test
        @DisplayName("Should throw exception when blocking self")
        void shouldThrowException_WhenBlockingSelf() {
            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> blockService.blockUser(blockerId, blockerId, null, null, null));

            assertEquals(ErrorCode.SOCIAL_CANNOT_ADD_SELF, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when user not found")
        void shouldThrowException_WhenUserNotFound() {
            // Given
            when(userProfileRepository.existsById(blockedId)).thenReturn(false);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> blockService.blockUser(blockerId, blockedId, null, null, null));

            assertEquals(ErrorCode.USER_NOT_FOUND, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when already blocked")
        void shouldThrowException_WhenAlreadyBlocked() {
            // Given
            when(userProfileRepository.existsById(blockedId)).thenReturn(true);
            when(blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> blockService.blockUser(blockerId, blockedId, null, null, null));

            assertEquals(ErrorCode.SOCIAL_ALREADY_BLOCKED, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Unblock User Tests")
    class UnblockUserTests {

        @Test
        @DisplayName("Should unblock user successfully")
        void shouldUnblockUserSuccessfully() {
            // Given
            BlockList block = BlockList.builder()
                    .blockerId(blockerId)
                    .blockedId(blockedId)
                    .build();
            
            when(blockListRepository.findByBlockerIdAndBlockedId(blockerId, blockedId))
                    .thenReturn(Optional.of(block));

            // When
            blockService.unblockUser(blockerId, blockedId);

            // Then
            verify(blockListRepository).delete(block);
        }

        @Test
        @DisplayName("Should throw exception when block not found")
        void shouldThrowException_WhenBlockNotFound() {
            // Given
            when(blockListRepository.findByBlockerIdAndBlockedId(blockerId, blockedId))
                    .thenReturn(Optional.empty());

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> blockService.unblockUser(blockerId, blockedId));

            assertEquals(ErrorCode.SOCIAL_NOT_BLOCKED, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Get Blocked Users Tests")
    class GetBlockedUsersTests {

        @Test
        @DisplayName("Should get blocked users list")
        void shouldGetBlockedUsersList() {
            // Given
            Pageable pageable = PageRequest.of(0, 20);
            BlockList block = BlockList.builder()
                    .blockerId(blockerId)
                    .blockedId(blockedId)
                    .blockMessages(true)
                    .blockCalls(true)
                    .blockAndHideLogs(false)
                    .createdAt(Instant.now())
                    .build();
            block.setBlockId(UUID.randomUUID());

            UserProfile blockedProfile = UserProfile.builder()
                    .displayName("Blocked User")
                    .avatarUrl("https://example.com/avatar.jpg")
                    .build();
            blockedProfile.setId(blockedId);

            Page<BlockList> blockPage = new PageImpl<>(List.of(block));

            when(blockListRepository.findByBlockerIdOrderByCreatedAtDesc(blockerId, pageable))
                    .thenReturn(blockPage);
            when(userProfileRepository.findById(blockedId)).thenReturn(Optional.of(blockedProfile));

            // When
            Page<BlockedUserResponse> result = blockService.getBlockedUsers(blockerId, pageable);

            // Then
            assertNotNull(result);
            assertEquals(1, result.getTotalElements());
            assertEquals("Blocked User", result.getContent().get(0).displayName());
            assertTrue(result.getContent().get(0).blockMessages());
        }
    }

    @Nested
    @DisplayName("Is Blocked Tests")
    class IsBlockedTests {

        @Test
        @DisplayName("Should return true when user is blocked")
        void shouldReturnTrue_WhenUserIsBlocked() {
            // Given
            when(blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(true);

            // When
            boolean result = blockService.isBlocked(blockerId, blockedId);

            // Then
            assertTrue(result);
        }

        @Test
        @DisplayName("Should return false when user is not blocked")
        void shouldReturnFalse_WhenUserIsNotBlocked() {
            // Given
            when(blockListRepository.existsByBlockerIdAndBlockedId(blockerId, blockedId)).thenReturn(false);

            // When
            boolean result = blockService.isBlocked(blockerId, blockedId);

            // Then
            assertFalse(result);
        }

        @Test
        @DisplayName("Should check block between two users")
        void shouldCheckBlockBetweenTwoUsers() {
            // Given
            when(blockListRepository.existsBlockBetween(blockerId, blockedId)).thenReturn(true);

            // When
            boolean result = blockService.hasBlockBetween(blockerId, blockedId);

            // Then
            assertTrue(result);
        }
    }
}
