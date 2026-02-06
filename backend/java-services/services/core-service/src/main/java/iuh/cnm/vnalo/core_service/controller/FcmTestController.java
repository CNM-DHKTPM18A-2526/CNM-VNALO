package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.service.FcmService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Test controller for FCM push notifications.
 * Only available in dev profile.
 */
@RestController
@RequestMapping("/test/fcm")
@RequiredArgsConstructor
@Profile("dev")
@Tag(name = "FCM Test", description = "Test Firebase Cloud Messaging (dev only)")
public class FcmTestController {

    private final FcmService fcmService;

    @PostMapping("/send")
    @Operation(summary = "Test FCM push notification",
               description = "Send a test push notification to a device. Requires FCM token from mobile app.")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testSend(
            @RequestBody FcmTestRequest request) {
        
        Map<String, Object> result = new HashMap<>();
        result.put("fcmToken", maskToken(request.getFcmToken()));
        result.put("title", request.getTitle());
        result.put("body", request.getBody());
        
        try {
            boolean success = fcmService.sendNotification(
                request.getFcmToken(),
                request.getTitle(),
                request.getBody(),
                request.getData()
            );
            
            result.put("success", success);
            result.put("message", success ? "Notification sent successfully" : "Failed to send notification");
            
            return ResponseEntity.ok(ApiResponse.success("FCM test completed", result));
            
        } catch (Exception e) {
            result.put("success", false);
            result.put("error", e.getMessage());
            return ResponseEntity.ok(ApiResponse.success("FCM test failed", result));
        }
    }

    @PostMapping("/send-otp")
    @Operation(summary = "Test OTP push notification",
               description = "Send a test OTP notification to a device.")
    public ResponseEntity<ApiResponse<Map<String, Object>>> testOtpNotification(
            @RequestBody OtpTestRequest request) {
        
        Map<String, Object> result = new HashMap<>();
        result.put("fcmToken", maskToken(request.getFcmToken()));
        result.put("otp", request.getOtpCode());
        
        try {
            boolean success = fcmService.sendOtpNotification(
                request.getFcmToken(),
                request.getOtpCode()
            );
            
            result.put("success", success);
            result.put("message", success ? "OTP notification sent" : "Failed to send OTP");
            
            return ResponseEntity.ok(ApiResponse.success("OTP notification test completed", result));
            
        } catch (Exception e) {
            result.put("success", false);
            result.put("error", e.getMessage());
            return ResponseEntity.ok(ApiResponse.success("OTP notification test failed", result));
        }
    }

    private String maskToken(String token) {
        if (token == null || token.length() < 20) return "****";
        return token.substring(0, 10) + "..." + token.substring(token.length() - 10);
    }

    @Data
    public static class FcmTestRequest {
        private String fcmToken;
        private String title = "Test Notification";
        private String body = "This is a test message from VNALO";
        private Map<String, String> data;
    }

    @Data
    public static class OtpTestRequest {
        private String fcmToken;
        private String otpCode = "123456";
    }
}
