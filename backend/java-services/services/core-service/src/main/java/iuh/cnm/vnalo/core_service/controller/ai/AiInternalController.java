package iuh.cnm.vnalo.core_service.controller.ai;

import iuh.cnm.vnalo.core_service.service.ai.AiHistoryService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ai/internal")
@RequiredArgsConstructor
public class AiInternalController {

    private final AiHistoryService aiHistoryService;

    @PostMapping("/history")
    public ResponseEntity<Void> saveHistory(@RequestBody SaveHistoryRequest request) {
        for (MessageEntry entry : request.getMessages()) {
            aiHistoryService.saveMessage(
                    request.getUserId(),
                    request.getConversationId(),
                    entry.getRole(),
                    entry.getContent(),
                    entry.getProvider()
            );
        }
        return ResponseEntity.ok().build();
    }

    @GetMapping("/history")
    public ResponseEntity<java.util.List<MessageEntry>> getHistory(@RequestParam UUID userId, @RequestParam UUID conversationId) {
        java.util.List<iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory> dbHistory = aiHistoryService.getHistory(userId, conversationId);
        java.util.List<MessageEntry> response = new java.util.ArrayList<>();
        // Reverse order so that oldest messages come first (chronological order)
        for (int i = dbHistory.size() - 1; i >= 0; i--) {
            iuh.cnm.vnalo.core_service.model.entity.ai.AiChatHistory entity = dbHistory.get(i);
            MessageEntry entry = new MessageEntry();
            entry.setRole(entity.getRole());
            entry.setContent(entity.getContent());
            entry.setProvider(entity.getProvider());
            response.add(entry);
        }
        return ResponseEntity.ok(response);
    }

    @Data
    public static class SaveHistoryRequest {
        private UUID userId;
        private UUID conversationId;
        private java.util.List<MessageEntry> messages;
    }

    @Data
    public static class MessageEntry {
        private String role;
        private String content;
        private String provider;
    }
}
