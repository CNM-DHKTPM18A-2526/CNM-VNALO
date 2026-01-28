package iuh.cnm.vnalo.core_service.model.entity.user;

import iuh.cnm.vnalo.core_service.model.enums.AllowCallingType;
import iuh.cnm.vnalo.core_service.model.enums.DisplayBirthdayType;
import iuh.cnm.vnalo.core_service.model.enums.SeenCommentType;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_privacy_setting")
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPrivacySetting {

    @Id
    @Column(name = "user_id", updatable = false, nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "display_birthday", length = 20)
    @Builder.Default
    private DisplayBirthdayType displayBirthday = DisplayBirthdayType.DAY_MONTH;

    @Column(name = "birthday_notification_enabled")
    @Builder.Default
    private Boolean birthdayNotificationEnabled = true;

    @Column(name = "show_online_status")
    @Builder.Default
    private Boolean showOnlineStatus = true;

    @Column(name = "allow_messaging")
    @Builder.Default
    private Boolean allowMessaging = true;

    @Enumerated(EnumType.STRING)
    @Column(name = "allow_calling", length = 20)
    @Builder.Default
    private AllowCallingType allowCalling = AllowCallingType.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(name = "allow_seen_and_comment", length = 20)
    @Builder.Default
    private SeenCommentType allowSeenAndComment = SeenCommentType.EVERYONE;

    @Column(name = "allow_friend_request_by_phone")
    @Builder.Default
    private Boolean allowFriendRequestByPhone = true;

    @Column(name = "allow_friend_request_by_qr_code")
    @Builder.Default
    private Boolean allowFriendRequestByQrCode = true;

    @Column(name = "allow_friend_request_by_shared_group")
    @Builder.Default
    private Boolean allowFriendRequestBySharedGroup = true;

    @Column(name = "allow_friend_request_by_bio")
    @Builder.Default
    private Boolean allowFriendRequestByBio = true;

    @Column(name = "allow_friend_request_by_suggestion")
    @Builder.Default
    private Boolean allowFriendRequestBySuggestion = true;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    public static UserPrivacySetting createDefault(UUID userId) {
        return UserPrivacySetting.builder()
                .userId(userId)
                .build();
    }
}
