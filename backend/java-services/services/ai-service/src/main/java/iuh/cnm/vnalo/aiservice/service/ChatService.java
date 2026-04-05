package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.ChatMessage;
import iuh.cnm.vnalo.aiservice.dto.ChatResponse;
import iuh.cnm.vnalo.aiservice.exception.AiUnavailableException;
import iuh.cnm.vnalo.aiservice.exception.RateLimitExceededException;
import iuh.cnm.vnalo.aiservice.knowledge.SystemPrompt;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.Cursor;

import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

@Service
@Slf4j
public class ChatService {

    private final GeminiProvider geminiProvider;
    private final OllamaProvider ollamaProvider;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${ai.chat.rate-limit-per-user:5}")
    private int rateLimitPerUser;

    @Value("${ai.chat.rate-limit-global:10}")
    private int rateLimitGlobal;

    @Value("${ai.chat.max-history:20}")
    private int maxHistory;

    @Value("${ai.chat.history-ttl:86400}")
    private long historyTtl;

    public ChatService(GeminiProvider geminiProvider, OllamaProvider ollamaProvider, StringRedisTemplate redisTemplate) {
        this.geminiProvider = geminiProvider;
        this.ollamaProvider = ollamaProvider;
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
    }

    public ChatResponse ask(String userId, String message, String conversationId) {
        // 1. Check Rate Limit
        checkRateLimit(userId);

        // 2. Initialize conversation ID
        String convId = (conversationId != null && !conversationId.isBlank()) ? conversationId : UUID.randomUUID().toString();

        // 3. Load history
        List<ChatMessage> history = loadHistory(userId, convId);
        
        // 4. Add user message
        history.add(new ChatMessage("user", message));

        // Keep last N messages
        List<ChatMessage> trimmedHistory = trimHistory(history);

        // 5. Generate Answer (Gemini -> Ollama fallback)
        String answer;
        String provider;

        try {
            if (geminiProvider.isAvailable()) {
                // Check global rate limit before calling Gemini
                checkGlobalRateLimit();
                answer = geminiProvider.generate(SystemPrompt.VNALO_SYSTEM_PROMPT, trimmedHistory);
                provider = "gemini";
                log.info("Response via Gemini for user {}", userId);
            } else {
                throw new RuntimeException("Gemini not configured");
            }
        } catch (Exception geminiEx) {
            log.warn("Gemini failed ({}), falling back to Ollama...", geminiEx.getMessage());
            
            try {
                answer = ollamaProvider.generate(SystemPrompt.VNALO_SYSTEM_PROMPT, trimmedHistory);
                provider = "ollama";
                log.info("Response via Ollama (fallback) for user {}", userId);
            } catch (Exception ollamaEx) {
                log.error("Both providers failed. Gemini: {}, Ollama: {}", geminiEx.getMessage(), ollamaEx.getMessage());
                throw new AiUnavailableException("AI service hiện không khả dụng. Vui lòng thử lại sau.");
            }
        }

        // 6. Save answer to history
        trimmedHistory.add(new ChatMessage("assistant", answer));
        saveHistory(userId, convId, trimHistory(trimmedHistory));


        // 7. Return response
        return ChatResponse.builder()
                .answer(answer)
                .conversationId(convId)
                .provider(provider)
                .timestamp(DateTimeFormatter.ISO_INSTANT.format(Instant.now()))
                .build();
    }

    public List<ChatMessage> getHistory(String userId, String conversationId) {
        if (conversationId == null || conversationId.isBlank()) {
            return new ArrayList<>();
        }
        return loadHistory(userId, conversationId);
    }

    public List<String> getUserConversations(String userId) {
        String pattern = "ai:history:" + userId + ":*";
        Set<String> keys = scanKeys(pattern);
        if (keys.isEmpty()) return new ArrayList<>();

        return keys.stream()
                .map(key -> key.substring(key.lastIndexOf(':') + 1))
                .collect(Collectors.toList());
    }

    public void deleteHistory(String userId, String conversationId) {
        if (conversationId != null && !conversationId.isBlank()) {
            redisTemplate.delete(historyKey(userId, conversationId));
        } else {
            String pattern = "ai:history:" + userId + ":*";
            Set<String> keys = scanKeys(pattern);
            if (!keys.isEmpty()) {
                redisTemplate.delete(keys);
            }
        }
    }

    // --- Helpers ---

    private void checkRateLimit(String userId) {
        long currentMinute = Instant.now().getEpochSecond() / 60;
        String key = "rl:ai:user:" + userId + ":" + currentMinute;
        
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1) {
            redisTemplate.expire(key, 60, TimeUnit.SECONDS);
        }

        if (count != null && count > rateLimitPerUser) {
            throw new RateLimitExceededException("Bạn đã gửi quá " + rateLimitPerUser + " câu hỏi trong 1 phút. Vui lòng chờ.");
        }
    }

    private void checkGlobalRateLimit() {
        long currentMinute = Instant.now().getEpochSecond() / 60;
        String key = "rl:ai:global:" + currentMinute;

        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1) {
            redisTemplate.expire(key, 60, TimeUnit.SECONDS);
        }

        if (count != null && count > rateLimitGlobal) {
            throw new RuntimeException("GLOBAL_RATE_LIMIT_EXCEEDED_SWITCH_TO_OLLAMA");
        }
    }

    private String historyKey(String userId, String conversationId) {
        return "ai:history:" + userId + ":" + conversationId;
    }

    private Set<String> scanKeys(String pattern) {
        Set<String> keys = redisTemplate.execute(connection -> {
            Set<String> result = new LinkedHashSet<>();
            ScanOptions options = ScanOptions.scanOptions().match(pattern).count(100).build();

            try (Cursor<byte[]> cursor = connection.scan(options)) {
                while (cursor.hasNext()) {
                    byte[] keyBytes = cursor.next();
                    String key = redisTemplate.getStringSerializer().deserialize(keyBytes);
                    if (key != null) {
                        result.add(key);
                    }
                }
            } catch (Exception e) {
                log.warn("Failed to scan Redis keys by pattern {}: {}", pattern, e.getMessage());
            }

            return result;
        });
        return keys != null ? keys : new LinkedHashSet<>();
    }

    private List<ChatMessage> loadHistory(String userId, String conversationId) {
        String key = historyKey(userId, conversationId);
        String raw = redisTemplate.opsForValue().get(key);
        if (raw == null || raw.isBlank()) {
            return new ArrayList<>();
        }
        try {
            return objectMapper.readValue(raw, new TypeReference<List<ChatMessage>>() {});
        } catch (JsonProcessingException e) {
            log.warn("Failed to parse history JSON: {}", e.getMessage());
            return new ArrayList<>();
        }
    }

    private void saveHistory(String userId, String conversationId, List<ChatMessage> messages) {
        String key = historyKey(userId, conversationId);
        try {
            String raw = objectMapper.writeValueAsString(messages);
            redisTemplate.opsForValue().set(key, raw, historyTtl, TimeUnit.SECONDS);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize history: {}", e.getMessage());
        }
    }

    private List<ChatMessage> trimHistory(List<ChatMessage> history) {
        if (history.size() <= maxHistory) {
            return history;
        }
        return new ArrayList<>(history.subList(history.size() - maxHistory, history.size()));
    }
}
