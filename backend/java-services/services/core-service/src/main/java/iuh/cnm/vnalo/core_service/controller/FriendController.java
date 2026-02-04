package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.request.FriendRequestDto;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.FriendRequestResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.FriendResponse;
import iuh.cnm.vnalo.core_service.model.entity.social.FriendRequest;
import iuh.cnm.vnalo.core_service.model.entity.social.Friendship;
import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.FriendService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/friends")
@RequiredArgsConstructor
@Tag(name = "Friends", description = "Friend management")
public class FriendController {

    private final FriendService friendService;

    @PostMapping("/requests")
    @Operation(summary = "Send friend request")
    public ResponseEntity<ApiResponse<FriendRequestResponse>> sendFriendRequest(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody FriendRequestDto request) {

        FriendRequest result = friendService.sendFriendRequest(
                currentUser.getId(), request.getToUserId(), request.getMessage(), FriendshipSource.SEARCH);

        FriendRequestResponse response = FriendRequestResponse.builder()
                .id(result.getRequestId())
                .fromUserId(result.getUserIdFrom())
                .toUserId(result.getUserIdTo())
                .message(result.getMessage())
                .status(result.getStatus())
                .createdAt(result.getCreatedAt())
                .build();

        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success("Friend request sent", response));
    }

    @GetMapping("/requests/incoming")
    @Operation(summary = "Get incoming friend requests")
    public ResponseEntity<ApiResponse<Page<FriendRequestResponse>>> getIncomingRequests(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<FriendRequestResponse> response = friendService.getPendingRequests(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/requests/sent")
    @Operation(summary = "Get sent friend requests")
    public ResponseEntity<ApiResponse<Page<FriendRequestResponse>>> getSentRequests(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<FriendRequestResponse> response = friendService.getSentRequests(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/requests/{requestId}/accept")
    @Operation(summary = "Accept friend request")
    public ResponseEntity<ApiResponse<FriendResponse>> acceptFriendRequest(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID requestId) {

        Friendship friendship = friendService.acceptFriendRequest(requestId, currentUser.getId());
        FriendResponse response = FriendResponse.builder()
                .friendshipId(friendship.getFriendshipId())
                .friendId(friendship.getFriendId(currentUser.getId()))
                .source(friendship.getSource())
                .friendsSince(friendship.getCreatedAt())
                .build();
        return ResponseEntity.ok(ApiResponse.success("Friend request accepted", response));
    }

    @PostMapping("/requests/{requestId}/decline")
    @Operation(summary = "Decline friend request")
    public ResponseEntity<ApiResponse<Void>> declineFriendRequest(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID requestId) {

        friendService.declineFriendRequest(requestId, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Friend request declined"));
    }

    @DeleteMapping("/requests/{requestId}")
    @Operation(summary = "Cancel friend request")
    public ResponseEntity<ApiResponse<Void>> cancelFriendRequest(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID requestId) {

        friendService.cancelFriendRequest(requestId, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Friend request canceled"));
    }

    @GetMapping
    @Operation(summary = "Get friends list")
    public ResponseEntity<ApiResponse<Page<FriendResponse>>> getFriends(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<FriendResponse> response = friendService.getFriends(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @DeleteMapping("/{friendId}")
    @Operation(summary = "Unfriend")
    public ResponseEntity<ApiResponse<Void>> unfriend(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID friendId) {

        friendService.unfriend(currentUser.getId(), friendId);
        return ResponseEntity.ok(ApiResponse.success("Friend removed"));
    }

    @GetMapping("/{userId}/status")
    @Operation(summary = "Check friendship status")
    public ResponseEntity<ApiResponse<FriendshipStatusResponse>> checkFriendshipStatus(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID userId) {

        boolean areFriends = friendService.areFriends(currentUser.getId(), userId);
        return ResponseEntity.ok(ApiResponse.success(new FriendshipStatusResponse(areFriends)));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get friend stats")
    public ResponseEntity<ApiResponse<FriendStatsResponse>> getFriendStats(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        long friendCount = friendService.countFriends(currentUser.getId());
        long pendingCount = friendService.countPendingRequests(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(new FriendStatsResponse(friendCount, pendingCount)));
    }

    public record FriendshipStatusResponse(boolean areFriends) {}
    public record FriendStatsResponse(long friendCount, long pendingRequestCount) {}
}
