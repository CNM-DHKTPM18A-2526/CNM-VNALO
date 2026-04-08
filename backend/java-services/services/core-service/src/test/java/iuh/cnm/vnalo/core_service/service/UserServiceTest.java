package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.UpdateProfileRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.model.enums.Gender;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.social.ContactSyncRepository;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("UserService Unit Tests")
class UserServiceTest {

    @Mock
    private UserProfileRepository userProfileRepository;

    @Mock
    private UserPrivacySettingRepository userPrivacySettingRepository;

    @Mock
    private AuthAccountRepository authAccountRepository;

    @Mock
    private FriendshipRepository friendshipRepository;

    @Mock
    private ContactSyncRepository contactSyncRepository;

    @InjectMocks
    private UserService userService;

    private UUID testUserId;
    private AuthAccount testAccount;
    private UserProfile testProfile;

    @BeforeEach
    void setUp() {
        testUserId = UUID.randomUUID();

        testAccount = AuthAccount.builder()
                .phone("+84912345678")
                .passwordHash("hashedPassword")
                .status(AccountStatus.ACTIVE)
                .build();
        testAccount.setId(testUserId);

        testProfile = UserProfile.builder()
                .displayName("Test User")
                .avatarUrl("https://example.com/avatar.jpg")
                .bio("Test bio")
                .gender(Gender.MALE)
                .build();
        testProfile.setId(testUserId);
    }

    @Nested
    @DisplayName("Get Profile Tests")
    class GetProfileTests {

        @Test
        @DisplayName("Should get current user profile successfully")
        void shouldGetCurrentUserProfile() {
            // Given
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.of(testAccount));
            when(userProfileRepository.findById(testUserId)).thenReturn(Optional.of(testProfile));

            // When
            UserInfoResponse response = userService.getCurrentUserProfile(testUserId);

            // Then
            assertNotNull(response);
            assertEquals(testUserId, response.getId());
            assertEquals("+84912345678", response.getPhone());
            assertEquals("Test User", response.getDisplayName());
        }

        @Test
        @DisplayName("Should throw exception when account not found")
        void shouldThrowException_WhenAccountNotFound() {
            // Given
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.empty());

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> userService.getCurrentUserProfile(testUserId));

            assertEquals(ErrorCode.USER_NOT_FOUND, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should throw exception when profile not found")
        void shouldThrowException_WhenProfileNotFound() {
            // Given
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.of(testAccount));
            when(userProfileRepository.findById(testUserId)).thenReturn(Optional.empty());

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> userService.getCurrentUserProfile(testUserId));

            assertEquals(ErrorCode.USER_PROFILE_NOT_FOUND, exception.getErrorCode());
        }

        @Test
        @DisplayName("Should get user profile by ID")
        void shouldGetUserProfileById() {
            // Given
            when(userProfileRepository.findById(testUserId)).thenReturn(Optional.of(testProfile));
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.of(testAccount));

            // When
            UserInfoResponse response = userService.getUserProfile(testUserId);

            // Then
            assertNotNull(response);
            assertEquals("Test User", response.getDisplayName());
        }
    }

    @Nested
    @DisplayName("Update Profile Tests")
    class UpdateProfileTests {

        @Test
        @DisplayName("Should update profile successfully")
        void shouldUpdateProfileSuccessfully() {
            // Given
            UpdateProfileRequest request = new UpdateProfileRequest(
                    "New Name", null, null, "New Bio", Gender.FEMALE, LocalDate.of(1990, 1, 1), null);

            when(userProfileRepository.findById(testUserId)).thenReturn(Optional.of(testProfile));
            when(userProfileRepository.save(any(UserProfile.class))).thenAnswer(inv -> inv.getArgument(0));
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.of(testAccount));

            // When
            UserInfoResponse response = userService.updateProfile(testUserId, request);

            // Then
            assertNotNull(response);
            assertEquals("New Name", response.getDisplayName());
            assertEquals("New Bio", response.getBio());
            assertEquals(Gender.FEMALE, response.getGender());
            verify(userProfileRepository).save(any(UserProfile.class));
        }

        @Test
        @DisplayName("Should throw exception when profile not found")
        void shouldThrowException_WhenProfileNotFoundOnUpdate() {
            // Given
            UpdateProfileRequest request = new UpdateProfileRequest("New Name", null, null, null, null, null, null);
            when(userProfileRepository.findById(testUserId)).thenReturn(Optional.empty());

            // When & Then
            ApiException exception = assertThrows(ApiException.class,
                    () -> userService.updateProfile(testUserId, request));

            assertEquals(ErrorCode.USER_PROFILE_NOT_FOUND, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Search Users Tests")
    class SearchUsersTests {

        @Test
        @DisplayName("Should search users by keyword")
        void shouldSearchUsersByKeyword() {
            // Given
            UUID requesterId = UUID.randomUUID();
            Pageable pageable = PageRequest.of(0, 20);
            Page<UserProfile> profilePage = new PageImpl<>(List.of(testProfile));
            
            when(friendshipRepository.findFriendIds(requesterId)).thenReturn(List.of(testUserId));
            when(contactSyncRepository.findByUserIdAndMatchedUserIdIsNotNull(requesterId)).thenReturn(List.of());
            when(userProfileRepository.searchByDisplayNameWithinIds(any(), eq("test"), eq(pageable))).thenReturn(profilePage);
            when(authAccountRepository.findById(testUserId)).thenReturn(Optional.of(testAccount));

            // When
            Page<UserInfoResponse> result = userService.searchUsers(requesterId, "Test", pageable);

            // Then
            assertNotNull(result);
            assertEquals(1, result.getTotalElements());
            assertEquals("Test User", result.getContent().get(0).getDisplayName());
        }
    }

    @Nested
    @DisplayName("Privacy Settings Tests")
    class PrivacySettingsTests {

        @Test
        @DisplayName("Should get existing privacy settings")
        void shouldGetExistingPrivacySettings() {
            // Given
            UserPrivacySetting settings = UserPrivacySetting.createDefault(testUserId);
            when(userPrivacySettingRepository.findById(testUserId)).thenReturn(Optional.of(settings));

            // When
            UserPrivacySetting result = userService.getPrivacySettings(testUserId);

            // Then
            assertNotNull(result);
            assertEquals(testUserId, result.getUserId());
        }

        @Test
        @DisplayName("Should return default privacy settings when not found")
        void shouldReturnDefaultPrivacySettings_WhenNotFound() {
            // Given
            when(userPrivacySettingRepository.findById(testUserId)).thenReturn(Optional.empty());

            // When
            UserPrivacySetting result = userService.getPrivacySettings(testUserId);

            // Then
            assertNotNull(result);
            assertEquals(testUserId, result.getUserId());
            assertTrue(result.getShowOnlineStatus());
            assertTrue(result.getAllowMessaging());
        }

        @Test
        @DisplayName("Should update privacy settings")
        void shouldUpdatePrivacySettings() {
            // Given
            UserPrivacySetting settings = UserPrivacySetting.createDefault(testUserId);
            settings.setShowOnlineStatus(false);
            
            when(userPrivacySettingRepository.save(any(UserPrivacySetting.class)))
                    .thenAnswer(inv -> inv.getArgument(0));

            // When
            UserPrivacySetting result = userService.updatePrivacySettings(testUserId, settings);

            // Then
            assertNotNull(result);
            assertFalse(result.getShowOnlineStatus());
            verify(userPrivacySettingRepository).save(any(UserPrivacySetting.class));
        }
    }
}
