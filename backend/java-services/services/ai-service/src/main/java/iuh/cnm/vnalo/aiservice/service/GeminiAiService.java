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
        // Construct System Instructions for VNALO Mascot if intention analysis is required
        String promptText = request.getPrompt();
        
        if (request.isAnalyzeIntent()) {
            promptText = "System Instruction: You are VNALO, a lively 3D virtual assistant for a social app. " +
                         "If the user asks to start a call, output ONLY a JSON formatted like {\"actionCommand\": \"START_CALL\", \"actionParams\": {\"target\": \"name\"}}. " +
                         "Otherwise, reply naturally. \nUser Input: " + request.getPrompt();
        }

        Map<String, Object> part = new HashMap<>();
        part.put("text", promptText);

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
        if (firstCandidate == null) {
            return AiChatResponse.builder().textReply(fallbackText).build();
        }
        
        JsonNode contentNode = firstCandidate.path("content");
        if (contentNode.isMissingNode()) {
            return AiChatResponse.builder().textReply(fallbackText).build();
        }
        
        JsonNode partsNode = contentNode.path("parts");
        if (partsNode.isMissingNode() || !partsNode.isArray() || partsNode.size() == 0) {
            return AiChatResponse.builder().textReply(fallbackText).build();
        }
        
        JsonNode firstPart = partsNode.get(0);
        if (firstPart == null) {
            return AiChatResponse.builder().textReply(fallbackText).build();
        }
        
        String rawText = firstPart.path("text").asText();

        // 4. Intent parsing - Handle potential Markdown formatting from AI
        AiChatResponse response = new AiChatResponse();
        if (isAnalyzingIntent) {
            String cleanJson = extractJson(rawText);
            if (cleanJson != null) {
                try {
                    JsonNode cmdNode = objectMapper.readTree(cleanJson);
                    if (cmdNode.has("actionCommand")) {
                        response.setActionCommand(cmdNode.get("actionCommand").asText());
                        if (cmdNode.has("actionParams")) {
                            response.setActionParams(objectMapper.convertValue(cmdNode.get("actionParams"), Map.class));
                        }
                        response.setTextReply(""); // Command execution mode
                        return response;
                    }
                } catch (Exception e) {
                    log.warn("Failed to parse extracted JSON: {}", e.getMessage());
                }
            }
        }

        response.setTextReply(rawText);
        return response;
    }

    private String extractJson(String text) {
        if (text == null) return null;
        
        // Try to find JSON within code blocks first
        if (text.contains("```")) {
            int start = text.indexOf("{");
            int end = text.lastIndexOf("}");
            if (start != -1 && end != -1 && start < end) {
                return text.substring(start, end + 1);
            }
        }
        
        String trimmed = text.trim();
        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            return trimmed;
        }
        
        return null;
    }
}
