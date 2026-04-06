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
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * REST Controller for authentication endpoints.
 */
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "Authentication endpoints (login, register, OTP, refresh token)")
public class AuthController {

    private final AuthService authService;
    private final OtpConfig otpConfig;
    private final AuthAccountRepository authAccountRepository;

    /**
     * Send OTP for registration.
     * Kept for backward compatibility; registration no longer requires phone OTP.
     */
    @PostMapping("/register/send-otp")
    @Operation(summary = "Send OTP for registration",
               description = "Registration phone OTP is disabled; returns skipped response")
    public ResponseEntity<ApiResponse<OtpResponse>> sendRegistrationOtp(
            @Valid @RequestBody SendOtpRequest request) {

        if (authAccountRepository.existsByPhone(request.getPhone())) {
            throw new ApiException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS);
        }

        return ResponseEntity.ok(ApiResponse.success(
            "Phone OTP for registration is disabled",
            OtpResponse.skipped("Registration no longer requires phone OTP")
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
                false
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

    /**
     * Response for OTP status check.
     */
    public record OtpStatusResponse(
        boolean enabled,
        boolean testMode,
        int expirationMinutes,
        int cooldownSeconds,
        boolean passwordResetOtpEnabled,
        boolean registerPhoneOtpEnabled
    ) {}
}
