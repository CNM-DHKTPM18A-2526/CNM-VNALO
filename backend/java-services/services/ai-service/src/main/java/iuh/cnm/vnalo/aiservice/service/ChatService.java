package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.Message;
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
import org.springframework.data.redis.core.RedisCallback;

import java.time.Instant;
import java.time.OffsetDateTime;
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
    private final CoreServiceClient coreServiceClient;
    private final ObjectMapper objectMapper;

    @Value("${ai.chat.rate-limit-per-user:5}")
    private int rateLimitPerUser;

    @Value("${ai.chat.rate-limit-global:10}")
    private int rateLimitGlobal;

    @Value("${ai.chat.max-history:20}")
    private int maxHistory;

    @Value("${ai.chat.history-ttl:86400}")
    private long historyTtl;

    public ChatService(GeminiProvider geminiProvider, OllamaProvider ollamaProvider, 
                       StringRedisTemplate redisTemplate, CoreServiceClient coreServiceClient) {
        this.geminiProvider = geminiProvider;
        this.ollamaProvider = ollamaProvider;
        this.redisTemplate = redisTemplate;
        this.coreServiceClient = coreServiceClient;
        this.objectMapper = new ObjectMapper();
    }

    public void enforceUserRateLimit(String userId) {
        checkRateLimit(userId);
    }

    public void enforceGlobalRateLimit() {
        checkGlobalRateLimit();
    }

    public ChatResponse ask(String userId, String message, String conversationId) {
        // 1. Check Rate Limit
        checkRateLimit(userId);

        // 2. Initialize conversation ID
        String convId = (conversationId != null && !conversationId.isBlank()) ? conversationId : UUID.randomUUID().toString();
        String userEntryId = UUID.randomUUID().toString();
        OffsetDateTime userCreatedAt = OffsetDateTime.now(ZoneOffset.UTC);

        // 3. Load history
        List<Message> history = loadHistory(userId, convId);
        
        // 4. Add user message
        Message userHistoryMessage = new Message("user", message);
        userHistoryMessage.setClientEntryId(userEntryId);
        userHistoryMessage.setCreatedAt(userCreatedAt.toString());
        history.add(userHistoryMessage);

        // Keep last N messages
        List<Message> trimmedHistory = trimHistory(history);

        // 5. Build Dynamic System Prompt based on Mascot Settings
        iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO mascot = coreServiceClient.getUserMascotSettings(userId);
        String dynamicSystemPrompt = buildSystemPrompt(mascot);

        // 6. Generate Answer (Gemini -> Ollama fallback)
        String answer;
        String provider;

        try {
            if (geminiProvider.isAvailable()) {
                // Check global rate limit before calling Gemini
                checkGlobalRateLimit();
                answer = geminiProvider.generate(dynamicSystemPrompt, trimmedHistory);
                provider = "gemini";
                log.info("Response via Gemini for user {}", userId);
            } else {
                throw new RuntimeException("Gemini not configured");
            }
        } catch (Exception geminiEx) {
            log.warn("Gemini failed ({}), falling back to Ollama...", geminiEx.getMessage());
            
            try {
                answer = ollamaProvider.generate(dynamicSystemPrompt, trimmedHistory);
                provider = "ollama";
                log.info("Response via Ollama (fallback) for user {}", userId);
            } catch (Exception ollamaEx) {
                log.error("Both providers failed. Gemini: {}, Ollama: {}", geminiEx.getMessage(), ollamaEx.getMessage());
                throw new AiUnavailableException("AI service hiện không khả dụng. Vui lòng thử lại sau.");
            }
        }

        // 7. Persist to Postgres (Async-like via internal API)
        java.util.List<java.util.Map<String, String>> messagesToSave = new java.util.ArrayList<>();
        OffsetDateTime assistantCreatedAt = OffsetDateTime.now(ZoneOffset.UTC);
        String assistantEntryId = UUID.randomUUID().toString();
        
        java.util.Map<String, String> userMsg = new java.util.HashMap<>();
        userMsg.put("role", "user");
        userMsg.put("content", message);
        userMsg.put("createdAt", userCreatedAt.toString());
        userMsg.put("clientEntryId", userEntryId);
        messagesToSave.add(userMsg);
        
        java.util.Map<String, String> assistantMsg = new java.util.HashMap<>();
        assistantMsg.put("role", "assistant");
        assistantMsg.put("content", answer);
        assistantMsg.put("provider", provider != null ? provider : "unknown");
        assistantMsg.put("createdAt", assistantCreatedAt.toString());
        assistantMsg.put("clientEntryId", assistantEntryId);
        messagesToSave.add(assistantMsg);
        
        coreServiceClient.saveChatHistory(userId, convId, messagesToSave);

        // 8. Save answer to history (Redis)
        Message assistantHistoryMessage = new Message("assistant", answer);
        assistantHistoryMessage.setProvider(provider);
        assistantHistoryMessage.setClientEntryId(assistantEntryId);
        assistantHistoryMessage.setCreatedAt(assistantCreatedAt.toString());
        trimmedHistory.add(assistantHistoryMessage);
        saveHistory(userId, convId, trimHistory(trimmedHistory));


        // 9. Return response
        return ChatResponse.builder()
                .answer(answer)
                .conversationId(convId)
                .provider(provider)
                .timestamp(DateTimeFormatter.ISO_INSTANT.format(Instant.now()))
                .userEntryId(userEntryId)
                .assistantEntryId(assistantEntryId)
                .build();
    }

    public void backupHistory(String userId, String conversationId, List<Message> entries) {
        if (entries == null || entries.isEmpty()) return;
        saveHistory(userId, conversationId, entries);

        java.util.List<java.util.Map<String, String>> messagesToSave = new java.util.ArrayList<>();
        for (Message entry : entries) {
            java.util.Map<String, String> msg = new java.util.HashMap<>();
            msg.put("role", entry.getRole());
            msg.put("content", entry.getContent());
            msg.put("provider", entry.getProvider() != null ? entry.getProvider() : "unknown");
            if (entry.getCreatedAt() != null) {
                msg.put("createdAt", entry.getCreatedAt());
            }
            if (entry.getClientEntryId() != null) {
                msg.put("clientEntryId", entry.getClientEntryId());
            }
            messagesToSave.add(msg);
        }
        coreServiceClient.saveChatHistory(userId, conversationId, messagesToSave);
    }

    public List<Message> getHistory(String userId, String conversationId) {
        if (conversationId == null || conversationId.isBlank()) {
            return new ArrayList<>();
        }
        List<Message> persistedHistory = coreServiceClient.getChatHistory(userId, conversationId);
        if (!persistedHistory.isEmpty()) {
            saveHistory(userId, conversationId, persistedHistory);
            return persistedHistory;
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

    public List<String> suggestReplies(List<Message> history) {
        if (history == null || history.isEmpty()) {
            return List.of("Chào bạn!", "Dạ vâng ạ", "Ok cậu nhé");
        }

        String systemPrompt = "Bạn là trợ lý ảo phân tích tin nhắn của VNALO. Hãy phân tích ngữ cảnh hội thoại được cung cấp (đặc biệt là tin nhắn cuối cùng) và đưa ra chính xác 3 gợi ý phản hồi tự nhiên, ngắn gọn bằng tiếng Việt phù hợp nhất. Trả về kết quả dưới dạng JSON Array phẳng duy nhất, ví dụ: [\"Ok luôn!\", \"Mấy giờ đi thế bạn?\", \"Tối nay tớ bận mất rồi.\"]. Tuyệt đối không trả thêm bất kỳ văn bản phụ hay markdown tag nào khác ngoài chuỗi JSON Array này.";

        try {
            String rawResponse = "";
            if (geminiProvider.isAvailable()) {
                rawResponse = geminiProvider.generate(systemPrompt, history);
            } else if (ollamaProvider.isAvailable()) {
                rawResponse = ollamaProvider.generate(systemPrompt, history);
            }

            if (rawResponse != null && !rawResponse.isBlank()) {
                String cleanJson = extractJsonArray(rawResponse);
                if (cleanJson != null) {
                    try {
                        return objectMapper.readValue(cleanJson, new TypeReference<List<String>>() {});
                    } catch (Exception e) {
                        log.warn("Failed to parse suggest replies JSON: {}, Raw: {}", e.getMessage(), rawResponse);
                    }
                }
            }
        } catch (Exception e) {
            log.error("Failed to generate suggest replies: {}", e.getMessage());
        }

        return List.of("Dạ vâng ạ", "Ok cậu nhé", "Để mình xem lại nha");
    }

    private String extractJsonArray(String text) {
        if (text == null) return null;
        int start = text.indexOf("[");
        int end = text.lastIndexOf("]");
        if (start != -1 && end != -1 && start < end) {
            return text.substring(start, end + 1);
        }
        return null;
    }

    // --- Helpers ---

    private String buildSystemPrompt(iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO mascot) {
        if (mascot == null) return SystemPrompt.VNALO_SYSTEM_PROMPT;

        StringBuilder sb = new StringBuilder(SystemPrompt.VNALO_SYSTEM_PROMPT);
        sb.append("\n\n[DYNAMICS SETTINGS]");
        sb.append("\n- Tên của bạn hiện tại là: ").append(mascot.getMascotName());
        sb.append("\n- Cá tính của bạn: ").append(mascot.getPersonalityType());
        if (mascot.getCustomInstructions() != null && !mascot.getCustomInstructions().isBlank()) {
            sb.append("\n- Chỉ dẫn đặc biệt từ người dùng: ").append(mascot.getCustomInstructions());
        }
        return sb.toString();
    }

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
        Set<String> keys = redisTemplate.execute((RedisCallback<Set<String>>) connection -> {
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

    private List<Message> loadHistory(String userId, String conversationId) {
        String key = historyKey(userId, conversationId);
        String raw = redisTemplate.opsForValue().get(key);
        if (raw == null || raw.isBlank()) {
            return new ArrayList<>();
        }
        try {
            return objectMapper.readValue(raw, new TypeReference<List<Message>>() {});
        } catch (JsonProcessingException e) {
            log.warn("Failed to parse history JSON: {}", e.getMessage());
            return new ArrayList<>();
        }
    }

    private void saveHistory(String userId, String conversationId, List<Message> messages) {
        String key = historyKey(userId, conversationId);
        try {
            String raw = objectMapper.writeValueAsString(messages);
            redisTemplate.opsForValue().set(key, raw, historyTtl, TimeUnit.SECONDS);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize history: {}", e.getMessage());
        }
    }

    private List<Message> trimHistory(List<Message> history) {
        if (history.size() <= maxHistory) {
            return history;
        }
        return new ArrayList<>(history.subList(history.size() - maxHistory, history.size()));
    }
}
