package iuh.cnm.vnalo.core_service.controller;

import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RefreshTokenRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
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
@Tag(name = "Authentication", description = "Authentication endpoints (login, register, refresh token)")
public class AuthController {

    private final AuthService authService;

    /**
     * Register a new user account.
     */
    @PostMapping("/register")
    @Operation(summary = "Register new account", description = "Create a new user account with phone number")
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
}
