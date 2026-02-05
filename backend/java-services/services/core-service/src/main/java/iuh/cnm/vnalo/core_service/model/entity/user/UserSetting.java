package iuh.cnm.vnalo.core_service.model.entity.user;

import iuh.cnm.vnalo.core_service.model.enums.FontSize;
import iuh.cnm.vnalo.core_service.model.enums.Theme;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

/**
 * User settings entity for storing user preferences.
 * Includes language, theme, font size, and notification settings.
 */
@Entity
@Table(name = "user_setting")
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserSetting {

    @Id
    @Column(name = "user_id", updatable = false, nullable = false)
    private UUID userId;

    @Column(name = "language", length = 10)
    @Builder.Default
    private String language = "vi";

    @Enumerated(EnumType.STRING)
    @Column(name = "theme", length = 20)
    @Builder.Default
    private Theme theme = Theme.LIGHT;

    @Enumerated(EnumType.STRING)
    @Column(name = "font_size", length = 20)
    @Builder.Default
    private FontSize fontSize = FontSize.MEDIUM;

    @Column(name = "notification_sound")
    @Builder.Default
    private Boolean notificationSound = true;

    @Column(name = "notification_vibrate")
    @Builder.Default
    private Boolean notificationVibrate = true;

    @Column(name = "notification_preview")
    @Builder.Default
    private Boolean notificationPreview = true;

    @Column(name = "auto_download_image")
    @Builder.Default
    private Boolean autoDownloadImage = true;

    @Column(name = "auto_download_video")
    @Builder.Default
    private Boolean autoDownloadVideo = false;

    @Column(name = "auto_download_file")
    @Builder.Default
    private Boolean autoDownloadFile = false;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;

    /**
     * Create default user settings for a new user.
     */
    public static UserSetting createDefault(UUID userId) {
        return UserSetting.builder()
                .userId(userId)
                .build();
    }
}
