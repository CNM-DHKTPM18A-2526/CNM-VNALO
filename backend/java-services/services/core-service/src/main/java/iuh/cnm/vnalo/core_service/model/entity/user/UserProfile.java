package iuh.cnm.vnalo.core_service.model.entity.user;

import iuh.cnm.vnalo.core_service.model.enums.Gender;
import iuh.cnm.vnalo.core_service.model.enums.StatusMessageType;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * User profile entity. Uses the same ID as AuthAccount (1:1 relationship)
 * so does not use auto-generated UUID like other entities.
 */
@Entity
@Table(name = "user_profile", indexes = {
    @Index(name = "idx_user_profile_display_name", columnList = "display_name")
})
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfile {

    /**
     * ID is assigned from AuthAccount, not auto-generated
     */
    @Id
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

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

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    public String getAvatarUrlOrDefault() {
        return avatarUrl != null ? avatarUrl : "/assets/default-avatar.png";
    }

    public boolean isProfileComplete() {
        return displayName != null && !displayName.isBlank() && avatarUrl != null;
    }

    /**
     * Factory method to create UserProfile with account ID
     */
    public static UserProfile createWithAccountId(UUID accountId, String displayName) {
        UserProfile profile = new UserProfile();
        profile.setId(accountId);
        profile.setDisplayName(displayName);
        profile.setGender(Gender.UNKNOWN);
        profile.setIsVerified(false);
        profile.setIsOfficialAccount(false);
        profile.setFollowerCount(0);
        return profile;
    }
}
