package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.Message;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Ollama Provider - Fallback LLM.
 * Calls Ollama's REST API (POST /api/chat).
 * Ollama runs in Docker container.
 */
@Service
@Slf4j
public class OllamaProvider {

    private final RestClient restClient;
    private final boolean enabled;
    private final String model;
    private final ObjectMapper objectMapper;

    public OllamaProvider(
            @Value("${ai.ollama.enabled:true}") boolean enabled,
            @Value("${ai.ollama.base-url:http://localhost:11434}") String baseUrl,
            @Value("${ai.ollama.model:llama3.1:8b}") String model
    ) {
        this.enabled = enabled;
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .build();
        this.model = model;
        this.objectMapper = new ObjectMapper();
        log.info("Ollama configured - enabled: {}, url: {}, model: {}", enabled, baseUrl, model);
    }

    public boolean isAvailable() {
        if (!enabled) {
            return false;
        }
        try {
            String response = restClient.get()
                    .uri("/api/tags")
                    .retrieve()
                    .body(String.class);
            return response != null;
        } catch (Exception e) {
            log.debug("Ollama not available: {}", e.getMessage());
            return false;
        }
    }

    public String generate(String systemPrompt, List<Message> messages) {
        if (!enabled) {
            throw new RuntimeException("OLLAMA_DISABLED");
        }
        try {
            List<Map<String, String>> ollamaMessages = new ArrayList<>();
            ollamaMessages.add(Map.of("role", "system", "content", systemPrompt));

            for (Message msg : messages) {
                ollamaMessages.add(Map.of("role", msg.getRole(), "content", msg.getContent()));
            }

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", model);
            requestBody.put("messages", ollamaMessages);
            requestBody.put("stream", false);
            requestBody.put("options", Map.of(
                    "temperature", 0.7,
                    "num_predict", 1024
            ));

            String responseJson = restClient.post()
                    .uri("/api/chat")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .body(String.class);

            JsonNode root = objectMapper.readTree(responseJson);
            String answer = root.path("message").path("content").asText("");

            log.debug("Ollama response length: {} chars", answer.length());
            return answer;
        } catch (Exception e) {
            log.error("Ollama error: {}", e.getMessage());
            throw new RuntimeException("OLLAMA_ERROR: " + e.getMessage(), e);
        }
    }
}
