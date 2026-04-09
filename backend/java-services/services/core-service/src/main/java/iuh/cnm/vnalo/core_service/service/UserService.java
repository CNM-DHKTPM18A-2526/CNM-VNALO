package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.UpdateProfileRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.UpdateSyncPolicyRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.SyncPolicyResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.social.ContactSync;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.entity.user.UserSetting;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.social.ContactSyncRepository;
import iuh.cnm.vnalo.core_service.repository.social.FriendshipRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserSettingRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UserProfileRepository userProfileRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;
    private final AuthAccountRepository authAccountRepository;
    private final FriendshipRepository friendshipRepository;
    private final ContactSyncRepository contactSyncRepository;
    private final UserSettingRepository userSettingRepository;

    @Transactional(readOnly = true)
    public UserInfoResponse getCurrentUserProfile(UUID accountId) {
        AuthAccount account = authAccountRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
        UserProfile profile = userProfileRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));
        return mapToUserInfoResponse(account, profile);
    }

    @Transactional(readOnly = true)
    public UserInfoResponse getUserProfile(UUID userId) {
        UserProfile profile = userProfileRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));
        AuthAccount account = authAccountRepository.findById(userId).orElse(null);
        return mapToUserInfoResponse(account, profile);
    }

    @Transactional
    public UserInfoResponse updateProfile(UUID accountId, UpdateProfileRequest request) {
        UserProfile profile = userProfileRepository.findById(accountId)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));

        if (request.displayName() != null) profile.setDisplayName(request.displayName());
        if (request.avatarUrl() != null) profile.setAvatarUrl(request.avatarUrl());
        if (request.coverUrl() != null) profile.setCoverUrl(request.coverUrl());
        if (request.bio() != null) profile.setBio(request.bio());
        if (request.gender() != null) profile.setGender(request.gender());
        if (request.dob() != null) profile.setDob(request.dob());
        if (request.statusMessage() != null) profile.setStatusMessage(request.statusMessage());

        profile = userProfileRepository.save(profile);
        AuthAccount account = authAccountRepository.findById(accountId).orElse(null);
        return mapToUserInfoResponse(account, profile);
    }

    @Transactional(readOnly = true)
    public Page<UserInfoResponse> searchUsers(UUID requesterId, String keyword, Pageable pageable) {
        final String normalizedKeyword = normalizeKeyword(keyword);
        if (normalizedKeyword.isBlank()) {
            return Page.empty(pageable);
        }

        final Set<UUID> allowedIds = new HashSet<>(friendshipRepository.findFriendIds(requesterId));
        final List<ContactSync> matchedContacts = contactSyncRepository
            .findByUserIdAndMatchedUserIdIsNotNull(requesterId);
        matchedContacts.stream()
                .map(ContactSync::getMatchedUserId)
                .filter(id -> id != null && !id.equals(requesterId))
                .forEach(allowedIds::add);

        if (allowedIds.isEmpty()) {
            return new PageImpl<>(List.of(), pageable, 0);
        }

        Page<UserProfile> profilePage = userProfileRepository
            .searchByDisplayNameWithinIds(allowedIds, normalizedKeyword, pageable);

        if (profilePage.isEmpty()) {
            return new PageImpl<>(List.of(), pageable, profilePage.getTotalElements());
        }

        Set<UUID> profileIds = profilePage.getContent().stream()
            .map(UserProfile::getId)
            .collect(Collectors.toSet());

        Map<UUID, AuthAccount> accountMap = new HashMap<>();
        authAccountRepository.findAllByIdIn(profileIds)
            .forEach(account -> accountMap.put(account.getId(), account));

        List<UserInfoResponse> content = profilePage.getContent().stream()
            .map(profile -> mapToUserInfoResponse(accountMap.get(profile.getId()), profile))
            .toList();

        return new PageImpl<>(content, pageable, profilePage.getTotalElements());
    }

    @Transactional(readOnly = true)
    public UserInfoResponse searchUserByPhone(UUID requesterId, String phoneNumber) {
        final String normalizedPhone = normalizePhone(phoneNumber);
        final AuthAccount account = authAccountRepository.findByPhone(normalizedPhone)
                .orElseThrow(() -> new ApiException(ErrorCode.USER_NOT_FOUND));

        if (account.getId().equals(requesterId)) {
            throw new ApiException(ErrorCode.USER_NOT_FOUND);
        }

        final boolean allowSearchByPhone = userPrivacySettingRepository.findById(account.getId())
                .map(setting -> Boolean.TRUE.equals(setting.getAllowSearchByPhone()))
                .orElse(true);
        if (!allowSearchByPhone) {
            throw new ApiException(ErrorCode.USER_NOT_FOUND);
        }

        final UserProfile profile = userProfileRepository.findById(account.getId())
                .orElseThrow(() -> new ApiException(ErrorCode.USER_PROFILE_NOT_FOUND));
        return mapToUserInfoResponse(account, profile);
    }

    @Transactional(readOnly = true)
    public UserPrivacySetting getPrivacySettings(UUID userId) {
        return userPrivacySettingRepository.findById(userId)
                .orElseGet(() -> UserPrivacySetting.createDefault(userId));
    }

    @Transactional
    public UserPrivacySetting updatePrivacySettings(UUID userId, UserPrivacySetting settings) {
        settings.setUserId(userId);
        return userPrivacySettingRepository.save(settings);
    }

    @Transactional(readOnly = true)
    public SyncPolicyResponse getSyncPolicy(UUID userId) {
        final UserSetting setting = userSettingRepository.findById(userId)
                .orElseGet(() -> UserSetting.createDefault(userId));
        return mapToSyncPolicy(setting);
    }

    @Transactional
    public SyncPolicyResponse updateSyncPolicy(UUID userId, UpdateSyncPolicyRequest request) {
        final UserSetting setting = userSettingRepository.findById(userId)
                .orElseGet(() -> UserSetting.createDefault(userId));

        setting.setSyncEnabled(Boolean.TRUE.equals(request.syncEnabled()));
        setting.setWebRestrictedMode(!Boolean.TRUE.equals(request.syncEnabled()));

        final UserSetting saved = userSettingRepository.save(setting);
        return mapToSyncPolicy(saved);
    }

    private UserInfoResponse mapToUserInfoResponse(AuthAccount account, UserProfile profile) {
        return UserInfoResponse.builder()
                .id(profile.getId())
                .phone(account != null ? account.getPhone() : null)
            .email(account != null ? account.getEmail() : null)
                .displayName(profile.getDisplayName())
                .avatarUrl(profile.getAvatarUrl())
                .coverUrl(profile.getCoverUrl())
                .bio(profile.getBio())
                .gender(profile.getGender())
                .dob(profile.getDob())
                .statusMessage(profile.getStatusMessage())
                .isVerified(profile.getIsVerified())
                .build();
    }

    private String normalizeKeyword(String keyword) {
        return keyword == null ? "" : keyword.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizePhone(String phone) {
        if (phone == null) {
            return "";
        }
        String cleaned = phone.replaceAll("[^+\\d]", "");
        if (cleaned.startsWith("0")) {
            cleaned = "+84" + cleaned.substring(1);
        }
        return cleaned;
    }

    private SyncPolicyResponse mapToSyncPolicy(UserSetting setting) {
        return new SyncPolicyResponse(
                Boolean.TRUE.equals(setting.getSyncEnabled()),
                Boolean.TRUE.equals(setting.getWebRestrictedMode()),
                setting.getUpdatedAt()
        );
    }
}
