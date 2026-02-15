package iuh.cnm.vnalo.messagingservice.service;

import iuh.cnm.vnalo.messagingservice.exceptions.ApiException;
import iuh.cnm.vnalo.messagingservice.exceptions.ErrorCode;
import iuh.cnm.vnalo.messagingservice.model.dto.request.notification.RegisterDeviceTokenRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.notification.NotificationResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.notification.Notification;
import iuh.cnm.vnalo.messagingservice.model.entity.notification.NotificationDeviceToken;
import iuh.cnm.vnalo.messagingservice.model.enums.notification.DevicePlatform;
import iuh.cnm.vnalo.messagingservice.model.enums.notification.DeviceTokenStatus;
import iuh.cnm.vnalo.messagingservice.repository.notification.NotificationDeviceTokenRepository;
import iuh.cnm.vnalo.messagingservice.repository.notification.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final NotificationDeviceTokenRepository deviceTokenRepository;

    @Transactional(readOnly = true)
    public List<NotificationResponse> getNotifications(UUID userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> getUnreadNotifications(UUID userId) {
        return notificationRepository.findByUserIdAndIsReadFalseOrderByCreatedAtDesc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public long getUnreadCount(UUID userId) {
        return notificationRepository.countByUserIdAndIsReadFalse(userId);
    }

    public void markAsRead(UUID notificationId, UUID userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOTIF_NOT_FOUND));

        if (!notification.getUserId().equals(userId)) {
            throw new ApiException(ErrorCode.ACCESS_DENIED);
        }

        notification.setIsRead(true);
        notification.setReadAt(Instant.now());
        notificationRepository.save(notification);
    }

    public void markAllAsRead(UUID userId) {
        List<Notification> unread = notificationRepository.findByUserIdAndIsReadFalseOrderByCreatedAtDesc(userId);
        Instant now = Instant.now();
        for (Notification n : unread) {
            n.setIsRead(true);
            n.setReadAt(now);
        }
        notificationRepository.saveAll(unread);
    }

    /**
     * Register or update a device token for push notifications.
     * Uses device_id as the primary key — upsert by device_id.
     */
    public void registerDeviceToken(UUID userId, RegisterDeviceTokenRequest request) {
        NotificationDeviceToken token = deviceTokenRepository.findById(request.getDeviceId())
                .orElse(null);

        if (token != null) {
            // Update existing device token
            token.setUserId(userId);
            token.setPushToken(request.getPushToken());
            token.setPlatform(DevicePlatform.valueOf(request.getPlatform().toUpperCase()));
            token.setStatus(DeviceTokenStatus.ACTIVE);
            token.setLastActiveAt(Instant.now());
            if (request.getVoipToken() != null) token.setVoipToken(request.getVoipToken());
            if (request.getAppVersion() != null) token.setAppVersion(request.getAppVersion());
            if (request.getOsVersion() != null) token.setOsVersion(request.getOsVersion());
            if (request.getDeviceModel() != null) token.setDeviceModel(request.getDeviceModel());
            if (request.getDeviceName() != null) token.setDeviceName(request.getDeviceName());
        } else {
            // Create new device token
            token = NotificationDeviceToken.builder()
                    .deviceId(request.getDeviceId())
                    .userId(userId)
                    .pushToken(request.getPushToken())
                    .platform(DevicePlatform.valueOf(request.getPlatform().toUpperCase()))
                    .voipToken(request.getVoipToken())
                    .appVersion(request.getAppVersion())
                    .osVersion(request.getOsVersion())
                    .deviceModel(request.getDeviceModel())
                    .deviceName(request.getDeviceName())
                    .lastActiveAt(Instant.now())
                    .build();
        }

        deviceTokenRepository.save(token);
    }

    /**
     * Revoke a device token (soft-delete by setting status to REVOKED).
     */
    public void revokeDeviceToken(UUID userId, String deviceId) {
        deviceTokenRepository.findById(deviceId)
                .ifPresent(token -> {
                    if (token.getUserId().equals(userId)) {
                        token.setStatus(DeviceTokenStatus.REVOKED);
                        deviceTokenRepository.save(token);
                    }
                });
    }

    /**
     * Get all active device tokens for a user (for push notification delivery).
     */
    @Transactional(readOnly = true)
    public List<NotificationDeviceToken> getActiveDeviceTokens(UUID userId) {
        return deviceTokenRepository.findByUserIdAndStatus(userId, DeviceTokenStatus.ACTIVE);
    }

    private NotificationResponse toResponse(Notification n) {
        return NotificationResponse.builder()
                .notificationId(n.getNotificationId())
                .type(n.getType().name())
                .title(n.getTitle())
                .body(n.getBody())
                .imageUrl(n.getImageUrl())
                .actionType(n.getActionType() != null ? n.getActionType().name() : null)
                .actionData(n.getActionData())
                .isRead(n.getIsRead())
                .readAt(n.getReadAt())
                .createdAt(n.getCreatedAt())
                .build();
    }
}
