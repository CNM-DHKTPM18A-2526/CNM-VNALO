package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.config.OtpConfig;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.ChangePasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ForgotPasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RefreshTokenRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ResetPasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.SendOtpRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.OtpResponse;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.AuthService;
import iuh.cnm.vnalo.core_service.service.SessionAuditService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * REST Controller for authentication endpoints.
 */
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "Authentication endpoints (login, register, OTP, refresh token)")
public class AuthController {

    private final AuthService authService;
    private final SessionAuditService sessionAuditService;
    private final OtpConfig otpConfig;

    /**
     * Send OTP for registration.
     */
    @PostMapping("/register/send-otp")
    @Operation(summary = "Send OTP for registration",
               description = "Send registration OTP to email")
    public ResponseEntity<ApiResponse<OtpResponse>> sendRegistrationOtp(
            @Valid @RequestBody SendOtpRequest request) {

        final String normalizedEmail = request.getEmail().trim().toLowerCase();
        if (authService.isPhoneRegistered(request.getPhone())) {
            throw new ApiException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS);
        }
        if (authService.isEmailRegistered(normalizedEmail)) {
            throw new ApiException(ErrorCode.AUTH_EMAIL_ALREADY_EXISTS);
        }

        var result = authService.sendRegistrationOtp(normalizedEmail);
        return ResponseEntity.ok(ApiResponse.success(
            "Registration OTP sent",
            result.isSkipped()
                ? OtpResponse.skipped(result.getMessage())
                : OtpResponse.success(result.getExpiresInSeconds(), otpConfig.getRateLimit().getCooldownSeconds())
        ));
    }

    /**
     * Register a new user account.
     */
    @PostMapping("/register")
    @Operation(summary = "Register new account",
               description = "Create a new user account with phone + email")
    public ResponseEntity<ApiResponse<AuthResponse>> register(
            @Valid @RequestBody RegisterRequest request,
            HttpServletRequest httpRequest) {

        AuthResponse response = authService.register(request, httpRequest);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success("Registration successful", response));
    }

    /**
     * User login.
     */
    @PostMapping("/login")
    @Operation(summary = "Login", description = "Authenticate with phone/email and password")
    public ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest) {

        AuthResponse response = authService.login(request, httpRequest);
        return ResponseEntity.ok(ApiResponse.success("Login successful", response));
    }

    /**
     * Refresh access token.
     */
    @PostMapping("/refresh")
    @Operation(summary = "Refresh token", description = "Get new access token using refresh token")
    public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(
            @Valid @RequestBody RefreshTokenRequest request,
            HttpServletRequest httpRequest) {

        AuthResponse response = authService.refreshToken(request, httpRequest);
        return ResponseEntity.ok(ApiResponse.success("Token refreshed", response));
    }

    /**
     * User logout.
     */
    @PostMapping("/logout")
    @Operation(summary = "Logout", description = "Revoke current refresh token")
    public ResponseEntity<ApiResponse<Void>> logout(
            @RequestBody(required = false) RefreshTokenRequest request) {

        String refreshToken = request != null ? request.getRefreshToken() : null;
        authService.logout(refreshToken);

        return ResponseEntity.ok(ApiResponse.success("Logout successful"));
    }

    /**
     * Logout from all devices.
     */
    @PostMapping("/logout-all")
    @Operation(summary = "Logout from all devices", description = "Revoke all refresh tokens")
    public ResponseEntity<ApiResponse<Void>> logoutAll(
            @AuthenticationPrincipal UserPrincipal currentUser) {

        authService.logoutAll(currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success("Logged out from all devices"));
    }

    @GetMapping("/login-devices")
    @Operation(summary = "Login device history", description = "Get recent login devices for current account")
    public ResponseEntity<ApiResponse<java.util.List<AuthService.LoginDeviceInfo>>> getLoginDevices(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam(defaultValue = "20") int limit) {

        final var devices = authService.getLoginDevices(currentUser.getId(), limit);
        return ResponseEntity.ok(ApiResponse.success("Login devices retrieved", devices));
    }

    @GetMapping("/session-audit")
    @Operation(summary = "Session transition audit trail", description = "Get recent session transition events for current account")
    public ResponseEntity<ApiResponse<java.util.List<iuh.cnm.vnalo.core_service.model.dto.response.SessionAuditResponse>>> getSessionAudit(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @RequestParam(defaultValue = "50") int limit) {

        final var audits = sessionAuditService.getAudits(currentUser.getId(), limit);
        return ResponseEntity.ok(ApiResponse.success("Session audits retrieved", audits));
    }

    /**
     * Check OTP configuration status.
     */
    @GetMapping("/otp/status")
    @Operation(summary = "Check OTP status", description = "Check OTP behavior by flow")
    public ResponseEntity<ApiResponse<OtpStatusResponse>> getOtpStatus() {
        return ResponseEntity.ok(ApiResponse.success(
            "OTP status retrieved",
            new OtpStatusResponse(
                false,
                otpConfig.isTestMode(),
                otpConfig.getExpirationMinutes(),
                otpConfig.getRateLimit().getCooldownSeconds(),
                otpConfig.isEnabled(),
                false,
                otpConfig.isEnabled()
            )
        ));
    }

    /**
     * Change password for authenticated user.
     */
    @PostMapping({"/change-password", "/password/change"})
    @Operation(summary = "Change password", description = "Change password for authenticated user")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody ChangePasswordRequest request) {

        authService.changePassword(currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Password changed successfully"));
    }

    /**
     * Request password reset OTP by email.
     */
    @PostMapping({"/forgot-password", "/password/forgot/send-otp"})
    @Operation(summary = "Forgot password", description = "Send password reset OTP to email")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request) {

        authService.forgotPassword(request);
        return ResponseEntity.ok(ApiResponse.success("Password reset OTP sent"));
    }

    /**
     * Reset password using email OTP verification.
     */
    @PostMapping({"/reset-password", "/password/reset"})
    @Operation(summary = "Reset password", description = "Reset password with email OTP verification")
    public ResponseEntity<ApiResponse<Void>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {

        authService.resetPassword(request);
        return ResponseEntity.ok(ApiResponse.success("Password reset successfully"));
    }

    @GetMapping("/check-phone/{phone}")
    public ResponseEntity<Map<String, Boolean>> checkPhone(@PathVariable String phone) {
        boolean registered = authService.isPhoneRegistered(phone);
        return ResponseEntity.ok(Map.of("registered", registered));
    }

    @PostMapping("/register/verify-otp")
    public ResponseEntity<Void> verifyOtp(@RequestBody Map<String, String> body) {
        authService.verifyRegistrationOtp(body.get("email"), body.get("otp"));
        return ResponseEntity.ok().build();
    }

    /**
     * Face login — caller must first call /face/verify to get verified=true with a userId.
     * This endpoint creates a session for the verified userId.
     */
    @PostMapping("/face-login")
    @Operation(summary = "Face login", description = "Create session after face verification succeeded")
    public ResponseEntity<ApiResponse<AuthResponse>> faceLogin(
            @Valid @RequestBody FaceLoginRequest request,
            HttpServletRequest httpRequest) {

        AuthResponse response = authService.faceLogin(
                UUID.fromString(request.getUserId()),
                httpRequest,
                request.getDeviceId(),
                request.getDeviceName(),
                request.getPlatform()
        );
        return ResponseEntity.ok(ApiResponse.success("Face login successful", response));
    }

    /**
     * Lookup a user account by phone number or email, returning the userId.
     * Used by the face login flow to resolve an identifier to a UUID.
     */
    @GetMapping("/lookup")
    @Operation(summary = "Lookup user by identifier", description = "Resolve phone or email to userId for face login")
    public ResponseEntity<ApiResponse<Map<String, String>>> lookupByIdentifier(
            @RequestParam("identifier") String identifier) {

        UUID userId = authService.resolveAccountToUserId(identifier);
        return ResponseEntity.ok(ApiResponse.success(
                "User found",
                Map.of("userId", userId.toString())
        ));
    }

    /**
     * Response for OTP status check.
     */
    public record OtpStatusResponse(
        boolean enabled,
        boolean testMode,
        int expirationMinutes,
        int cooldownSeconds,
        boolean passwordResetOtpEnabled,
        boolean registerPhoneOtpEnabled,
        boolean registerEmailOtpEnabled
    ) {}
}
