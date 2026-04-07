package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.QrLoginService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth/qr")
@RequiredArgsConstructor
@Tag(name = "Authentication QR", description = "QR login flow between web and mobile")
public class AuthQrController {

    private final QrLoginService qrLoginService;

    @PostMapping("/sessions")
    @Operation(summary = "Create QR login session", description = "Create a 60-second QR login session for web")
    public ResponseEntity<ApiResponse<QrLoginService.SessionCreateResponse>> createSession(
            @RequestBody(required = false) QrLoginService.SessionCreateRequest request,
            HttpServletRequest httpRequest) {

        final QrLoginService.SessionCreateRequest safe = request == null
                ? new QrLoginService.SessionCreateRequest(null, null, null)
                : request;

        final var result = qrLoginService.createSession(httpRequest, safe);
        return ResponseEntity.ok(ApiResponse.success("QR login session created", result));
    }

    @GetMapping("/sessions/{token}")
    @Operation(summary = "Poll QR login session", description = "Poll QR login session status and return auth payload when approved")
    public ResponseEntity<ApiResponse<QrLoginService.SessionPollResponse>> pollSession(
            @PathVariable String token,
            HttpServletRequest request) {

        final var result = qrLoginService.pollSession(token, request);
        return ResponseEntity.ok(ApiResponse.success("QR login session status", result));
    }

    @GetMapping("/sessions/{token}/preview")
    @Operation(summary = "Preview QR login session", description = "Fetch pending QR login metadata for mobile approval screen")
    public ResponseEntity<ApiResponse<QrLoginService.SessionPreviewResponse>> previewSession(@PathVariable String token) {
        final var result = qrLoginService.getSessionPreview(token);
        return ResponseEntity.ok(ApiResponse.success("QR login session preview", result));
    }

    @PostMapping("/sessions/{token}/approve")
    @Operation(summary = "Approve QR login session", description = "Approve web login from authenticated mobile account")
    public ResponseEntity<ApiResponse<QrLoginService.SessionApproveResponse>> approveSession(
            @PathVariable String token,
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestBody(required = false) QrLoginService.SessionApproveRequest request,
            HttpServletRequest httpRequest) {

        if (currentUser == null) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }

        final QrLoginService.SessionApproveRequest safe = request == null
                ? new QrLoginService.SessionApproveRequest(null, null, null, null)
                : request;

        final var result = qrLoginService.approveSession(token, currentUser.getId(), httpRequest, safe);
        return ResponseEntity.ok(ApiResponse.success("QR login approved", result));
    }
}
