package iuh.cnm.vnalo.notification_service.controller;

import iuh.cnm.vnalo.notification_service.model.dto.CreateNotificationRequest;
import iuh.cnm.vnalo.notification_service.model.dto.RegisterDeviceRequest;
import iuh.cnm.vnalo.notification_service.model.entity.Notification;
import iuh.cnm.vnalo.notification_service.model.entity.NotificationDevice;
import iuh.cnm.vnalo.notification_service.service.NotificationDeviceService;
import iuh.cnm.vnalo.notification_service.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequiredArgsConstructor
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationService notificationService;
    private final NotificationDeviceService deviceService;
    
    private UUID currentUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @PostMapping("/devices")
    public NotificationDevice registerDevice(
            Authentication authentication,
            @RequestBody RegisterDeviceRequest req
    ) {
        return deviceService.register(currentUserId(authentication), req);
    }

    @GetMapping
    public List<Notification> list(
            Authentication authentication,
            @RequestParam(defaultValue = "20") int limit
    ) {
        return notificationService.list(currentUserId(authentication), limit);
    }

    @GetMapping("/unread-count")
    public Map<String, Long> unreadCount(
            Authentication authentication
    ) {
        return Map.of("unreadCount", notificationService.unreadCount(currentUserId(authentication)));
    }

    @PatchMapping("/{id}/read")
    public Notification markRead(
            Authentication authentication,
            @PathVariable UUID id
    ) {
        return notificationService.markRead(currentUserId(authentication), id);
    }

    // MVP test (nên dùng service để không lệch logic)
    @PostMapping("/test")
    public Notification createTest(@RequestBody CreateNotificationRequest req) {
        return notificationService.send(req);
    }
}

