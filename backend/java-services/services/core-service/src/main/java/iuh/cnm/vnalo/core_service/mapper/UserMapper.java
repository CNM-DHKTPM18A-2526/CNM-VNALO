package iuh.cnm.vnalo.core_service.mapper;

import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import org.springframework.stereotype.Component;

/**
 * Mapper for converting between User entities and DTOs.
 */
@Component
public class UserMapper {

    /**
     * Map AuthAccount and UserProfile to UserInfoResponse.
     *
     * @param account the auth account (can be null)
     * @param profile the user profile
     * @return UserInfoResponse DTO
     */
    public UserInfoResponse toUserInfoResponse(AuthAccount account, UserProfile profile) {
        if (profile == null) {
            return null;
        }
        
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
