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

    @Value("${services.core-service.url:http://core-service:8080}")
    private String coreServiceUrl;

    public MascotSettingsDTO getUserMascotSettings(String userId) {
        try {
            String url = coreServiceUrl + "/api/v1/ai/mascot/internal/settings?userId=" + userId;
            return restTemplate.getForObject(url, MascotSettingsDTO.class);
    public void saveChatHistory(String userId, String conversationId, java.util.List<java.util.Map<String, String>> messages) {
        try {
            String url = coreServiceUrl + "/api/v1/ai/internal/history";
            java.util.Map<String, Object> body = new java.util.HashMap<>();
            body.put("userId", userId);
            body.put("conversationId", conversationId);
            body.put("messages", messages);
            
            restTemplate.postForEntity(url, body, Void.class);
        } catch (Exception e) {
            log.warn("Failed to persist chat history to core-service: {}", e.getMessage());
        }
    }
}
