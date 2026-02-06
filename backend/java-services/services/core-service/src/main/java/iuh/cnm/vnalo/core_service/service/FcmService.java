package iuh.cnm.vnalo.core_service.service;

import com.google.firebase.messaging.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Firebase Cloud Messaging Service for sending push notifications.
 * Used to deliver OTP codes to users via push notification (free alternative to SMS).
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class FcmService {

    /**
     * Send OTP code via push notification to a specific device.
     *
     * @param fcmToken Device FCM token
     * @param otpCode  The OTP code to send
     * @return true if sent successfully
     */
    public boolean sendOtpNotification(String fcmToken, String otpCode) {
        if (fcmToken == null || fcmToken.isBlank()) {
            log.warn("Cannot send OTP notification: FCM token is null or empty");
            return false;
        }

        try {
            Message message = Message.builder()
                .setToken(fcmToken)
                .setNotification(Notification.builder()
                    .setTitle("VNALO - Mã xác thực")
                    .setBody("Mã OTP của bạn là: " + otpCode + ". Có hiệu lực trong 5 phút.")
                    .build())
                .putData("type", "OTP")
                .putData("otp", otpCode)
                .putData("expiresIn", "300")
                .setAndroidConfig(AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                        .setChannelId("otp_channel")
                        .setPriority(AndroidNotification.Priority.HIGH)
                        .build())
                    .build())
                .setApnsConfig(ApnsConfig.builder()
                    .setAps(Aps.builder()
                        .setAlert(ApsAlert.builder()
                            .setTitle("VNALO - Mã xác thực")
                            .setBody("Mã OTP của bạn là: " + otpCode)
                            .build())
                        .setSound("default")
                        .build())
                    .build())
                .build();

            String response = FirebaseMessaging.getInstance().send(message);
            log.info("OTP notification sent successfully. Message ID: {}", response);
            return true;

        } catch (FirebaseMessagingException e) {
            log.error("Failed to send OTP notification: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Send OTP to multiple devices (if user has multiple devices registered).
     *
     * @param fcmTokens List of device tokens
     * @param otpCode   The OTP code
     * @return Number of successful sends
     */
    public int sendOtpToMultipleDevices(java.util.List<String> fcmTokens, String otpCode) {
        if (fcmTokens == null || fcmTokens.isEmpty()) {
            log.warn("No FCM tokens provided for OTP notification");
            return 0;
        }

        int successCount = 0;
        for (String token : fcmTokens) {
            if (sendOtpNotification(token, otpCode)) {
                successCount++;
            }
        }

        log.info("OTP sent to {}/{} devices", successCount, fcmTokens.size());
        return successCount;
    }

    /**
     * Send a general notification to a device.
     *
     * @param fcmToken Device token
     * @param title    Notification title
     * @param body     Notification body
     * @param data     Additional data map
     * @return true if successful
     */
    public boolean sendNotification(String fcmToken, String title, String body, 
                                     java.util.Map<String, String> data) {
        if (fcmToken == null || fcmToken.isBlank()) {
            log.warn("Cannot send notification: FCM token is null");
            return false;
        }

        try {
            Message.Builder builder = Message.builder()
                .setToken(fcmToken)
                .setNotification(Notification.builder()
                    .setTitle(title)
                    .setBody(body)
                    .build());

            if (data != null) {
                builder.putAllData(data);
            }

            String response = FirebaseMessaging.getInstance().send(builder.build());
            log.info("Notification sent successfully. Message ID: {}", response);
            return true;

        } catch (FirebaseMessagingException e) {
            log.error("Failed to send notification: {}", e.getMessage());
            return false;
        }
    }
}
