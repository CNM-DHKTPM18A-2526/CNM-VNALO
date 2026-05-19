package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.Message;
import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeminiAiService {

    private final RestTemplate geminiRestTemplate;
    private final ObjectMapper objectMapper;
    private final CoreServiceClient coreServiceClient;
    private final OllamaProvider ollamaProvider;
    private final ChatService chatService;

    @Value("${ai.gemini.model:gemini-1.5-flash}")
    private String modelName;

    private static final java.util.Set<String> ALLOWED_COMMANDS = java.util.Set.of(
        "OPEN_CHAT",
        "COMPOSE_MESSAGE",
        "START_CALL",
        "RECALL_MESSAGE",
        "NAVIGATE_TO",
        "NAVIGATE_TO_SETTINGS",
        "NAVIGATE_TO_CHAT",
        "NAVIGATE_TO_CONTACTS",
        "NAVIGATE_TO_SCANNER",
        "NAVIGATE_TO_TIMELINE"
    );

    // Direct REST formulation to bypass volatile SDK version constraints
    private static final String GEMINI_REST_URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent";

    public AiChatResponse interactWithGemini(String userId, AiChatRequest request) {
        // 1. Check Rate Limit via ChatService
        chatService.enforceUserRateLimit(userId);

        // 2. Fetch Mascot Settings
        iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO mascot = coreServiceClient.getUserMascotSettings(userId);

        // 3. Build Dynamic System Prompt based on Mascot Settings
        String dynamicSystemPrompt = buildSystemPrompt(mascot, request.isEnableDeepSummary());
        String stableConvId = UUID.nameUUIDFromBytes(
                ("AI_ASSISTANT_" + userId).getBytes(java.nio.charset.StandardCharsets.UTF_8)
        ).toString();
        String userEntryId = normalizeEntryId(request.getClientUserEntryId(), UUID.randomUUID().toString());
        String assistantEntryId = normalizeEntryId(request.getClientAssistantEntryId(), UUID.randomUUID().toString());
        OffsetDateTime userCreatedAt = OffsetDateTime.now(ZoneOffset.UTC);

        String url = String.format(GEMINI_REST_URL, modelName);
        Map<String, Object> payload = buildGeminiPayload(request, dynamicSystemPrompt);

        String answer = null;
        String provider = "gemini";
        AiChatResponse responseObj = null;

        try {
            // Check Global Rate Limit via ChatService
            chatService.enforceGlobalRateLimit();

            // Call Gemini
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload);
            ResponseEntity<String> response = geminiRestTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            responseObj = parseGeminiResponse(response.getBody(), request.isAnalyzeIntent());
            answer = responseObj.getTextReply();
        } catch (Exception geminiEx) {
            log.warn("Gemini failed in GeminiAiService ({}), falling back to Ollama...", geminiEx.getMessage());
            try {
                // Prepare messages list for Ollama fallback
                List<Message> historyMessages = new ArrayList<>();
                if (request.getHistory() != null) {
                    historyMessages.addAll(request.getHistory());
                }
                // Append the current user prompt so Ollama receives the actual input!
                historyMessages.add(new Message("user", request.getPrompt()));

                String ollamaAnswer = ollamaProvider.generate(dynamicSystemPrompt, historyMessages);
                responseObj = parseFallbackResponse(ollamaAnswer, request.isAnalyzeIntent());
                answer = responseObj.getTextReply();
                provider = "ollama";
            } catch (Exception ollamaEx) {
                log.error("Both providers failed in GeminiAiService. Gemini: {}, Ollama: {}", geminiEx.getMessage(), ollamaEx.getMessage());
                throw new RuntimeException("AI_SERVICE_ERROR");
            }
        }

        if (responseObj != null) {
            responseObj.setConversationId(stableConvId);
            responseObj.setUserEntryId(userEntryId);
            responseObj.setAssistantEntryId(assistantEntryId);
        }

        // 5. Save Chat History asynchronously-like to Core Service
        try {
            List<Map<String, String>> messagesToSave = new ArrayList<>();
            Map<String, String> userMsg = new HashMap<>();
            userMsg.put("role", "user");
            userMsg.put("content", request.getPrompt());
            userMsg.put("createdAt", userCreatedAt.toString());
            userMsg.put("clientEntryId", userEntryId);
            messagesToSave.add(userMsg);

            Map<String, String> assistantMsg = new HashMap<>();
            assistantMsg.put("role", "assistant");
            assistantMsg.put("content", answer);
            assistantMsg.put("provider", provider);
            assistantMsg.put("createdAt", OffsetDateTime.now(ZoneOffset.UTC).toString());
            assistantMsg.put("clientEntryId", assistantEntryId);
            messagesToSave.add(assistantMsg);

            coreServiceClient.saveChatHistory(userId, stableConvId, messagesToSave);
        } catch (Exception e) {
            log.warn("Failed to persist chat history from GeminiAiService to core-service: {}", e.getMessage());
        }

        return responseObj;
    }

    private String normalizeEntryId(String requestedEntryId, String fallbackEntryId) {
        if (requestedEntryId == null || requestedEntryId.isBlank()) {
            return fallbackEntryId;
        }
        return requestedEntryId.trim();
    }

    private String buildSystemPrompt(iuh.cnm.vnalo.aiservice.dto.external.MascotSettingsDTO mascot, boolean enableDeepSummary) {
        StringBuilder sb = new StringBuilder(iuh.cnm.vnalo.aiservice.knowledge.SystemPrompt.VNALO_SYSTEM_PROMPT);
        if (enableDeepSummary) {
            sb.append("\n\nLƯU Ý: Người dùng đã yêu cầu phản hồi sâu (Deep Summary). Hãy phân tích kỹ và trả lời chi tiết hơn bình thường.");
        }
        if (mascot != null) {
            sb.append("\n\n[DYNAMICS SETTINGS]");
            sb.append("\n- Tên của bạn hiện tại là: ").append(mascot.getMascotName());
            sb.append("\n- Cá tính của bạn: ").append(mascot.getPersonalityType());
            if (mascot.getCustomInstructions() != null && !mascot.getCustomInstructions().isBlank()) {
                sb.append("\n- Chỉ dẫn đặc biệt từ người dùng: ").append(mascot.getCustomInstructions());
            }
        }
        return sb.toString();
    }

    private Map<String, Object> buildGeminiPayload(AiChatRequest request, String systemPrompt) {
        List<Map<String, Object>> contents = new ArrayList<>();

        contents.add(createContent("user", "SYSTEM INSTRUCTION:\n" + systemPrompt));

        // 2. Structured History Alignment
        if (request.getHistory() != null && !request.getHistory().isEmpty()) {
            for (Message msg : request.getHistory()) {
                // Map mobile roles to Gemini roles (user -> user, assistant -> model)
                String role = "assistant".equalsIgnoreCase(msg.getRole()) ? "model" : "user";
                contents.add(createContent(role, msg.getContent()));
            }
        }

        // 3. Current User Input
        contents.add(createContent("user", request.getPrompt()));

        Map<String, Object> payload = new HashMap<>();
        payload.put("contents", contents);

        return payload;
    }

    private void sanitizeActionCommand(AiChatResponse response, JsonNode cmdNode) {
        String actionCommand = cmdNode.path("actionCommand").asText(null);
        if (actionCommand != null) {
            actionCommand = actionCommand.toUpperCase().trim();
            if ("SEND_MESSAGE".equals(actionCommand)) {
                actionCommand = "COMPOSE_MESSAGE";
            }
            if (ALLOWED_COMMANDS.contains(actionCommand)) {
                response.setActionCommand(actionCommand);
            } else {
                log.warn("Blocked untrusted/unsupported LLM actionCommand: {}", actionCommand);
                response.setActionCommand(null);
            }
        }

        if (response.getActionCommand() != null && cmdNode.has("actionParams")) {
            try {
                Map<String, Object> params = objectMapper.convertValue(cmdNode.get("actionParams"), Map.class);
                Map<String, Object> cleanParams = new HashMap<>();
                for (Map.Entry<String, Object> entry : params.entrySet()) {
                    if (entry.getValue() instanceof String val) {
                        if (val.length() > 500) {
                            cleanParams.put(entry.getKey(), val.substring(0, 500));
                        } else {
                            cleanParams.put(entry.getKey(), val);
                        }
                    } else if (entry.getValue() instanceof Number || entry.getValue() instanceof Boolean) {
                        cleanParams.put(entry.getKey(), entry.getValue());
                    }
                }
                response.setActionParams(cleanParams);
            } catch (Exception e) {
                log.warn("Failed to sanitize action params: {}", e.getMessage());
                response.setActionParams(null);
            }
        }

        // Validate required schema params for allowed commands
        if (response.getActionCommand() != null) {
            String cmd = response.getActionCommand();
            Map<String, Object> cp = response.getActionParams();
            boolean valid = true;
            if (cp == null) {
                cp = new HashMap<>();
                response.setActionParams(cp);
            }
            if ("COMPOSE_MESSAGE".equals(cmd)) {
                String recipient = null;
                if (cp.containsKey("recipient")) recipient = String.valueOf(cp.get("recipient"));
                else if (cp.containsKey("target")) recipient = String.valueOf(cp.get("target"));
                else if (cp.containsKey("contactName")) recipient = String.valueOf(cp.get("contactName"));
                else if (cp.containsKey("displayName")) recipient = String.valueOf(cp.get("displayName"));

                String content = null;
                if (cp.containsKey("content")) content = String.valueOf(cp.get("content"));
                else if (cp.containsKey("messageText")) content = String.valueOf(cp.get("messageText"));
                else if (cp.containsKey("prefilledText")) content = String.valueOf(cp.get("prefilledText"));

                if (recipient == null || recipient.trim().isEmpty() || content == null || content.trim().isEmpty()) {
                    valid = false;
                } else {
                    cp.put("recipient", recipient.trim());
                    cp.put("content", content.trim());
                }
            } else if ("OPEN_CHAT".equals(cmd) || "START_CALL".equals(cmd)) {
                String target = null;
                if (cp.containsKey("target")) target = String.valueOf(cp.get("target"));
                else if (cp.containsKey("recipient")) target = String.valueOf(cp.get("recipient"));
                else if (cp.containsKey("contactName")) target = String.valueOf(cp.get("contactName"));
                else if (cp.containsKey("displayName")) target = String.valueOf(cp.get("displayName"));

                if (target == null || target.trim().isEmpty()) {
                    valid = false;
                } else {
                    cp.put("target", target.trim());
                }
            } else if ("NAVIGATE_TO".equals(cmd)) {
                String page = null;
                if (cp.containsKey("page")) page = String.valueOf(cp.get("page"));
                else if (cp.containsKey("destination")) page = String.valueOf(cp.get("destination"));
                else if (cp.containsKey("screen")) page = String.valueOf(cp.get("screen"));

                if (page == null || page.trim().isEmpty()) {
                    valid = false;
                } else {
                    cp.put("page", page.trim().toLowerCase());
                }
            }
            if (!valid) {
                log.warn("Blocked action command '{}' due to missing or invalid required schema fields in params: {}", cmd, cp);
                response.setActionCommand(null);
                response.setActionParams(null);
            }
        }
    }

    private AiChatResponse parseFallbackResponse(String rawText, boolean isAnalyzingIntent) throws Exception {
        AiChatResponse response = new AiChatResponse();
        String cleanJson = extractJson(rawText);

        if (cleanJson != null) {
            try {
                JsonNode cmdNode = objectMapper.readTree(cleanJson);
                response.setTextReply(cmdNode.path("textReply").asText(""));
                response.setEmotion(cmdNode.path("emotion").asText("thinking"));

                if (isAnalyzingIntent) {
                    sanitizeActionCommand(response, cmdNode);
                } else {
                    response.setActionCommand(null);
                    response.setActionParams(null);
                }

                if (response.getActionCommand() != null && response.getTextReply().isEmpty()) {
                    response.setTextReply("Đã rõ, tôi đang thực hiện lệnh của bạn...");
                }

                return response;
            } catch (Exception e) {
                log.warn("Failed to parse fallback extracted JSON. Falling back to raw text.");
            }
        }

        response.setTextReply(rawText);
        response.setEmotion("thinking");
        return response;
    }

    private Map<String, Object> createContent(String role, String text) {
        Map<String, Object> part = new HashMap<>();
        part.put("text", text);

        Map<String, Object> content = new HashMap<>();
        content.put("role", role);
        content.put("parts", List.of(part));
        return content;
    }

    private AiChatResponse parseGeminiResponse(String jsonBody, boolean isAnalyzingIntent) throws Exception {
        JsonNode rootNode = objectMapper.readTree(jsonBody);
        JsonNode candidates = rootNode.path("candidates");

        if (candidates.isMissingNode() || !candidates.isArray() || candidates.size() == 0) {
            return AiChatResponse.builder().textReply("I'm sorry, I couldn't process that.").build();
        }

        String fallbackText = "I'm sorry, I couldn't process that.";
        JsonNode firstCandidate = candidates.get(0);
        JsonNode contentNode = firstCandidate.path("content");
        JsonNode partsNode = contentNode.path("parts");

        if (partsNode.isMissingNode() || !partsNode.isArray() || partsNode.size() == 0) {
            return AiChatResponse.builder().textReply(fallbackText).build();
        }

        String rawText = partsNode.get(0).path("text").asText();

        // Intent parsing - Handle JSON within response
        AiChatResponse response = new AiChatResponse();
        String cleanJson = extractJson(rawText);

        if (cleanJson != null) {
            try {
                JsonNode cmdNode = objectMapper.readTree(cleanJson);

                // Map the JSON schema to DTO
                response.setTextReply(cmdNode.path("textReply").asText(""));
                response.setEmotion(cmdNode.path("emotion").asText("thinking"));

                if (isAnalyzingIntent) {
                    sanitizeActionCommand(response, cmdNode);
                } else {
                    response.setActionCommand(null);
                    response.setActionParams(null);
                }

                // If it's a valid action but textReply is empty, use a default acknowledgment
                if (response.getActionCommand() != null && response.getTextReply().isEmpty()) {
                    response.setTextReply("Đã rõ, tôi đang thực hiện lệnh của bạn...");
                }

                return response;
            } catch (Exception e) {
                log.warn("Failed to parse extracted JSON: {}. Falling back to raw text.", e.getMessage());
            }
        }

        // Fallback for natural language responses
        response.setTextReply(rawText);
        response.setEmotion("thinking");
        return response;
    }

    private String extractJson(String text) {
        if (text == null) return null;
        
        // 1. Try to find the outermost { ... } block
        int start = text.indexOf("{");
        int end = text.lastIndexOf("}");
        
        if (start != -1 && end != -1 && start < end) {
            String candidate = text.substring(start, end + 1);
            // Quick sanity check: simple check if it even looks like JSON
            if (candidate.contains(":") && (candidate.contains("\"textReply\"") || candidate.contains("\"actionCommand\""))) {
                return candidate;
            }
        }
        
        // 2. Fallback to trimmed direct match
        String trimmed = text.trim();
        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            return trimmed;
        }
        
        return null;
    }
}
