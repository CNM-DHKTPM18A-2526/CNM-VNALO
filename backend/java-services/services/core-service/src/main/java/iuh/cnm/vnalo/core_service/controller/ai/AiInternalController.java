package iuh.cnm.vnalo.core_service.controller.ai;

import iuh.cnm.vnalo.core_service.service.ai.AiHistoryService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/ai/internal")
@RequiredArgsConstructor
public class AiInternalController {

    private final AiHistoryService aiHistoryService;

    @PostMapping("/history")
    public ResponseEntity<Void> saveHistory(@RequestBody SaveHistoryRequest request) {
        if (request == null || request.getMessages() == null || request.getMessages().isEmpty()) {
            return ResponseEntity.ok().build();
        }
        for (MessageEntry entry : request.getMessages()) {
            if (entry == null) {
                continue;
            }
            OffsetDateTime parsedTime = parseCreatedAt(entry.getCreatedAt());
            aiHistoryService.saveMessage(
                    request.getUserId(),
                    request.getConversationId(),
                    entry.getRole(),
                    entry.getContent(),
                    entry.getProvider(),
                    parsedTime,
                    entry.getClientEntryId()
            );
        }
        return ResponseEntity.ok().build();
    }

    private OffsetDateTime parseCreatedAt(String rawCreatedAt) {
        if (rawCreatedAt == null || rawCreatedAt.trim().isEmpty()) {
            return null;
        }
        String value = rawCreatedAt.trim();
        try {
            return OffsetDateTime.parse(value);
        } catch (Exception ignored) {
            try {
                return LocalDateTime.parse(value).atOffset(ZoneOffset.UTC);
            } catch (Exception ignoredAgain) {
                return null;
            }
        }
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
            entry.setClientEntryId(entity.getClientEntryId());
            if (entity.getCreatedAt() != null) {
                entry.setCreatedAt(entity.getCreatedAt().toString());
            }
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
        private String createdAt;
        private String clientEntryId;
    }
}
