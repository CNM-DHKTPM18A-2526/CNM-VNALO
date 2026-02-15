package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.message.AddReactionRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.MessageReaction;
import iuh.cnm.vnalo.messagingservice.model.entity.PinnedMsg;
import iuh.cnm.vnalo.messagingservice.service.MessageMetadataService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/conversations/{conversationId}/messages")
@RequiredArgsConstructor
@Tag(name = "Message Metadata", description = "Message reactions, pins, and receipts")
public class MessageMetadataController {

    private final MessageMetadataService messageMetadataService;

    // --- Reactions ---

    @PostMapping("/reactions")
    @Operation(summary = "Add a reaction to a message")
    public ResponseEntity<ApiResponse<MessageReaction>> addReaction(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @Valid @RequestBody AddReactionRequest request) {
        MessageReaction reaction = messageMetadataService.addReaction(
                conversationId, request.getMessageId(), currentUserId, request.getEmoji());
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(reaction));
    }

    @DeleteMapping("/{messageId}/reactions")
    @Operation(summary = "Remove your reaction from a message")
    public ResponseEntity<ApiResponse<Void>> removeReaction(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId) {
        messageMetadataService.removeReaction(messageId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Reaction removed"));
    }

    @GetMapping("/{messageId}/reactions")
    @Operation(summary = "Get all reactions for a message")
    public ResponseEntity<ApiResponse<List<MessageReaction>>> getReactions(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId) {
        return ResponseEntity.ok(ApiResponse.success(messageMetadataService.getReactions(messageId)));
    }

    // --- Pinned Messages ---
    // --- Pinned Messages ---

    @PostMapping("/{messageId}/pin")
    @Operation(summary = "Pin a message")
    public ResponseEntity<ApiResponse<PinnedMsg>> pinMessage(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId,
            @RequestParam(defaultValue = "0") Long serverSeq) {
        PinnedMsg pinned = messageMetadataService.pinMessage(conversationId, messageId, serverSeq, currentUserId);
        return ResponseEntity.ok(ApiResponse.success(pinned));
    }

    @DeleteMapping("/{messageId}/pin")
    @Operation(summary = "Unpin a message")
    public ResponseEntity<ApiResponse<Void>> unpinMessage(
            @PathVariable UUID conversationId,
            @PathVariable UUID messageId) {
        messageMetadataService.unpinMessage(conversationId, messageId);
        return ResponseEntity.ok(ApiResponse.success("Message unpinned"));
    }

    @GetMapping("/pinned")
    @Operation(summary = "Get all pinned messages in a conversation")
    public ResponseEntity<ApiResponse<List<PinnedMsg>>> getPinnedMessages(
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(messageMetadataService.getPinnedMessages(conversationId)));
    }

    // --- Polls ---

    @PostMapping("/polls")
    @Operation(summary = "Create a new poll")
    public ResponseEntity<ApiResponse<iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse>> createPoll(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @Valid @RequestBody iuh.cnm.vnalo.messagingservice.model.dto.request.message.CreatePollRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(messageMetadataService.createPoll(conversationId, currentUserId, request)));
    }

    @PostMapping("/polls/{pollId}/vote")
    @Operation(summary = "Vote on a poll")
    public ResponseEntity<ApiResponse<Void>> votePoll(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID pollId,
            @Valid @RequestBody iuh.cnm.vnalo.messagingservice.model.dto.request.message.VotePollRequest request) {
        messageMetadataService.vote(pollId, currentUserId, request);
        return ResponseEntity.ok(ApiResponse.success("Vote recorded"));
    }

    @GetMapping("/polls/{pollId}")
    @Operation(summary = "Get poll details and results")
    public ResponseEntity<ApiResponse<iuh.cnm.vnalo.messagingservice.model.dto.response.message.PollResponse>> getPoll(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID pollId) {
        return ResponseEntity.ok(ApiResponse.success(messageMetadataService.getPoll(pollId, currentUserId)));
    }
}
