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

@Slf4j
@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AiInteractionController {

    private final GeminiAiService geminiAiService;
    private final ChatService chatService;

    private String getCurrentUserId() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @PostMapping("/chat")
    public ResponseEntity<Object> interactWithMascot(@Valid @RequestBody AiChatRequest request) {
        log.info("Received AI Command for mascot {}. Analyze intent: {}, Deep summary: {}", 
                request.getMascotId(), request.isAnalyzeIntent(), request.isEnableDeepSummary());
        
        try {
            AiChatResponse response = geminiAiService.interactWithGemini(request);
            return ResponseEntity.ok(response);
            
        } catch (RuntimeException e) {
            if ("QUOTA_EXCEEDED".equals(e.getMessage())) {
                return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                        .body("AI Assistant is currently overloaded. Please try again later.");
            }
            log.error("AI Interaction error: ", e);
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body("VNALO Brain is restarting.");
        }
    }

    @PostMapping("/history/backup")
    public ResponseEntity<Object> backupHistory(@Valid @RequestBody AiHistoryBackupRequest request) {
        String userId = getCurrentUserId();
        log.info("Received history backup request for user: {}, conversation: {}. Entry count: {}", 
                userId, request.getConversationId(), request.getEntries().size());
        
        try {
            chatService.backupHistory(userId, request.getConversationId(), request.getEntries());
            return ResponseEntity.ok().body("History synced successfully");
        } catch (Exception e) {
            log.error("History backup failed: ", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Failed to backup history: " + e.getMessage());
        }
    }
}
