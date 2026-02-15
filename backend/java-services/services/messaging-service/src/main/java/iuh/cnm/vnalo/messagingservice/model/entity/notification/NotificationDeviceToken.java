package iuh.cnm.vnalo.messagingservice.model.entity.notification;

import iuh.cnm.vnalo.messagingservice.model.enums.notification.DevicePlatform;
import iuh.cnm.vnalo.messagingservice.model.enums.notification.DeviceTokenStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "device_token")
@EntityListeners(AuditingEntityListener.class)
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationDeviceToken {

    @Id
    @Column(name = "device_id", length = 100)
    private String deviceId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "platform", nullable = false, length = 20)
    private DevicePlatform platform;

    @Column(name = "push_token", nullable = false, length = 500, unique = true)
    private String pushToken;

    @Column(name = "voip_token", length = 500)
    private String voipToken;

    @Column(name = "app_version", length = 20)
    private String appVersion;

    @Column(name = "os_version", length = 20)
    private String osVersion;

    @Column(name = "device_model", length = 100)
    private String deviceModel;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20)
    @Builder.Default
    private DeviceTokenStatus status = DeviceTokenStatus.ACTIVE;

    @Column(name = "last_active_at")
    private Instant lastActiveAt;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private Instant updatedAt;
}
