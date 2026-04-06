package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.config.OtpConfig;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.ChangePasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ForgotPasswordSendOtpRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RefreshTokenRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.ResetPasswordRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.SendOtpRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.OtpResponse;
import iuh.cnm.vnalo.core_service.model.enums.OtpPurpose;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import iuh.cnm.vnalo.core_service.service.AuthService;
import iuh.cnm.vnalo.core_service.service.OtpService;
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
    private final OtpService otpService;
    private final OtpConfig otpConfig;
    private final AuthAccountRepository authAccountRepository;

    /**
     * Send OTP for registration.
     * Call this before /register to get OTP sent to phone.
     */
    @PostMapping("/register/send-otp")
    @Operation(summary = "Send OTP for registration", 
               description = "Send OTP to phone number for registration verification. Skip if OTP is disabled.")
    public ResponseEntity<ApiResponse<OtpResponse>> sendRegistrationOtp(
            @Valid @RequestBody SendOtpRequest request) {
        
        // Check if phone already registered
        if (authAccountRepository.existsByPhone(request.getPhone())) {
            throw new ApiException(ErrorCode.AUTH_PHONE_ALREADY_EXISTS);
        }
        
        // Check if OTP is disabled
        if (otpConfig.shouldSkipOtp()) {
            return ResponseEntity.ok(ApiResponse.success(
                "OTP verification is disabled",
                OtpResponse.skipped("OTP verification is disabled in current environment")
            ));
        }
        
        OtpService.OtpSendResult result = otpService.sendOtp(request.getPhone(), OtpPurpose.REGISTER);
        
        return ResponseEntity.ok(ApiResponse.success(
            result.getMessage(),
            OtpResponse.success(result.getExpiresInSeconds(), otpConfig.getRateLimit().getCooldownSeconds())
        ));
    }

    /**
     * Register a new user account.
     * Requires OTP verification if enabled.
     */
    @PostMapping("/register")
    @Operation(summary = "Register new account", 
               description = "Create a new user account with phone number. Include OTP if verification is enabled.")
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
     * Refresh access token
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
     * Useful for frontend to know if OTP verification is required.
     */
    @GetMapping("/otp/status")
    @Operation(summary = "Check OTP status", description = "Check if OTP verification is enabled")
    public ResponseEntity<ApiResponse<OtpStatusResponse>> getOtpStatus() {
        return ResponseEntity.ok(ApiResponse.success(
            "OTP status retrieved",
            new OtpStatusResponse(
                otpConfig.isEnabled(),
                otpConfig.isTestMode(),
                otpConfig.getExpirationMinutes(),
                otpConfig.getRateLimit().getCooldownSeconds()
            )
        ));
    }
    
    /**
     * Response for OTP status check.
     */
    public record OtpStatusResponse(
        boolean enabled,
        boolean testMode,
        int expirationMinutes,
        int cooldownSeconds
    ) {}

    /**
     * Send OTP for forgot password flow.
     * Always returns generic success message to avoid exposing account existence.
     */
    @PostMapping("/password/forgot/send-otp")
    @Operation(summary = "Send OTP for forgot password",
               description = "Sends OTP for password reset if phone exists. Returns generic success message regardless.")
    public ResponseEntity<ApiResponse<OtpResponse>> sendForgotPasswordOtp(
            @Valid @RequestBody ForgotPasswordSendOtpRequest request) {

        OtpResponse response = authService.sendForgotPasswordOtp(request.getPhone());
        return ResponseEntity.ok(ApiResponse.success("If the phone number exists, OTP has been sent", response));
    }

    /**
     * Reset password by verifying OTP and setting a new password in one step.
     */
    @PostMapping("/password/reset")
    @Operation(summary = "Reset password",
               description = "Verify OTP and reset password using phone number.")
    public ResponseEntity<ApiResponse<Void>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {

        authService.resetPassword(request);
        return ResponseEntity.ok(ApiResponse.success("Password reset successful"));
    }

    /**
     * Change password for authenticated user.
     */
    @PostMapping("/password/change")
    @Operation(summary = "Change password", description = "Change password for authenticated account")
    public ResponseEntity<ApiResponse<Void>> changePassword(
            @AuthenticationPrincipal UserPrincipal currentUser,
            @Valid @RequestBody ChangePasswordRequest request) {

        authService.changePassword(currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.success("Password changed successfully"));
    }
}

