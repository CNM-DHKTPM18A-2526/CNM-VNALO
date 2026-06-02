package iuh.cnm.vnalo.aiservice.service;

import com.google.genai.Client;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentConfig;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Part;
import iuh.cnm.vnalo.aiservice.dto.Message;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class GeminiProvider {

    private final GeminiKeyManager keyManager;

    @Value("${ai.gemini.model:gemini-2.5-flash}")
    private String modelName;

    private boolean available = false;

    @PostConstruct
    public void init() {
        if (!keyManager.hasKeys()) {
            log.warn("GEMINI_API_KEY not set; Gemini provider disabled");
            return;
        }

        available = true;
        log.info("Gemini initialized - model: {}, keys: {}", modelName, keyManager.keyCount());
    }

    public boolean isAvailable() {
        return available;
    }

    public String generate(String systemPrompt, List<Message> messages) {
        if (!available) {
            throw new RuntimeException("Gemini not configured");
        }

        List<Content> contents = new ArrayList<>();
        for (Message msg : messages) {
            String role = "user".equals(msg.getRole()) ? "user" : "model";
            contents.add(Content.builder()
                    .role(role)
                    .parts(List.of(Part.fromText(msg.getContent())))
                    .build());
        }

        GenerateContentConfig config = GenerateContentConfig.builder()
                .systemInstruction(Content.fromParts(Part.fromText(systemPrompt)))
                .build();

        Exception lastError = null;
        int attempts = Math.max(1, keyManager.keyCount());
        for (int attempt = 0; attempt < attempts; attempt++) {
            String activeKey = keyManager.currentKey();
            try {
                Client client = Client.builder().apiKey(activeKey).build();
                GenerateContentResponse response = client.models.generateContent(modelName, contents, config);
                String answer = response.text();
                log.debug("Gemini response length: {} chars", answer != null ? answer.length() : 0);
                return answer;
            } catch (Exception e) {
                lastError = e;
                if (keyManager.isQuotaOrRateLimitError(e) && attempt < attempts - 1) {
                    keyManager.rotateAfterFailure(activeKey);
                    continue;
                }

                String message = e.getMessage() != null ? e.getMessage() : "Unknown error";
                if (keyManager.isQuotaOrRateLimitError(e)) {
                    log.warn("Gemini quota exhausted after {} attempt(s): {}", attempt + 1, message);
                    throw new RuntimeException("GEMINI_QUOTA_EXHAUSTED", e);
                }

                log.error("Gemini error: {}", message);
                throw new RuntimeException("GEMINI_ERROR: " + message, e);
            }
        }

        throw new RuntimeException("GEMINI_ERROR", lastError);
    }
}
