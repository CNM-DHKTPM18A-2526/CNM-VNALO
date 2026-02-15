package iuh.cnm.vnalo.messagingservice.controller;

import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.AddMemberRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.BanMemberRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.CreateConversationRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.JoinRequestDTO;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.UpdateConversationRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.request.conversation.UpdateMemberRoleRequest;
import iuh.cnm.vnalo.messagingservice.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationInboxResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationMemberResponse;
import iuh.cnm.vnalo.messagingservice.model.dto.response.conversation.ConversationResponse;
import iuh.cnm.vnalo.messagingservice.model.entity.conversation.GroupBannedMember;
import iuh.cnm.vnalo.messagingservice.model.entity.conversation.GroupJoinRequest;
import iuh.cnm.vnalo.messagingservice.service.ConversationService;
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
@RequestMapping("/conversations")
@RequiredArgsConstructor
@Tag(name = "Conversation", description = "Conversation management APIs")
public class ConversationController {

    private final ConversationService conversationService;

    @PostMapping
    @Operation(summary = "Create a direct or group conversation")
    public ResponseEntity<ApiResponse<ConversationResponse>> createConversation(
            @AuthenticationPrincipal UUID currentUserId,
            @Valid @RequestBody CreateConversationRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(conversationService.createConversation(currentUserId, request)));
    }

    @GetMapping
    @Operation(summary = "Get user's conversation inbox")
    public ResponseEntity<ApiResponse<List<ConversationInboxResponse>>> getConversations(
            @AuthenticationPrincipal UUID currentUserId) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.getConversations(currentUserId)));
    }

    @GetMapping("/{conversationId}")
    @Operation(summary = "Get conversation details")
    public ResponseEntity<ApiResponse<ConversationResponse>> getConversation(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.getConversation(conversationId, currentUserId)));
    }

    @PatchMapping("/{conversationId}")
    @Operation(summary = "Update conversation (Title, Avatar, Settings)")
    public ResponseEntity<ApiResponse<ConversationResponse>> updateConversation(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @Valid @RequestBody UpdateConversationRequest request) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.updateConversation(conversationId, currentUserId, request)));
    }

    @PostMapping("/{conversationId}/leave")
    @Operation(summary = "Leave a conversation")
    public ResponseEntity<ApiResponse<Void>> leaveConversation(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId) {
        conversationService.leaveConversation(conversationId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Left conversation successfully"));
    }

    // --- Member Management ---

    @GetMapping("/{conversationId}/members")
    @Operation(summary = "Get members of a conversation")
    public ResponseEntity<ApiResponse<List<ConversationMemberResponse>>> getMembers(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.getMembers(conversationId, currentUserId)));
    }

    @PostMapping("/{conversationId}/members")
    @Operation(summary = "Add members to a conversation")
    public ResponseEntity<ApiResponse<Void>> addMembers(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @Valid @RequestBody AddMemberRequest request) {
        conversationService.addMembers(conversationId, currentUserId, request.getUserIds());
        return ResponseEntity.ok(ApiResponse.success("Members added successfully"));
    }

    @DeleteMapping("/{conversationId}/members/{userId}")
    @Operation(summary = "Remove a member from conversation (Admin only)")
    public ResponseEntity<ApiResponse<Void>> removeMember(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID userId) {
        conversationService.removeMember(conversationId, currentUserId, userId);
        return ResponseEntity.ok(ApiResponse.success("Member removed successfully"));
    }

    @PutMapping("/{conversationId}/members/{userId}/role")
    @Operation(summary = "Update member role (Promote to Admin/Owner)")
    public ResponseEntity<ApiResponse<Void>> updateMemberRole(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @Valid @RequestBody UpdateMemberRoleRequest request) {
        conversationService.updateMemberRole(conversationId, currentUserId, userId, request.getRole());
        return ResponseEntity.ok(ApiResponse.success("Member role updated successfully"));
    }

    // --- Ban Management ---

    @PostMapping("/{conversationId}/banned-members/{userId}")
    @Operation(summary = "Ban a member from the group (Admin only)")
    public ResponseEntity<ApiResponse<Void>> banMember(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID userId,
            @RequestBody(required = false) BanMemberRequest request) {
        String reason = request != null ? request.getReason() : null;
        var expiresAt = request != null ? request.getExpiresAt() : null;
        conversationService.banMember(conversationId, currentUserId, userId, reason, expiresAt);
        return ResponseEntity.ok(ApiResponse.success("Member banned successfully"));
    }

    @DeleteMapping("/{conversationId}/banned-members/{userId}")
    @Operation(summary = "Unban a member from the group (Admin only)")
    public ResponseEntity<ApiResponse<Void>> unbanMember(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID userId) {
        conversationService.unbanMember(conversationId, currentUserId, userId);
        return ResponseEntity.ok(ApiResponse.success("Member unbanned successfully"));
    }

    @GetMapping("/{conversationId}/banned-members")
    @Operation(summary = "Get list of banned members (Admin only)")
    public ResponseEntity<ApiResponse<List<GroupBannedMember>>> getBannedMembers(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.getBannedMembers(conversationId, currentUserId)));
    }

    // --- Join Request Management ---

    @PostMapping("/{conversationId}/join-requests")
    @Operation(summary = "Request to join a group conversation")
    public ResponseEntity<ApiResponse<GroupJoinRequest>> requestToJoin(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @RequestBody(required = false) JoinRequestDTO request) {
        String message = request != null ? request.getMessage() : null;
        GroupJoinRequest joinRequest = conversationService.requestToJoin(conversationId, currentUserId, message);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(joinRequest));
    }

    @PostMapping("/{conversationId}/join-requests/{requestId}/approve")
    @Operation(summary = "Approve a join request (Admin only)")
    public ResponseEntity<ApiResponse<Void>> approveJoinRequest(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID requestId) {
        conversationService.approveJoinRequest(requestId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Join request approved"));
    }

    @PostMapping("/{conversationId}/join-requests/{requestId}/reject")
    @Operation(summary = "Reject a join request (Admin only)")
    public ResponseEntity<ApiResponse<Void>> rejectJoinRequest(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId,
            @PathVariable UUID requestId) {
        conversationService.rejectJoinRequest(requestId, currentUserId);
        return ResponseEntity.ok(ApiResponse.success("Join request rejected"));
    }

    @GetMapping("/{conversationId}/join-requests")
    @Operation(summary = "Get pending join requests (Admin only)")
    public ResponseEntity<ApiResponse<List<GroupJoinRequest>>> getPendingJoinRequests(
            @AuthenticationPrincipal UUID currentUserId,
            @PathVariable UUID conversationId) {
        return ResponseEntity.ok(ApiResponse.success(conversationService.getPendingJoinRequests(conversationId, currentUserId)));
    }
}

