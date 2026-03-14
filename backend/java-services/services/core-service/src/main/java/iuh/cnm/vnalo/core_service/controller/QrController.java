package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.enums.FriendshipSource;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.FriendService;
import iuh.cnm.vnalo.core_service.service.QrService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * REST Controller for QR code-based user identification and friend adding.
 * The QR image itself is rendered by the client — this API provides the data payload.
 */
@RestController
@RequestMapping("/qr")
@RequiredArgsConstructor
@Tag(name = "QR Code", description = "QR code generation and scanning for adding friends")
public class QrController {

    private final QrService qrService;
    private final FriendService friendService;

    /**
     * Generate QR payload for the current user.
     * Frontend encodes this JSON payload into a QR image.
     */
    @GetMapping("/generate")
    @Operation(summary = "Generate QR data",
               description = "Generate time-limited QR payload containing user info and verification token")
    public ResponseEntity<ApiResponse<QrService.QrPayload>> generateQr(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        QrService.QrPayload payload = qrService.generateQrPayload(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("QR code generated", payload));
    }

    /**
     * Validate a scanned QR code and return the target user's info.
     * Does NOT automatically send a friend request — the client decides.
     */
    @PostMapping("/scan")
    @Operation(summary = "Scan QR code",
               description = "Validate scanned QR data and return the target user's info")
    public ResponseEntity<ApiResponse<QrService.QrScanResult>> scanQr(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody QrScanRequest request) {

        QrService.QrScanResult result = qrService.scanQr(
                currentUser.getId(), request.userId(), request.token(), request.nonce());

        return ResponseEntity.ok(ApiResponse.success(result.message(), result));
    }

    /**
     * Scan QR and immediately send a friend request in one step.
     */
    @PostMapping("/scan/add-friend")
    @Operation(summary = "Scan QR and add friend",
               description = "Validate QR and send friend request in one step")
    public ResponseEntity<ApiResponse<QrService.QrScanResult>> scanAndAddFriend(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody QrScanRequest request) {

        QrService.QrScanResult result = qrService.scanQr(
                currentUser.getId(), request.userId(), request.token(), request.nonce());

        if (result.valid() && !result.message().contains("Already friends")) {
            try {
                friendService.sendFriendRequest(
                        currentUser.getId(), request.userId(), "Added via QR code", FriendshipSource.QR);
                return ResponseEntity.ok(ApiResponse.success("Friend request sent via QR",
                        new QrService.QrScanResult(true, result.userId(), result.displayName(), "Friend request sent")));
            } catch (Exception e) {
                return ResponseEntity.ok(ApiResponse.success(e.getMessage(), result));
            }
        }

        return ResponseEntity.ok(ApiResponse.success(result.message(), result));
    }

    /**
     * Request body for scanning a QR code.
     */
    public record QrScanRequest(
            @NotNull UUID userId,
            @NotBlank String token,
            @NotBlank String nonce
    ) {}
}
