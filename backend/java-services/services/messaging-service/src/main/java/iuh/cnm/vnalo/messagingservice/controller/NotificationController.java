package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.notification.RegisterDeviceTokenRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.notification.NotificationResponse;
import iuh.cnm.vnalo.messagingservice.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/notifications")
@RequiredArgsConstructor
@Tag(name = "Notifications", description = "Notification management APIs")
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    @Operation(summary = "Get all notifications for the current user")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getNotifications(
            @AuthenticationPrincipal UUID currentUserId) {
        return ResponseEntity.ok(ApiResponse.success(notificationService.getNotifications(currentUserId)));
    }

    @GetMapping("/unread")
    @Operation(summary = "Get unread notifications")
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getUnreadNotifications(
            @AuthenticationPrincipal UUID currentUserId) {
        return ResponseEntity.ok(ApiResponse.success(notificationService.getUnreadNotifications(currentUserId)));
    }

    @GetMapping("/unread/count")
    @Operation(summary = "Get unread notification count")
    public ResponseEntity<ApiResponse<Long>> getUnreadCount(
            @AuthenticationPrincipal UUID currentUserId) {
        return ResponseEntity.ok(ApiResponse.success(notificationService.getUnreadCount(currentUserId)));
    }

    @PatchMapping("/{notificationId}/read")
    @Operation(summary = "Mark a notification as read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID notificationId) {
        notificationService.markAsRead(notificationId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Notification marked as read"));
    }

    @PatchMapping("/read-all")
    @Operation(summary = "Mark all notifications as read")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(
            @AuthenticationPrincipal UUID currentUserId) {
        notificationService.markAllAsRead(currentUserId);
        return ResponseEntity.ok(ApiResponse.success("All notifications marked as read"));
    }

    @PostMapping("/device-token")
    @Operation(summary = "Register or update a device token for push notifications")
    public ResponseEntity<ApiResponse<Void>> registerDeviceToken(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody RegisterDeviceTokenRequest request) {
        notificationService.registerDeviceToken(currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Device token registered"));
    }

    @DeleteMapping("/device-token/{deviceId}")
    @Operation(summary = "Revoke a device token")
    public ResponseEntity<ApiResponse<Void>> revokeDeviceToken(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable String deviceId) {
        notificationService.revokeDeviceToken(currentUserId, deviceId);
        return ResponseEntity.ok(ApiResponse.success("Device token revoked"));
    }
}
