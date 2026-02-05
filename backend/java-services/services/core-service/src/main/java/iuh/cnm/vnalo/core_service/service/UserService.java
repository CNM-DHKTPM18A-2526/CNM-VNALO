package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.UpdateProfileRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UserProfileRepository userProfileRepository;
    private final UserPrivacySettingRepository userPrivacySettingRepository;
    private final AuthAccountRepository authAccountRepository;

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
    public Page<UserInfoResponse> searchUsers(String keyword, Pageable pageable) {
        return userProfileRepository.searchByDisplayName(keyword, pageable)
                .map(profile -> {
                    AuthAccount account = authAccountRepository.findById(profile.getId()).orElse(null);
                    return mapToUserInfoResponse(account, profile);
                });
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

    private UserInfoResponse mapToUserInfoResponse(AuthAccount account, UserProfile profile) {
        return UserInfoResponse.builder()
                .id(profile.getId())
                .phone(account != null ? account.getPhone() : null)
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
}
