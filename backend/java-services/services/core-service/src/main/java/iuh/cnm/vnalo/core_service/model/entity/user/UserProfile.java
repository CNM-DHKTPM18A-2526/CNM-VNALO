package iuh.cnm.vnalo.core_service.model.entity.user;

import iuh.cnm.vnalo.core_service.model.entity.base.BaseEntity;
import iuh.cnm.vnalo.core_service.model.enums.Gender;
import iuh.cnm.vnalo.core_service.model.enums.StatusMessageType;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "user_profile", indexes = {
    @Index(name = "idx_user_profile_display_name", columnList = "display_name")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfile extends BaseEntity {

    @Column(name = "display_name", nullable = false, length = 100)
    private String displayName;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender", length = 20)
    @Builder.Default
    private Gender gender = Gender.UNKNOWN;

    @Column(name = "dob")
    private LocalDate dob;

    @Column(name = "cover_url", length = 500)
    private String coverUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "status_message_type", length = 20)
    private StatusMessageType statusMessageType;

    @Column(name = "status_message", length = 200)
    private String statusMessage;

    @Column(name = "bio", length = 500)
    private String bio;

    @Column(name = "qr_code_url", length = 500)
    private String qrCodeUrl;

    @Column(name = "region", length = 100)
    private String region;

    @Column(name = "is_verified")
    @Builder.Default
    private Boolean isVerified = false;

    @Column(name = "is_official_account")
    @Builder.Default
    private Boolean isOfficialAccount = false;

    @Column(name = "follower_count")
    @Builder.Default
    private Integer followerCount = 0;

    public String getAvatarUrlOrDefault() {
        return avatarUrl != null ? avatarUrl : "/assets/default-avatar.png";
    }

    public boolean isProfileComplete() {
        return displayName != null && !displayName.isBlank() && avatarUrl != null;
    }
}
