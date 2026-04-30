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
