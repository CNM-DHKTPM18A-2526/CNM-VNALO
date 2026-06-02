package iuh.cnm.vnalo.aiservice.service;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

@Component
@Slf4j
public class GeminiKeyManager {

    @Value("${ai.gemini.api-key:}")
    private String primaryApiKey;

    @Value("${ai.gemini.api-keys:}")
    private String apiKeysProperty;

    private final AtomicInteger currentIndex = new AtomicInteger(0);
    private List<String> apiKeys = Collections.emptyList();

    @PostConstruct
    public void init() {
        List<String> keys = new ArrayList<>();
        addKeys(keys, apiKeysProperty);
        addKeys(keys, primaryApiKey);
        apiKeys = keys.stream()
                .map(String::trim)
                .filter(key -> !key.isBlank())
                .distinct()
                .toList();

        if (apiKeys.isEmpty()) {
            log.warn("No Gemini API keys configured; Gemini provider disabled");
            return;
        }

        log.info("Gemini key manager initialized with {} key(s); active={}", apiKeys.size(), mask(currentKey()));
    }

    public boolean hasKeys() {
        return !apiKeys.isEmpty();
    }

    public int keyCount() {
        return apiKeys.size();
    }

    public String currentKey() {
        if (apiKeys.isEmpty()) {
            return "";
        }
        return apiKeys.get(Math.floorMod(currentIndex.get(), apiKeys.size()));
    }

    public String rotateAfterFailure(String failedKey) {
        if (apiKeys.size() <= 1) {
            return currentKey();
        }

        int failedIndex = apiKeys.indexOf(failedKey);
        int nextIndex = failedIndex >= 0 ? failedIndex + 1 : currentIndex.get() + 1;
        currentIndex.set(Math.floorMod(nextIndex, apiKeys.size()));
        String nextKey = currentKey();
        log.warn("Rotated Gemini API key after quota/rate-limit failure: {} -> {}", mask(failedKey), mask(nextKey));
        return nextKey;
    }

    public boolean isQuotaOrRateLimitError(Throwable error) {
        StringBuilder message = new StringBuilder();
        Throwable cursor = error;
        while (cursor != null) {
            if (cursor.getMessage() != null) {
                message.append(' ').append(cursor.getMessage().toLowerCase());
            }
            cursor = cursor.getCause();
        }

        String value = message.toString();
        return value.contains("429")
                || value.contains("quota")
                || value.contains("resource_exhausted")
                || value.contains("rate limit")
                || value.contains("rate-limit")
                || value.contains("too many requests");
    }

    private void addKeys(List<String> keys, String rawKeys) {
        if (rawKeys == null || rawKeys.isBlank()) {
            return;
        }
        Arrays.stream(rawKeys.split(","))
                .map(String::trim)
                .filter(key -> !key.isBlank())
                .forEach(keys::add);
    }

    private String mask(String key) {
        if (key == null || key.isBlank()) {
            return "<empty>";
        }
        if (key.length() <= 8) {
            return "****";
        }
        return key.substring(0, 4) + "..." + key.substring(key.length() - 4);
    }
}
