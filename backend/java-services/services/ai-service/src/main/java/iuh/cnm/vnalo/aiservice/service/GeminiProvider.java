package iuh.cnm.vnalo.aiservice.service;

import com.google.genai.Client;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Part;
import iuh.cnm.vnalo.aiservice.dto.ChatMessage;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

/**
 * Gemini Provider — Primary LLM.
 * Uses Google GenAI Java SDK.
 * Throws RuntimeException on quota exhaustion for fallback.
 */
@Service
@Slf4j
public class GeminiProvider {

    @Value("${ai.gemini.api-key:}")
    private String apiKey;

    @Value("${ai.gemini.model:gemini-2.5-flash}")
    private String modelName;

    private Client client;
    private boolean available = false;

    @PostConstruct
    public void init() {
        if (apiKey != null && !apiKey.isBlank()) {
            try {
                this.client = Client.builder().apiKey(apiKey).build();
                this.available = true;
                log.info("Gemini initialized — model: {}", modelName);
            } catch (Exception e) {
                log.warn("Failed to initialize Gemini: {}", e.getMessage());
            }
        } else {
            log.warn("GEMINI_API_KEY not set — Gemini provider disabled");
        }
    }

    public boolean isAvailable() {
        return available;
    }

    public String generate(String systemPrompt, List<ChatMessage> messages) {
        if (!available) {
            throw new RuntimeException("Gemini not configured");
        }

        try {
            // Build conversation content
            List<Content> contents = new ArrayList<>();
            for (ChatMessage msg : messages) {
                String role = "user".equals(msg.getRole()) ? "user" : "model";
                contents.add(Content.builder()
                        .role(role)
                        .parts(List.of(Part.fromText(msg.getContent())))
                        .build());

            }

            // Build config with system instruction
            GenerateContentConfig config = GenerateContentConfig.builder()
                    .systemInstruction(Content.fromParts(Part.fromText(systemPrompt)))
                    .build();

            // Call Gemini API
            GenerateContentResponse response = client.models.generateContent(
                    modelName,
                    contents,
                    config
            );

            String answer = response.text();
            log.debug("Gemini response length: {} chars", answer != null ? answer.length() : 0);
            return answer;

        } catch (Exception e) {
            String message = e.getMessage() != null ? e.getMessage() : "Unknown error";

            if (message.contains("429") || message.contains("RESOURCE_EXHAUSTED")
                    || message.contains("quota") || message.contains("rate")) {
                log.warn("Gemini quota exhausted: {}", message);
                throw new RuntimeException("GEMINI_QUOTA_EXHAUSTED", e);
            }

            log.error("Gemini error: {}", message);
            throw new RuntimeException("GEMINI_ERROR: " + message, e);
        }
    }
}
