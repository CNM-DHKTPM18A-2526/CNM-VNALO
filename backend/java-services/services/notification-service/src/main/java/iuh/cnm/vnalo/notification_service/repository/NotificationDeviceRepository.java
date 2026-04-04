package iuh.cnm.vnalo.notification_service.repository;

import iuh.cnm.vnalo.notification_service.model.entity.NotificationDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.UUID;
import java.util.Optional;

public interface NotificationDeviceRepository extends JpaRepository<NotificationDevice, UUID> {
    Optional<NotificationDevice> findByUserIdAndDeviceId(UUID userId, String deviceId);

    List<NotificationDevice> findByUserIdAndIsActiveTrue(UUID userId);

    @Query("""
           select d.fcmToken
           from NotificationDevice d
           where d.userId = :userId
             and d.isActive = true
             and d.fcmToken is not null
             and length(d.fcmToken) > 0
           """)
    List<String> findActiveTokens(UUID userId);

    @Modifying
    @Query("""
           update NotificationDevice d
              set d.isActive = false
            where d.fcmToken = :token
           """)
    int deactivateByToken(String token);
}
