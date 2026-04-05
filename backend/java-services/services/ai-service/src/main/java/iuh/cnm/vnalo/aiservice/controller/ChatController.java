package iuh.cnm.vnalo.aiservice.controller;

import iuh.cnm.vnalo.aiservice.dto.ApiResponse;
import iuh.cnm.vnalo.aiservice.dto.AskRequest;
import iuh.cnm.vnalo.aiservice.dto.ChatMessage;
import iuh.cnm.vnalo.aiservice.dto.ChatResponse;
import iuh.cnm.vnalo.aiservice.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    private String getCurrentUserId() {
        return SecurityContextHolder.getContext().getAuthentication().getName();
    }

    @PostMapping("/ask")
    public ResponseEntity<ApiResponse<ChatResponse>> ask(@Valid @RequestBody AskRequest request) {
        String userId = getCurrentUserId();
        ChatResponse response = chatService.ask(userId, request.getMessage(), request.getConversationId());
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getHistory(
            @RequestParam(required = false) String conversationId) {
        String userId = getCurrentUserId();
        
        if (conversationId != null && !conversationId.isBlank()) {
            List<ChatMessage> messages = chatService.getHistory(userId, conversationId);
            return ResponseEntity.ok(ApiResponse.ok(Map.of("conversationId", conversationId, "messages", messages)));
        } else {
            List<String> conversations = chatService.getUserConversations(userId);
            return ResponseEntity.ok(ApiResponse.ok(Map.of("conversations", conversations)));
        }
    }

    @DeleteMapping("/history")
    public ResponseEntity<ApiResponse<Void>> deleteHistory(
            @RequestParam(required = false) String conversationId) {
        String userId = getCurrentUserId();
        chatService.deleteHistory(userId, conversationId);
        
        String message = (conversationId != null && !conversationId.isBlank()) ? 
                "Đã xóa cuộc trò chuyện " + conversationId : "Đã xóa toàn bộ lịch sử chat";
        
        return ResponseEntity.ok(ApiResponse.ok(message, null));
    }
}
