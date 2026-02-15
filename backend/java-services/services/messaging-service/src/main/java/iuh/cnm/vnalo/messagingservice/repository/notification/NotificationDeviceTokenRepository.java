package iuh.cnm.vnalo.messagingservice.repository.notification;

import iuh.cnm.vnalo.messagingservice.model.entity.notification.NotificationDeviceToken;
import iuh.cnm.vnalo.messagingservice.model.enums.notification.DeviceTokenStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface NotificationDeviceTokenRepository extends JpaRepository<NotificationDeviceToken, String> {
    List<NotificationDeviceToken> findByUserIdAndStatus(UUID userId, DeviceTokenStatus status);
    List<NotificationDeviceToken> findByUserId(UUID userId);
}
