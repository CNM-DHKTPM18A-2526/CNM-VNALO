package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.Message;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Ollama Provider — Fallback LLM.
 * Calls Ollama's REST API (POST /api/chat).
 * Ollama runs in Docker container.
 */
@Service
@Slf4j
public class OllamaProvider {

    private final RestClient restClient;
    private final String model;
    private final ObjectMapper objectMapper;

    public OllamaProvider(
            @Value("${ai.ollama.base-url:http://localhost:11434}") String baseUrl,
            @Value("${ai.ollama.model:llama3.1:8b}") String model
    ) {
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .build();
        this.model = model;
        this.objectMapper = new ObjectMapper();
        log.info("Ollama configured — url: {}, model: {}", baseUrl, model);
    }

    public boolean isAvailable() {
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
        try {
            // Build Ollama message format
            List<Map<String, String>> ollamaMessages = new ArrayList<>();

            // System message
            ollamaMessages.add(Map.of("role", "system", "content", systemPrompt));

            // Conversation history
            for (Message msg : messages) {
                ollamaMessages.add(Map.of("role", msg.getRole(), "content", msg.getContent()));
            }

            // Build request body
            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", model);
            requestBody.put("messages", ollamaMessages);
            requestBody.put("stream", false);
            requestBody.put("options", Map.of(
                    "temperature", 0.7,
                    "num_predict", 1024
            ));

            // Call Ollama API
            String responseJson = restClient.post()
                    .uri("/api/chat")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .body(String.class);

            // Parse response
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
