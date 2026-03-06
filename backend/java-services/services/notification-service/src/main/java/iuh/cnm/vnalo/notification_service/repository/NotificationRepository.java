package iuh.cnm.vnalo.notification_service.repository;

import iuh.cnm.vnalo.notification_service.model.entity.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {
    Page<Notification> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    long countByUserIdAndIsReadFalse(UUID userId);

    Optional<Notification> findByNotificationIdAndUserId(UUID notificationId, UUID userId);
}
