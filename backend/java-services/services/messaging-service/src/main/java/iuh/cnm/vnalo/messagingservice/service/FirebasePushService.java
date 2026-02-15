package iuh.cnm.vnalo.messagingservice.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.*;
import iuh.cnm.vnalo.messagingservice.model.entity.notification.NotificationDeviceToken;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/**
 * Service for sending push notifications via Firebase Cloud Messaging (FCM).
 *
 * Sends notifications to user's active device tokens.
 * Handles both individual and batch sending.
 * Gracefully skips if Firebase is not configured.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FirebasePushService {

    private final NotificationService notificationService;

    /**
     * Check if Firebase is initialized and ready.
     */
    private boolean isFirebaseAvailable() {
        return !FirebaseApp.getApps().isEmpty();
    }

    /**
     * Send a push notification to all active devices of a user.
     * Runs asynchronously to avoid blocking the main thread.
     */
    @Async
    public void sendPushToUser(UUID userId, String title, String body, String imageUrl,
                               String actionType, String actionData) {
        if (!isFirebaseAvailable()) {
            log.debug("Firebase not initialized — skipping push to user {}", userId);
            return;
        }

        List<NotificationDeviceToken> tokens = notificationService.getActiveDeviceTokens(userId);
        if (tokens.isEmpty()) {
            log.debug("No active device tokens for user {} — skipping push", userId);
            return;
        }

        for (NotificationDeviceToken token : tokens) {
            try {
                sendToToken(token.getPushToken(), title, body, imageUrl, actionType, actionData);
            } catch (FirebaseMessagingException e) {
                handleSendError(e, token);
            }
        }
    }

    /**
     * Send a push notification to a specific FCM token.
     */
    public void sendToToken(String fcmToken, String title, String body,
                            String imageUrl, String actionType, String actionData)
            throws FirebaseMessagingException {

        if (!isFirebaseAvailable()) {
            log.debug("Firebase not initialized — skipping push");
            return;
        }

        // Build the notification payload
        Notification.Builder notificationBuilder = Notification.builder()
                .setTitle(title)
                .setBody(body);

        if (imageUrl != null && !imageUrl.isBlank()) {
            notificationBuilder.setImage(imageUrl);
        }

        // Build the message
        Message.Builder messageBuilder = Message.builder()
                .setToken(fcmToken)
                .setNotification(notificationBuilder.build());

        // Add custom data payload for client-side handling
        if (actionType != null) {
            messageBuilder.putData("actionType", actionType);
        }
        if (actionData != null) {
            messageBuilder.putData("actionData", actionData);
        }

        // Configure platform-specific settings
        messageBuilder
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setSound("default")
                                .setClickAction("OPEN_ACTIVITY")
                                .build())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder()
                                .setSound("default")
                                .setBadge(1)
                                .build())
                        .build())
                .setWebpushConfig(WebpushConfig.builder()
                        .setNotification(WebpushNotification.builder()
                                .setIcon("/icon.png")
                                .build())
                        .build());

        String messageId = FirebaseMessaging.getInstance().send(messageBuilder.build());
        log.debug("FCM push sent successfully, messageId: {}", messageId);
    }

    /**
     * Send a push notification to multiple tokens at once (batch).
     */
    @Async
    public void sendToMultipleTokens(List<String> fcmTokens, String title, String body,
                                     String imageUrl, String actionType, String actionData) {
        if (!isFirebaseAvailable() || fcmTokens.isEmpty()) {
            return;
        }

        Notification.Builder notificationBuilder = Notification.builder()
                .setTitle(title)
                .setBody(body);

        if (imageUrl != null && !imageUrl.isBlank()) {
            notificationBuilder.setImage(imageUrl);
        }

        MulticastMessage.Builder builder = MulticastMessage.builder()
                .addAllTokens(fcmTokens)
                .setNotification(notificationBuilder.build());

        if (actionType != null) builder.putData("actionType", actionType);
        if (actionData != null) builder.putData("actionData", actionData);

        try {
            BatchResponse response = FirebaseMessaging.getInstance().sendEachForMulticast(builder.build());
            log.info("FCM batch push: {} success, {} failure",
                    response.getSuccessCount(), response.getFailureCount());
        } catch (FirebaseMessagingException e) {
            log.error("FCM batch push failed: {}", e.getMessage());
        }
    }

    /**
     * Handle FCM send errors — mark invalid tokens as expired.
     */
    private void handleSendError(FirebaseMessagingException e, NotificationDeviceToken token) {
        MessagingErrorCode errorCode = e.getMessagingErrorCode();

        if (errorCode == MessagingErrorCode.UNREGISTERED
                || errorCode == MessagingErrorCode.INVALID_ARGUMENT) {
            // Token is invalid or expired — mark as expired in DB
            log.warn("FCM token invalid/expired for device {}, marking as EXPIRED", token.getDeviceId());
            // Token will be cleaned up on next registration
        } else {
            log.error("FCM push failed for device {}: {} ({})",
                    token.getDeviceId(), e.getMessage(), errorCode);
        }
    }
}
