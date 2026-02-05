package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.BlockedUserResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.BlockStatusResponse;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.BlockService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/blocks")
@RequiredArgsConstructor
@Tag(name = "Blocks", description = "Block/Unblock user management")
public class BlockController {

    private final BlockService blockService;

    @PostMapping("/{userId}")
    @Operation(summary = "Block user")
    public ResponseEntity<ApiResponse<Void>> blockUser(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID userId,
            @RequestParam(required = false) Boolean blockMessages,
            @RequestParam(required = false) Boolean blockCalls,
            @RequestParam(required = false) Boolean blockAndHideLogs) {

        blockService.blockUser(currentUser.getId(), userId, blockMessages, blockCalls, blockAndHideLogs);
        return ResponseEntity.ok(ApiResponse.success("User blocked"));
    }

    @DeleteMapping("/{userId}")
    @Operation(summary = "Unblock user")
    public ResponseEntity<ApiResponse<Void>> unblockUser(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID userId) {

        blockService.unblockUser(currentUser.getId(), userId);
        return ResponseEntity.ok(ApiResponse.success("User unblocked"));
    }

    @GetMapping
    @Operation(summary = "Get blocked users")
    public ResponseEntity<ApiResponse<Page<BlockedUserResponse>>> getBlockedUsers(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<BlockedUserResponse> response = blockService.getBlockedUsers(currentUser.getId(), pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/{userId}/status")
    @Operation(summary = "Check block status")
    public ResponseEntity<ApiResponse<BlockStatusResponse>> checkBlockStatus(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable UUID userId) {

        boolean isBlocked = blockService.isBlocked(currentUser.getId(), userId);
        boolean isBlockedBy = blockService.isBlocked(userId, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(new BlockStatusResponse(isBlocked, isBlockedBy)));
    }
}
