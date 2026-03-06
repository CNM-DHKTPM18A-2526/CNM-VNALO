package iuh.cnm.vnalo.notification_service.service;

import iuh.cnm.vnalo.notification_service.model.dto.CreateNotificationRequest;
import iuh.cnm.vnalo.notification_service.model.entity.Notification;
import iuh.cnm.vnalo.notification_service.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepo;
    private final PushService pushService;

    public List<Notification> list(UUID userId, int limit) {
        int size = Math.min(Math.max(limit, 1), 100);
        return notificationRepo
                .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(0, size))
                .getContent();
    }

    public long unreadCount(UUID userId) {
        return notificationRepo.countByUserIdAndIsReadFalse(userId);
    }

    @Transactional
    public Notification markRead(UUID userId, UUID notificationId) {
        Notification n = notificationRepo
                .findByNotificationIdAndUserId(notificationId, userId)
                .orElseThrow(() -> new IllegalArgumentException("Notification not found"));

        if (!Boolean.TRUE.equals(n.getIsRead())) {
            n.setIsRead(true);
            n.setReadAt(OffsetDateTime.now());
        }
        return n;
    }

    /**
     * Lưu notification vào DB (KHÔNG gửi push) – dùng nội bộ.
     */
    @Transactional
    public Notification createInternal(CreateNotificationRequest req) {
        Notification n = Notification.builder()
                .userId(req.getUserId())
                .type(req.getType())
                .title(req.getTitle())
                .body(req.getBody())
                .data(req.getData())
                .isRead(false)
                .build();

        return notificationRepo.save(n);
    }

    /**
     * Public use-case: Save DB -> Send FCM
     */
    @Transactional
    public Notification send(CreateNotificationRequest req) {
        Notification saved = createInternal(req);
        pushService.sendToUser(req.getUserId(), req.getTitle(), req.getBody(), req.getData());
        return saved;
    }
}