package iuh.cnm.vnalo.aiservice.service;

import iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class CoreServiceClient {

    private final RestTemplate restTemplate;

    @Value("${services.core-service.url:http://core-service:8081}")
    private String coreServiceUrl;

    @Value("${ai.internal-secret:VNALO_AI_SECRET_2026}")
    private String internalSecret;

    public MascotSettingsDTO getUserMascotSettings(String userId) {
        try {
            String url = coreServiceUrl + "/api/v1/ai/mascot/internal/settings?userId=" + userId;
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.set("X-Internal-Secret", internalSecret);
            org.springframework.http.HttpEntity<Void> entity = new org.springframework.http.HttpEntity<>(headers);
            return restTemplate.exchange(url, org.springframework.http.HttpMethod.GET, entity, MascotSettingsDTO.class).getBody();
        } catch (Exception e) {
            log.warn("Failed to fetch mascot settings for user {}: {}", userId, e.getMessage());
            return null;
        }
    }

    public void saveChatHistory(String userId, String conversationId, java.util.List<java.util.Map<String, String>> messages) {
        try {
            String url = coreServiceUrl + "/api/v1/ai/internal/history";
            java.util.Map<String, Object> body = new java.util.HashMap<>();
            body.put("userId", userId);
            body.put("conversationId", conversationId);
            body.put("messages", messages);
            
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.set("X-Internal-Secret", internalSecret);
            org.springframework.http.HttpEntity<java.util.Map<String, Object>> entity = new org.springframework.http.HttpEntity<>(body, headers);
            restTemplate.exchange(url, org.springframework.http.HttpMethod.POST, entity, Void.class);
        } catch (Exception e) {
            log.warn("Failed to persist chat history to core-service: {}", e.getMessage());
        }
    }

    public java.util.List<iuh.cnm.vnalo.aiservice.dto.Message> getChatHistory(String userId, String conversationId) {
        try {
            String url = coreServiceUrl + "/api/v1/ai/internal/history?userId=" + userId + "&conversationId=" + conversationId;
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.set("X-Internal-Secret", internalSecret);
            org.springframework.http.HttpEntity<Void> entity = new org.springframework.http.HttpEntity<>(headers);

            java.util.List<?> rawList = restTemplate.exchange(url, org.springframework.http.HttpMethod.GET, entity, java.util.List.class).getBody();
            java.util.List<iuh.cnm.vnalo.aiservice.dto.Message> messages = new java.util.ArrayList<>();
            if (rawList != null) {
                for (Object rawObj : rawList) {
                    if (rawObj instanceof java.util.Map) {
                        java.util.Map<?, ?> map = (java.util.Map<?, ?>) rawObj;
                        String role = (String) map.get("role");
                        String content = (String) map.get("content");
                        String provider = (String) map.get("provider");

                        iuh.cnm.vnalo.aiservice.dto.Message message = new iuh.cnm.vnalo.aiservice.dto.Message(role, content);
                        message.setProvider(provider);
                        messages.add(message);
                    }
                }
            }
            return messages;
        } catch (Exception e) {
            log.warn("Failed to retrieve chat history from core-service: {}", e.getMessage());
            return new java.util.ArrayList<>();
        }
    }
}
