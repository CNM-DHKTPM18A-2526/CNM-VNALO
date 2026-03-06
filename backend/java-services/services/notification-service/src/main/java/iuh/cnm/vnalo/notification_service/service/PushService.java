package iuh.cnm.vnalo.notification_service.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.google.firebase.messaging.*;
import iuh.cnm.vnalo.notification_service.repository.NotificationDeviceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class PushService {

    private final NotificationDeviceRepository deviceRepo;

    /**
     * Gửi push cho toàn bộ thiết bị active của user.
     * - Không có token => skip
     * - Có token lỗi (unregistered/invalid) => tự deactivate
     */
    @Transactional
    public void sendToUser(UUID userId, String title, String body, JsonNode data) {
        List<String> tokens = deviceRepo.findActiveTokens(userId);

        if (tokens == null || tokens.isEmpty()) {
            log.info("No active FCM tokens for userId={}", userId);
            return;
        }

        // FCM multicast giới hạn 500 tokens / request
        List<List<String>> batches = partition(tokens, 500);

        for (List<String> batch : batches) {
            MulticastMessage msg = buildMessage(batch, title, body, data);

            try {
                BatchResponse resp = FirebaseMessaging.getInstance().sendEachForMulticast(msg);

                log.info("FCM multicast userId={} success={} failure={} batchSize={}",
                        userId, resp.getSuccessCount(), resp.getFailureCount(), batch.size());

                if (resp.getFailureCount() > 0) {
                    cleanupInvalidTokens(batch, resp);
                }

            } catch (FirebaseMessagingException e) {
                // Lỗi kiểu network/service unavailable: để Kafka retry
                log.error("FCM send failed userId={} errorCode={} message={}",
                        userId, e.getErrorCode(), e.getMessage(), e);
                throw new RuntimeException("FCM send failed", e);
            }
        }
    }

    private MulticastMessage buildMessage(List<String> tokens, String title, String body, JsonNode data) {
        MulticastMessage.Builder b = MulticastMessage.builder()
                .addAllTokens(tokens)
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(body)
                        .build());

        // optional: data payload (phải là string)
        if (data != null && data.isObject()) {
            Iterator<Map.Entry<String, JsonNode>> it = data.fields();
            while (it.hasNext()) {
                var e = it.next();
                if (e.getValue() != null && !e.getValue().isNull()) {
                    // FCM data chỉ nhận string => dùng asText() là an toàn
                    b.putData(e.getKey(), e.getValue().asText());
                }
            }
        }

        return b.build();
    }

    /**
     * Disable token nếu Firebase báo token invalid/unregistered.
     */
    private void cleanupInvalidTokens(List<String> tokens, BatchResponse resp) {
        List<SendResponse> responses = resp.getResponses();

        for (int i = 0; i < responses.size(); i++) {
            SendResponse r = responses.get(i);
            if (r.isSuccessful()) continue;

            FirebaseMessagingException ex = r.getException();
            String token = tokens.get(i);

            boolean shouldDeactivate = isInvalidToken(ex);

            log.warn("FCM send failed tokenPrefix={} errorCode={} message={} deactivate={}",
                    tokenPrefix(token),
                    ex != null ? ex.getErrorCode() : null,
                    ex != null ? ex.getMessage() : null,
                    shouldDeactivate
            );

            if (shouldDeactivate) {
                int updated = deviceRepo.deactivateByToken(token);
                log.info("Deactivated tokenPrefix={} updated={}", tokenPrefix(token), updated);
            }
        }
    }

    /**
     * Heuristic check cho token invalid/unregistered.
     * firebase-admin có thể trả MessagingErrorCode, nhưng đôi khi message chứa chuỗi.
     */
    private boolean isInvalidToken(FirebaseMessagingException ex) {
        if (ex == null) return false;

        // Khi token không còn hợp lệ, firebase thường trả UNREGISTERED
        if (ex.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) return true;

        String msg = ex.getMessage();
        if (msg == null) return false;

        String m = msg.toLowerCase(Locale.ROOT);
        return m.contains("registration-token-not-registered")
                || m.contains("not registered")
                || m.contains("invalid registration token")
                || m.contains("invalid-argument");
    }

    private static String tokenPrefix(String token) {
        if (token == null) return "null";
        return token.length() <= 16 ? token : token.substring(0, 16) + "...";
    }

    private static <T> List<List<T>> partition(List<T> list, int size) {
        if (list == null || list.isEmpty()) return List.of();
        List<List<T>> out = new ArrayList<>();
        for (int i = 0; i < list.size(); i += size) {
            out.add(list.subList(i, Math.min(i + size, list.size())));
        }
        return out;
    }
}