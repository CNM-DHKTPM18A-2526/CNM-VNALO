package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.message.SendMessageRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.message.MessageResponse;
import iuh.cnm.vnalo.messagingservice.service.MessageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/messages")
@RequiredArgsConstructor
@Tag(name = "Messages", description = "Core messaging APIs")
public class MessageController {

    private final MessageService messageService;

    @PostMapping
    @Operation(summary = "Send a message")
    public ResponseEntity<ApiResponse<MessageResponse>> sendMessage(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody SendMessageRequest request) {
        MessageResponse response = messageService.sendMessage(currentUserId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(response));
    }

    @GetMapping("/conversations/{conversationId}")
    @Operation(summary = "Get messages in a conversation (Cassandra — Slice pagination)")
    public ResponseEntity<ApiResponse<Slice<MessageResponse>>> getMessages(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                messageService.getMessages(conversationId, currentUserId, pageable)));
    }

    @DeleteMapping("/conversations/{conversationId}/{messageId}")
    @Operation(summary = "Delete (recall) a message")
    public ResponseEntity<ApiResponse<Void>> deleteMessage(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId) {
        messageService.deleteMessage(conversationId, messageId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Message deleted successfully"));
    }
}
