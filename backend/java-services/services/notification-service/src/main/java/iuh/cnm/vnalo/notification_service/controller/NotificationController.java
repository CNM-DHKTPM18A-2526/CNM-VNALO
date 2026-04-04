package iuh.cnm.vnalo.notification_service.controller;

import iuh.cnm.vnalo.notification_service.model.dto.CreateNotificationRequest;
import iuh.cnm.vnalo.notification_service.model.dto.RegisterDeviceRequest;
import iuh.cnm.vnalo.notification_service.model.entity.Notification;
import iuh.cnm.vnalo.notification_service.model.entity.NotificationDevice;
import iuh.cnm.vnalo.notification_service.repository.NotificationRepository;
import iuh.cnm.vnalo.notification_service.service.NotificationDeviceService;
import iuh.cnm.vnalo.notification_service.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequiredArgsConstructor
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationDeviceService deviceService;

    @PostMapping("/devices")
    public NotificationDevice registerDevice(
            @RequestHeader("X-User-Id") UUID userId,
            @RequestBody RegisterDeviceRequest req
    ) {
        return deviceService.register(userId, req);
    }

    @GetMapping
    public List<Notification> list(
            @RequestHeader("X-User-Id") UUID userId,
            @RequestParam(defaultValue = "20") int limit
    ) {
        return notificationService.list(userId, limit);
    }

    @GetMapping("/unread-count")
    public Map<String, Long> unreadCount(
            @RequestHeader("X-User-Id") UUID userId
    ) {
        return Map.of("unreadCount", notificationService.unreadCount(userId));
    }

    @PatchMapping("/{id}/read")
    public Notification markRead(
            @RequestHeader("X-User-Id") UUID userId,
            @PathVariable UUID id
    ) {
        return notificationService.markRead(userId, id);
    }

    // MVP test (nên dùng service để không lệch logic)
    @PostMapping("/test")
    public Notification createTest(@RequestBody CreateNotificationRequest req) {
        return notificationService.send(req);
    }
}

