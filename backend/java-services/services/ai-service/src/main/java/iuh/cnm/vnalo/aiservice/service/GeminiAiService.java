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
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
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
    private final GeminiKeyManager keyManager;

    @Value("${ai.gemini.model:gemini-1.5-flash}")
    private String modelName;

    private static final java.util.Set<String> ALLOWED_COMMANDS = java.util.Set.of(
        "OPEN_CHAT",
        "COMPOSE_MESSAGE",
        "START_CALL",
        "RECALL_MESSAGE",
        "CREATE_GROUP",
        "MUTE_CONVERSATION",
        "UNMUTE_CONVERSATION",
        "PIN_MESSAGE",
        "UNPIN_MESSAGE",
        "OPEN_GROUP_SETTINGS",
        "OPEN_PROFILE",
        "SEND_FRIEND_REQUEST",
        "BLOCK_USER",
        "UNBLOCK_USER",
        "CHANGE_GROUP_NAME",
        "ADD_GROUP_MEMBER",
        "REMOVE_GROUP_MEMBER",
        "TRANSFER_GROUP_OWNER",
        "LEAVE_GROUP",
        "DISBAND_GROUP",
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

            // Call Gemini with key rotation when quota/rate-limit is hit.
            ResponseEntity<String> response = exchangeGeminiWithRotation(url, payload);
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
            responseObj.setProviderStatus(resolveProviderStatus(provider));
            responseObj.setDegraded(!"gemini".equals(provider));
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

    private ResponseEntity<String> exchangeGeminiWithRotation(String url, Map<String, Object> payload) {
        if (!keyManager.hasKeys()) {
            throw new RuntimeException("GEMINI_NOT_CONFIGURED");
        }

        RuntimeException lastError = null;
        int attempts = Math.max(1, keyManager.keyCount());
        for (int attempt = 0; attempt < attempts; attempt++) {
            String activeKey = keyManager.currentKey();
            try {
                HttpHeaders headers = new HttpHeaders();
                headers.setContentType(MediaType.APPLICATION_JSON);
                headers.set("x-goog-api-key", activeKey);
                HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);
                return geminiRestTemplate.exchange(url, HttpMethod.POST, entity, String.class);
            } catch (RuntimeException e) {
                lastError = e;
                if (keyManager.isQuotaOrRateLimitError(e) && attempt < attempts - 1) {
                    keyManager.rotateAfterFailure(activeKey);
                    continue;
                }
                throw e;
            }
        }

        throw lastError != null ? lastError : new RuntimeException("GEMINI_ERROR");
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
            sb.append("\n\nLÃ†Â¯U ÃƒÂ: NgÃ†Â°Ã¡Â»Âi dÃƒÂ¹ng Ã„â€˜ÃƒÂ£ yÃƒÂªu cÃ¡ÂºÂ§u phÃ¡ÂºÂ£n hÃ¡Â»â€œi sÃƒÂ¢u (Deep Summary). HÃƒÂ£y phÃƒÂ¢n tÃƒÂ­ch kÃ¡Â»Â¹ vÃƒÂ  trÃ¡ÂºÂ£ lÃ¡Â»Âi chi tiÃ¡ÂºÂ¿t hÃ†Â¡n bÃƒÂ¬nh thÃ†Â°Ã¡Â»Âng.");
        }
        if (mascot != null) {
            sb.append("\n\n[DYNAMICS SETTINGS]");
            sb.append("\n- TÃƒÂªn cÃ¡Â»Â§a bÃ¡ÂºÂ¡n hiÃ¡Â»â€¡n tÃ¡ÂºÂ¡i lÃƒÂ : ").append(mascot.getMascotName());
            sb.append("\n- CÃƒÂ¡ tÃƒÂ­nh cÃ¡Â»Â§a bÃ¡ÂºÂ¡n: ").append(mascot.getPersonalityType());
            if (mascot.getCustomInstructions() != null && !mascot.getCustomInstructions().isBlank()) {
                sb.append("\n- ChÃ¡Â»â€° dÃ¡ÂºÂ«n Ã„â€˜Ã¡ÂºÂ·c biÃ¡Â»â€¡t tÃ¡Â»Â« ngÃ†Â°Ã¡Â»Âi dÃƒÂ¹ng: ").append(mascot.getCustomInstructions());
            }
        }
        return sb.toString();
    }

    private Map<String, Object> buildGeminiPayload(AiChatRequest request, String systemPrompt) {
        List<Map<String, Object>> contents = new ArrayList<>();

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
        payload.put("systemInstruction", createContent("user", systemPrompt));

        return payload;
    }

    private String resolveProviderStatus(String provider) {
        return "gemini".equalsIgnoreCase(provider)
                ? "LIVE_PROVIDER_ACTIVE"
                : "FALLBACK_PROVIDER_ACTIVE";
    }

    private void sanitizeActionCommand(AiChatResponse response, JsonNode cmdNode) {
        String actionCommand = cmdNode.path("actionCommand").asText(null);
        if (actionCommand == null || actionCommand.isBlank()) {
            actionCommand = cmdNode.path("action").asText(null);
        }
        if (actionCommand == null || actionCommand.isBlank()) {
            actionCommand = cmdNode.path("command").asText(null);
        }
        if (actionCommand != null) {
            actionCommand = normalizeActionAlias(actionCommand.toUpperCase().trim());
            if (ALLOWED_COMMANDS.contains(actionCommand)) {
                response.setActionCommand(actionCommand);
            } else {
                log.warn("Blocked untrusted/unsupported LLM actionCommand: {}", actionCommand);
                blockActionCommand(response, actionCommand);
            }
        }

        JsonNode rawParamsNode = cmdNode.has("actionParams")
                ? cmdNode.get("actionParams")
                : cmdNode.has("params")
                ? cmdNode.get("params")
                : cmdNode.get("parameters");

        if (response.getActionCommand() != null && rawParamsNode != null && !rawParamsNode.isMissingNode()) {
            try {
                Map<String, Object> params = objectMapper.convertValue(rawParamsNode, Map.class);
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
                    } else if (entry.getValue() instanceof List<?>) {
                        List<String> values = extractStringList(entry.getValue());
                        if (!values.isEmpty()) {
                            cleanParams.put(entry.getKey(), values);
                        }
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
            } else if ("CREATE_GROUP".equals(cmd)) {
                String groupName = firstNonBlank(cp, "groupName", "title", "name");
                List<String> memberNames = extractStringList(cp.get("memberNames"));
                if (memberNames.isEmpty()) {
                    memberNames = extractStringList(cp.get("members"));
                }
                if (groupName == null || groupName.isBlank() || memberNames.isEmpty()) {
                    valid = false;
                } else {
                    cp.put("groupName", groupName.trim());
                    cp.put("memberNames", memberNames);
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
            } else if (Arrays.asList("OPEN_PROFILE", "SEND_FRIEND_REQUEST", "BLOCK_USER", "UNBLOCK_USER").contains(cmd)) {
                String target = firstNonBlank(cp, "target", "recipient", "contactName", "displayName", "name");
                if (target == null || target.isBlank()) {
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
            } else if ("CHANGE_GROUP_NAME".equals(cmd)) {
                String title = firstNonBlank(cp, "title", "groupName", "name");
                if (title == null || title.isBlank()) {
                    valid = false;
                } else {
                    cp.put("title", title.trim());
                }
            } else if (Arrays.asList("ADD_GROUP_MEMBER", "REMOVE_GROUP_MEMBER", "TRANSFER_GROUP_OWNER").contains(cmd)) {
                List<String> memberNames = extractStringList(cp.get("memberNames"));
                if (memberNames.isEmpty()) {
                    memberNames = extractStringList(cp.get("members"));
                }
                if (memberNames.isEmpty()) {
                    valid = false;
                } else {
                    cp.put("memberNames", memberNames);
                }
            }
            if (!valid) {
                log.warn("Blocked action command '{}' due to missing or invalid required schema fields in params: {}", cmd, cp);
                blockActionCommand(response, cmd);
            }
        }
        applyActionExecutionHints(response);
    }

    private void blockActionCommand(AiChatResponse response, String blockedCommand) {
        response.setActionCommand(null);
        response.setActionParams(null);
        response.setRequiresConfirmation(false);
        response.setRiskLevel("low");
        response.setTextReply(safeBlockedActionReply(blockedCommand, response.getTextReply()));
    }

    private String safeBlockedActionReply(String blockedCommand, String currentReply) {
        String command = blockedCommand == null ? "" : normalizeActionAlias(blockedCommand.trim().toUpperCase(Locale.ROOT));
        String reply = currentReply == null ? "" : currentReply.trim();
        if (!reply.isEmpty() && !containsPrematureSuccessClaim(reply) && !looksLikeActionPromise(reply)) {
            return reply;
        }
        return switch (command) {
            case "COMPOSE_MESSAGE" -> "Minh chua du thong tin nguoi nhan hoac noi dung tin nhan de chuan bi thao tac nay. Ban hay noi ro nguoi nhan va noi dung can gui.";
            case "START_CALL", "OPEN_CHAT" -> "Minh chua xac dinh duoc dung nguoi hoac cuoc tro chuyen can mo. Ban hay noi ro ten trong danh ba hoac chon lai trong VNALO.";
            case "CREATE_GROUP" -> "Minh chua du ten nhom hoac danh sach thanh vien de tao nhom. Ban hay cung cap ro ten nhom va cac thanh vien.";
            case "OPEN_PROFILE", "SEND_FRIEND_REQUEST", "BLOCK_USER", "UNBLOCK_USER" -> "Minh chua xac dinh duoc dung nguoi dung muc tieu. Ban hay noi ro ten hoac thong tin lien he.";
            case "NAVIGATE_TO" -> "Minh chua xac dinh duoc trang can mo trong VNALO. Ban hay noi ro Chat, Danh ba, Cai dat hoac Nhat ky.";
            case "CHANGE_GROUP_NAME" -> "Minh chua du ten nhom moi de chuan bi thao tac doi ten.";
            case "ADD_GROUP_MEMBER", "REMOVE_GROUP_MEMBER", "TRANSFER_GROUP_OWNER" -> "Minh chua xac dinh duoc dung thanh vien can thao tac. Ban hay noi ro ten thanh vien.";
            default -> "Minh chua du thong tin an toan de chuan bi thao tac nay. Ban hay noi ro hon hoac thao tac thu cong trong VNALO.";
        };
    }

    private void applyActionExecutionHints(AiChatResponse response) {
        String command = response.getActionCommand();
        if (command == null || command.isBlank()) {
            response.setRequiresConfirmation(false);
            response.setRiskLevel("low");
            return;
        }

        String normalized = command.trim().toUpperCase();
        boolean requiresConfirmation = switch (normalized) {
            case "COMPOSE_MESSAGE", "START_CALL", "RECALL_MESSAGE", "CREATE_GROUP",
                    "MUTE_CONVERSATION", "UNMUTE_CONVERSATION", "PIN_MESSAGE", "UNPIN_MESSAGE",
                    "SEND_FRIEND_REQUEST", "BLOCK_USER", "UNBLOCK_USER", "CHANGE_GROUP_NAME",
                    "ADD_GROUP_MEMBER", "REMOVE_GROUP_MEMBER", "TRANSFER_GROUP_OWNER",
                    "LEAVE_GROUP", "DISBAND_GROUP" -> true;
            default -> false;
        };

        String riskLevel = switch (normalized) {
            case "BLOCK_USER", "REMOVE_GROUP_MEMBER", "TRANSFER_GROUP_OWNER", "LEAVE_GROUP", "DISBAND_GROUP",
                    "RECALL_MESSAGE" -> "high";
            case "COMPOSE_MESSAGE", "START_CALL", "CREATE_GROUP", "MUTE_CONVERSATION", "UNMUTE_CONVERSATION",
                    "PIN_MESSAGE", "UNPIN_MESSAGE", "SEND_FRIEND_REQUEST", "UNBLOCK_USER", "CHANGE_GROUP_NAME",
                    "ADD_GROUP_MEMBER" -> "medium";
            default -> "low";
        };

        response.setRequiresConfirmation(requiresConfirmation);
        response.setRiskLevel(riskLevel);
        response.setTextReply(safeActionReply(normalized, response.getTextReply(), requiresConfirmation));
    }

    private String safeActionReply(String command, String currentReply, boolean requiresConfirmation) {
        String reply = currentReply == null ? "" : currentReply.trim();
        if (!reply.isEmpty() && !containsPrematureSuccessClaim(reply)) {
            return reply;
        }

        return switch (command) {
            case "COMPOSE_MESSAGE" -> "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n Ã„â€˜Ã¡Â»Æ’ bÃ¡ÂºÂ¡n kiÃ¡Â»Æ’m tra ngÃ†Â°Ã¡Â»Âi nhÃ¡ÂºÂ­n vÃƒÂ  nÃ¡Â»â„¢i dung trÃ†Â°Ã¡Â»â€ºc khi gÃ¡Â»Â­i.";
            case "START_CALL" -> "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n cuÃ¡Â»â„¢c gÃ¡Â»Âi; nÃ¡ÂºÂ¿u khÃƒÂ´ng tÃƒÂ¬m thÃ¡ÂºÂ¥y ngÃ†Â°Ã¡Â»Âi nÃƒÂ y trong danh bÃ¡ÂºÂ¡, Ã¡Â»Â©ng dÃ¡Â»Â¥ng sÃ¡ÂºÂ½ bÃƒÂ¡o ngay trong Ã„â€˜oÃ¡ÂºÂ¡n chat AI.";
            case "OPEN_CHAT" -> "MÃƒÂ¬nh sÃ¡ÂºÂ½ tÃƒÂ¬m vÃƒÂ  mÃ¡Â»Å¸ cuÃ¡Â»â„¢c trÃƒÂ² chuyÃ¡Â»â€¡n phÃƒÂ¹ hÃ¡Â»Â£p trong VNALO.";
            case "CREATE_GROUP" -> "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n Ã„â€˜Ã¡Â»Æ’ bÃ¡ÂºÂ¡n kiÃ¡Â»Æ’m tra tÃƒÂªn nhÃƒÂ³m vÃƒÂ  thÃƒÂ nh viÃƒÂªn trÃ†Â°Ã¡Â»â€ºc khi tÃ¡ÂºÂ¡o.";
            case "RECALL_MESSAGE" -> "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n trÃ†Â°Ã¡Â»â€ºc khi thu hÃ¡Â»â€œi tin nhÃ¡ÂºÂ¯n phÃƒÂ¹ hÃ¡Â»Â£p.";
            case "BLOCK_USER", "UNBLOCK_USER", "REMOVE_GROUP_MEMBER", "TRANSFER_GROUP_OWNER", "LEAVE_GROUP", "DISBAND_GROUP" ->
                    "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n an toÃƒÂ n trÃ†Â°Ã¡Â»â€ºc khi thÃ¡Â»Â±c hiÃ¡Â»â€¡n thao tÃƒÂ¡c nÃƒÂ y.";
            default -> requiresConfirmation
                    ? "MÃƒÂ¬nh sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc xÃƒÂ¡c nhÃ¡ÂºÂ­n trÃ†Â°Ã¡Â»â€ºc khi thÃ¡Â»Â±c hiÃ¡Â»â€¡n thao tÃƒÂ¡c nÃƒÂ y."
                    : "MÃƒÂ¬nh sÃ¡ÂºÂ½ chuÃ¡ÂºÂ©n bÃ¡Â»â€¹ thao tÃƒÂ¡c nÃƒÂ y trong VNALO.";
        };
    }

    private boolean looksLikeActionPromise(String reply) {
        String normalized = reply.toLowerCase(Locale.ROOT);
        return normalized.contains("i will ")
                || normalized.contains("i'll ")
                || normalized.contains("will open")
                || normalized.contains("will send")
                || normalized.contains("will call")
                || normalized.contains("se mo")
                || normalized.contains("se gui")
                || normalized.contains("se goi")
                || normalized.contains("chuan bi");
    }

    private boolean containsPrematureSuccessClaim(String reply) {
        String normalized = reply.toLowerCase(Locale.ROOT);
        return normalized.contains("Ã„â€˜ÃƒÂ£ gÃ¡Â»Â­i")
                || normalized.contains("da gui")
                || normalized.contains("Ã„â€˜ÃƒÂ£ gÃ¡Â»Âi")
                || normalized.contains("da goi")
                || normalized.contains("Ã„â€˜ang gÃ¡Â»Âi")
                || normalized.contains("dang goi")
                || normalized.contains("Ã„â€˜ÃƒÂ£ tÃ¡ÂºÂ¡o")
                || normalized.contains("da tao")
                || normalized.contains("Ã„â€˜ÃƒÂ£ thu hÃ¡Â»â€œi")
                || normalized.contains("da thu hoi")
                || normalized.contains("sent the message")
                || normalized.contains("message sent")
                || normalized.contains("started the call")
                || normalized.contains("call started")
                || normalized.contains("created the group");
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
                    response.setTextReply("MÃƒÂ¬nh Ã„â€˜ÃƒÂ£ hiÃ¡Â»Æ’u yÃƒÂªu cÃ¡ÂºÂ§u vÃƒÂ  sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc phÃƒÂ¹ hÃ¡Â»Â£p trong VNALO.");
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

    private String normalizeActionAlias(String rawAction) {
        return switch (rawAction) {
            case "SEND_MESSAGE" -> "COMPOSE_MESSAGE";
            case "MUTE_CHAT", "MUTE_GROUP", "MUTE_CONVERSATION" -> "MUTE_CONVERSATION";
            case "UNMUTE_CHAT", "UNMUTE_GROUP", "UNMUTE_CONVERSATION" -> "UNMUTE_CONVERSATION";
            case "PIN_LAST_MESSAGE" -> "PIN_MESSAGE";
            case "UNPIN_LAST_MESSAGE" -> "UNPIN_MESSAGE";
            case "OPEN_GROUP_SETTING", "OPEN_GROUP_SETTINGS" -> "OPEN_GROUP_SETTINGS";
            case "OPEN_USER_PROFILE", "OPEN_FRIEND_PROFILE" -> "OPEN_PROFILE";
            case "ADD_FRIEND" -> "SEND_FRIEND_REQUEST";
            case "BLOCK_CONTACT" -> "BLOCK_USER";
            case "UNBLOCK_CONTACT" -> "UNBLOCK_USER";
            case "RENAME_GROUP" -> "CHANGE_GROUP_NAME";
            case "ADD_MEMBER" -> "ADD_GROUP_MEMBER";
            case "REMOVE_MEMBER" -> "REMOVE_GROUP_MEMBER";
            case "TRANSFER_OWNER" -> "TRANSFER_GROUP_OWNER";
            case "DELETE_GROUP" -> "DISBAND_GROUP";
            case "RECALL_LAST_MESSAGE", "UNDO_LAST_MESSAGE" -> "RECALL_MESSAGE";
            default -> rawAction;
        };
    }

    private String firstNonBlank(Map<String, Object> params, String... keys) {
        for (String key : keys) {
            Object value = params.get(key);
            if (value == null) {
                continue;
            }
            String normalized = String.valueOf(value).trim();
            if (!normalized.isEmpty()) {
                return normalized;
            }
        }
        return null;
    }

    private List<String> extractStringList(Object rawValue) {
        if (rawValue instanceof List<?> rawList) {
            return rawList.stream()
                    .map(String::valueOf)
                    .map(String::trim)
                    .filter(item -> !item.isEmpty())
                    .distinct()
                    .toList();
        }
        if (rawValue instanceof String rawString && !rawString.isBlank()) {
            return Arrays.stream(rawString.split(","))
                    .map(String::trim)
                    .filter(item -> !item.isEmpty())
                    .distinct()
                    .toList();
        }
        return List.of();
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
                    response.setTextReply("MÃƒÂ¬nh Ã„â€˜ÃƒÂ£ hiÃ¡Â»Æ’u yÃƒÂªu cÃ¡ÂºÂ§u vÃƒÂ  sÃ¡ÂºÂ½ mÃ¡Â»Å¸ bÃ†Â°Ã¡Â»â€ºc phÃƒÂ¹ hÃ¡Â»Â£p trong VNALO.");
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

        int start = text.indexOf("{");
        while (start >= 0 && start < text.length()) {
            int depth = 0;
            boolean inString = false;
            boolean escaped = false;
            for (int index = start; index < text.length(); index++) {
                char current = text.charAt(index);
                if (escaped) {
                    escaped = false;
                    continue;
                }
                if (current == '\\') {
                    escaped = true;
                    continue;
                }
                if (current == '"') {
                    inString = !inString;
                    continue;
                }
                if (inString) {
                    continue;
                }
                if (current == '{') {
                    depth++;
                } else if (current == '}') {
                    depth--;
                    if (depth == 0) {
                        String candidate = text.substring(start, index + 1);
                        if (looksLikeActionJson(candidate)) {
                            return candidate;
                        }
                        break;
                    }
                }
            }
            start = text.indexOf("{", start + 1);
        }

        String trimmed = text.trim();
        if (trimmed.startsWith("{") && trimmed.endsWith("}") && looksLikeActionJson(trimmed)) {
            return trimmed;
        }

        return null;
    }

    private boolean looksLikeActionJson(String candidate) {
        return candidate.contains(":")
                && (candidate.contains("\"textReply\"")
                || candidate.contains("\"actionCommand\"")
                || candidate.contains("\"action\"")
                || candidate.contains("\"command\""));
    }
}
