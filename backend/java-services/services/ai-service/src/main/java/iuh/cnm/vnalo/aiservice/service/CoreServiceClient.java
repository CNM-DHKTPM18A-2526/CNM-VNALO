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
        } catch (Exception e) {
            log.warn("Could not fetch mascot settings for user {}: {}. Using defaults.", userId, e.getMessage());
            return null;
        }
    }
}
