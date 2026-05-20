package iuh.cnm.vnalo.aiservice.controller;

import iuh.cnm.vnalo.aiservice.dto.request.AiChatRequest;
import iuh.cnm.vnalo.aiservice.dto.request.AiHistoryBackupRequest;
import iuh.cnm.vnalo.aiservice.dto.response.AiChatResponse;
import iuh.cnm.vnalo.aiservice.service.ChatService;
import iuh.cnm.vnalo.aiservice.service.GeminiAiService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import iuh.cnm.vnalo.aiservice.dto.ApiResponse;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("")
@RequiredArgsConstructor
public class AiInteractionController {

    private final GeminiAiService geminiAiService;
    private final ChatService chatService;

    private String getCurrentUserId() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @PostMapping("/chat")
    public ResponseEntity<?> interactWithMascot(@Valid @RequestBody AiChatRequest request) {
        log.info("Received AI Command for mascot {}. Analyze intent: {}, Deep summary: {}", 
                request.getMascotId(), request.isAnalyzeIntent(), request.isEnableDeepSummary());
        
        try {
            String userId = getCurrentUserId();
            AiChatResponse response = geminiAiService.interactWithGemini(userId, request);
            return ResponseEntity.ok(ApiResponse.ok(response));
            
        } catch (iuh.cnm.vnalo.aiservice.exception.RateLimitExceededException e) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(ApiResponse.error(429, e.getMessage()));
        } catch (RuntimeException e) {
            log.error("AI Interaction error: ", e);
            return ResponseEntity.ok(ApiResponse.ok(buildEmergencyFallbackResponse(request)));
        }
    }

    @PostMapping("/history/backup")
    public ResponseEntity<?> backupHistory(@Valid @RequestBody AiHistoryBackupRequest request) {
        String userId = getCurrentUserId();
        log.info("Received history backup request for user: {}, conversation: {}. Entry count: {}", 
                userId, request.getConversationId(), request.getEntries().size());
        
        try {
            chatService.backupHistory(userId, request.getConversationId(), request.getEntries());
            return ResponseEntity.ok(ApiResponse.ok("History synced successfully", null));
        } catch (Exception e) {
            log.error("History backup failed: ", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Failed to backup history: " + e.getMessage()));
        }
    }

    @GetMapping("/history")
    public ResponseEntity<?> getHistory(@RequestParam String conversationId) {
        String userId = getCurrentUserId();
        log.info("Received request to restore history for user: {}, conversation: {}", userId, conversationId);
        try {
            java.util.List<iuh.cnm.vnalo.aiservice.dto.Message> history = chatService.getHistory(userId, conversationId);
            return ResponseEntity.ok(ApiResponse.ok(history));
        } catch (Exception e) {
            log.error("Failed to retrieve history: ", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Failed to restore history: " + e.getMessage()));
        }
    }

    @DeleteMapping("/history")
    public ResponseEntity<?> deleteHistory(@RequestParam String conversationId) {
        String userId = getCurrentUserId();
        if (conversationId == null || conversationId.isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error(400, "conversationId is required"));
        }
        log.info("Received request to delete AI history for user: {}, conversation: {}", userId, conversationId);
        try {
            chatService.deleteHistory(userId, conversationId);
            return ResponseEntity.ok(ApiResponse.ok("History deleted successfully", null));
        } catch (Exception e) {
            log.error("Failed to delete AI history: ", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.error(500, "Failed to delete history: " + e.getMessage()));
        }
    }

    private AiChatResponse buildEmergencyFallbackResponse(AiChatRequest request) {
        AiChatResponse fallback = AiChatResponse.builder()
                .textReply("Xin loi, he thong AI dang ban. Ban vui long thu lai sau it phut.")
                .emotion("neutral")
                .estimatedTokens(0)
                .build();

        if (!request.isAnalyzeIntent()) {
            return fallback;
        }

        String prompt = request.getPrompt() == null ? "" : request.getPrompt().toLowerCase(Locale.ROOT);
        if (looksLikeCallIntent(prompt)) {
            Map<String, Object> params = new HashMap<>();
            params.put("callType", isVideoCallIntent(prompt) ? "video" : "voice");

            fallback.setActionCommand("START_CALL");
            fallback.setActionParams(params);
            fallback.setTextReply("AI dang gap su co, nhung minh van co the bat dau cuoc goi cho ban.");
        }

        return fallback;
    }

    private boolean looksLikeCallIntent(String prompt) {
        if (prompt.isBlank()) {
            return false;
        }

        return prompt.contains("goi")
                || prompt.contains("call")
                || prompt.contains("phone")
                || prompt.contains("dien thoai");
    }

    private boolean isVideoCallIntent(String prompt) {
        return prompt.contains("video")
                || prompt.contains("camera")
                || prompt.contains("hinh")
                || prompt.contains("cam");
    }
}
