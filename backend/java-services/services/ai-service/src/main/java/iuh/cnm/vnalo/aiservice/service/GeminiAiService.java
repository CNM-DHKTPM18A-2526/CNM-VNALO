package iuh.cnm.vnalo.aiservice.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class GeminiAiService {

    private final RestTemplate geminiRestTemplate;
    private final ObjectMapper objectMapper;

    @Value("${ai.gemini.model:gemini-1.5-flash}")
    private String modelName;

    // Direct REST formulation to bypass volatile SDK version constraints
    private static final String GEMINI_REST_URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent";

    public AiChatResponse interactWithGemini(AiChatRequest request) {
        String url = String.format(GEMINI_REST_URL, modelName);

        // 1. Build Payload specifically structured for Gemini 1.5 Flash Standard
        Map<String, Object> payload = buildGeminiPayload(request);

        try {
            // 2. Call Google GenAI
            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload);
            ResponseEntity<String> response = geminiRestTemplate.exchange(url, HttpMethod.POST, entity, String.class);

            // 3. Parse Response
            return parseGeminiResponse(response.getBody(), request.isAnalyzeIntent());

        } catch (HttpClientErrorException.TooManyRequests e) {
            log.error("Gemini API Rate Limit Exceeded");
            throw new RuntimeException("QUOTA_EXCEEDED");
        } catch (Exception e) {
            log.error("Error communicating with Gemini: {}", e.getMessage());
            throw new RuntimeException("AI_SERVICE_ERROR");
        }
    }

    private Map<String, Object> buildGeminiPayload(AiChatRequest request) {
        StringBuilder promptBuilder = new StringBuilder();
        
        // 1. Inject Unified System Instruction first
        promptBuilder.append("SYSTEM INSTRUCTION:\n")
                     .append(iuh.cnm.vnalo.aiservice.knowledge.SystemPrompt.VNALO_SYSTEM_PROMPT)
                     .append("\n---\n");
        
        // 2. Add context if any (Reserved for future RAG/History expansion)
        
        // 3. Current User Input
        promptBuilder.append("USER INPUT: ").append(request.getPrompt());

        Map<String, Object> part = new HashMap<>();
        part.put("text", promptBuilder.toString());

        Map<String, Object> content = new HashMap<>();
        content.put("parts", List.of(part));

        Map<String, Object> payload = new HashMap<>();
        payload.put("contents", List.of(content));

        return payload;
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
                response.setActionCommand(cmdNode.path("actionCommand").asText(null));
                response.setEmotion(cmdNode.path("emotion").asText("thinking"));
                
                if (cmdNode.has("actionParams")) {
                    response.setActionParams(objectMapper.convertValue(cmdNode.get("actionParams"), Map.class));
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
