package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.request.UpdateProfileRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.UpdateSyncPolicyRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.SyncPolicyResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.UserInfoResponse;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
@Tag(name = "Users", description = "User profile management")
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    @Operation(summary = "Get current user profile")
    public ResponseEntity<ApiResponse<UserInfoResponse>> getCurrentUser(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        UserInfoResponse response = userService.getCurrentUserProfile(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Get user profile by ID")
    public ResponseEntity<ApiResponse<UserInfoResponse>> getUserById(@PathVariable UUID userId) {
        UserInfoResponse response = userService.getUserProfile(userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PatchMapping("/me")
    @Operation(summary = "Update current user profile")
    public ResponseEntity<ApiResponse<UserInfoResponse>> updateProfile(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody UpdateProfileRequest request) {

        UserInfoResponse response = userService.updateProfile(currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Profile updated", response));
    }

    @GetMapping("/search")
    @Operation(summary = "Search users")
    public ResponseEntity<ApiResponse<Page<UserInfoResponse>>> searchUsers(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam String keyword,
            @PageableDefault(size = 20) Pageable pageable) {

        Page<UserInfoResponse> response = userService.searchUsers(currentUser.getId(), keyword, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/phone/{phoneNumber}")
    @Operation(summary = "Search user by phone (path)", description = "Exact phone lookup respecting user privacy settings")
    public ResponseEntity<ApiResponse<UserInfoResponse>> searchUserByPhone(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @PathVariable String phoneNumber) {

        UserInfoResponse response = userService.searchUserByPhone(currentUser.getId(), phoneNumber);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/search-by-phone")
    @Operation(summary = "Search user by phone (query)", description = "Exact phone lookup via query param — avoids URL encoding issues with + in path")
    public ResponseEntity<ApiResponse<UserInfoResponse>> searchUserByPhoneQuery(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam String phone) {

        UserInfoResponse response = userService.searchUserByPhone(currentUser.getId(), phone);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/me/privacy")
    @Operation(summary = "Get privacy settings")
    public ResponseEntity<ApiResponse<UserPrivacySetting>> getPrivacySettings(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        UserPrivacySetting settings = userService.getPrivacySettings(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(settings));
    }

    @PutMapping("/me/privacy")
    @Operation(summary = "Update privacy settings")
    public ResponseEntity<ApiResponse<UserPrivacySetting>> updatePrivacySettings(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestBody UserPrivacySetting settings) {

        UserPrivacySetting updated = userService.updatePrivacySettings(currentUser.getId(), settings);
        return ResponseEntity.ok(ApiResponse.success("Privacy settings updated", updated));
    }

    @GetMapping("/me/settings/sync")
    @Operation(summary = "Get sync control policy")
    public ResponseEntity<ApiResponse<SyncPolicyResponse>> getSyncPolicy(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        final SyncPolicyResponse policy = userService.getSyncPolicy(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Sync policy retrieved", policy));
    }

    @PutMapping("/me/settings/sync")
    @Operation(summary = "Update sync control policy")
    public ResponseEntity<ApiResponse<SyncPolicyResponse>> updateSyncPolicy(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody UpdateSyncPolicyRequest request) {

        final SyncPolicyResponse policy = userService.updateSyncPolicy(currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Sync policy updated", policy));
    }
}
