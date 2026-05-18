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
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(ApiResponse.error(503, "VNALO Brain is restarting."));
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
}
