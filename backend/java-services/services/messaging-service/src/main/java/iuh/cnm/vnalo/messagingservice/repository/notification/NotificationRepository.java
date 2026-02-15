package iuh.cnm.vnalo.messagingservice.repository.notification;

import iuh.cnm.vnalo.messagingservice.model.entity.notification.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, UUID> {
    List<Notification> findByUserIdAndIsReadFalseOrderByCreatedAtDesc(UUID userId);
    List<Notification> findByUserIdOrderByCreatedAtDesc(UUID userId);
    long countByUserIdAndIsReadFalse(UUID userId);
}
