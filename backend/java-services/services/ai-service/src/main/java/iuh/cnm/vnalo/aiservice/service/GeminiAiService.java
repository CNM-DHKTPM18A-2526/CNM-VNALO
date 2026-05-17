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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
        "SEND_MESSAGE",
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

        // 4. Generate stable, deterministic conversation ID per user
        String stableConvId = java.util.UUID.nameUUIDFromBytes(("AI_ASSISTANT_" + userId).getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString();
        if (responseObj != null) {
            responseObj.setConversationId(stableConvId);
        }

        // 5. Save Chat History asynchronously-like to Core Service
        try {
            List<Map<String, String>> messagesToSave = new ArrayList<>();
            Map<String, String> userMsg = new HashMap<>();
            userMsg.put("role", "user");
            userMsg.put("content", request.getPrompt());
            messagesToSave.add(userMsg);

            Map<String, String> assistantMsg = new HashMap<>();
            assistantMsg.put("role", "assistant");
            assistantMsg.put("content", answer);
            assistantMsg.put("provider", provider);
            messagesToSave.add(assistantMsg);

            coreServiceClient.saveChatHistory(userId, stableConvId, messagesToSave);
        } catch (Exception e) {
            log.warn("Failed to persist chat history from GeminiAiService to core-service: {}", e.getMessage());
        }

        return responseObj;
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
    }

    private AiChatResponse parseFallbackResponse(String rawText, boolean isAnalyzingIntent) throws Exception {
        AiChatResponse response = new AiChatResponse();
        String cleanJson = extractJson(rawText);

        if (cleanJson != null) {
            try {
                JsonNode cmdNode = objectMapper.readTree(cleanJson);
                response.setTextReply(cmdNode.path("textReply").asText(""));
                response.setEmotion(cmdNode.path("emotion").asText("thinking"));

                sanitizeActionCommand(response, cmdNode);

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

                sanitizeActionCommand(response, cmdNode);

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
