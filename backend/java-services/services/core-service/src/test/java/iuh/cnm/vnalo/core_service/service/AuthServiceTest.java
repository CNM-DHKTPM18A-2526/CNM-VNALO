package iuh.cnm.vnalo.core_service.service;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.dto.request.LoginRequest;
import iuh.cnm.vnalo.core_service.model.dto.request.RegisterRequest;
import iuh.cnm.vnalo.core_service.model.dto.response.AuthResponse;
import iuh.cnm.vnalo.core_service.model.entity.auth.AuthAccount;
import iuh.cnm.vnalo.core_service.model.entity.user.UserPrivacySetting;
import iuh.cnm.vnalo.core_service.model.entity.user.UserProfile;
import iuh.cnm.vnalo.core_service.model.enums.AccountStatus;
import iuh.cnm.vnalo.core_service.repository.auth.AuthAccountRepository;
import iuh.cnm.vnalo.core_service.repository.auth.AuthLegalConsentRepository;
import iuh.cnm.vnalo.core_service.repository.auth.RefreshTokenRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserPrivacySettingRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserProfileRepository;
import iuh.cnm.vnalo.core_service.repository.user.UserSettingRepository;
import iuh.cnm.vnalo.core_service.security.JwtTokenProvider;
import iuh.cnm.vnalo.core_service.security.UserPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("AuthService Unit Tests")
class AuthServiceTest {

    @Mock
    private AuthAccountRepository authAccountRepository;

    @Mock
    private AuthLegalConsentRepository authLegalConsentRepository;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private UserProfileRepository userProfileRepository;

    @Mock
    private UserPrivacySettingRepository userPrivacySettingRepository;

    @Mock
    private UserSettingRepository userSettingRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    @Mock
    private OtpService otpService;

    @Mock
    private SessionAuditService sessionAuditService;

    @Mock
    private HttpServletRequest httpRequest;

    @InjectMocks
    private AuthService authService;

    private AuthAccount testAccount;
    private UserProfile testProfile;
    private UUID testAccountId;

    @BeforeEach
    void setUp() {
        testAccountId = UUID.randomUUID();
        
        testAccount = AuthAccount.builder()
                .phone("+84912345678")
            .email("test@example.com")
                .passwordHash("hashedPassword")
                .status(AccountStatus.ACTIVE)
                .build();
        testAccount.setId(testAccountId);

        testProfile = UserProfile.builder()
                .displayName("Test User")
                .build();
        testProfile.setId(testAccountId);
    }

    @Nested
    @DisplayName("Register Tests")
    class RegisterTests {

        @Test
        @DisplayName("Should register successfully with required email")
        void shouldRegisterSuccessfully_WithEmail() {
            // Given
            RegisterRequest request = RegisterRequest.builder()
                    .phone("+84912345678")
                .email("test@example.com")
                    .otp("123456")
                    .password("password123")
                    .displayName("Test User")
                    .acceptedTerms(true)
                    .acceptedPrivacy(true)
                    .build();
            
            when(authAccountRepository.existsByPhone(anyString())).thenReturn(false);
            when(authAccountRepository.existsByEmailIgnoreCase(anyString())).thenReturn(false);
            when(passwordEncoder.encode(anyString())).thenReturn("hashedPassword");
            when(authAccountRepository.save(any(AuthAccount.class))).thenReturn(testAccount);
            when(userProfileRepository.save(any(UserProfile.class))).thenReturn(testProfile);
            when(userPrivacySettingRepository.save(any(UserPrivacySetting.class))).thenReturn(UserPrivacySetting.createDefault(testAccountId));
            when(userSettingRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
            when(jwtTokenProvider.generateAccessToken(any(UserPrincipal.class), anyMap())).thenReturn("accessToken");
            when(jwtTokenProvider.generateRefreshToken()).thenReturn("refreshToken");
            when(jwtTokenProvider.getRefreshTokenExpiration()).thenReturn(604800000L);
            when(jwtTokenProvider.getAccessTokenExpirationSeconds()).thenReturn(86400L);

            // When
            AuthResponse response = authService.register(request, httpRequest);

            // Then
            assertNotNull(response);
            assertEquals("accessToken", response.getAccessToken());
            assertNotNull(response.getRefreshToken());
            verify(otpService).verifyOtp("test@example.com", "123456", iuh.cnm.vnalo.core_service.model.enums.OtpPurpose.REGISTER);
            verify(authAccountRepository).save(any(AuthAccount.class));
            verify(userProfileRepository).save(any(UserProfile.class));
            verify(userPrivacySettingRepository).save(any(UserPrivacySetting.class));
            verify(authLegalConsentRepository).saveAll(any());
        }

        @Test
        @DisplayName("Should reject register when consent is missing")
        void shouldRejectRegisterWhenConsentMissing() {
            RegisterRequest request = RegisterRequest.builder()
                    .phone("+84912345678")
                    .email("test@example.com")
                    .otp("123456")
                    .password("password123")
                    .displayName("Test User")
                    .acceptedTerms(false)
                    .acceptedPrivacy(true)
                    .build();

            ApiException exception = assertThrows(ApiException.class,
                    () -> authService.register(request, httpRequest));

            assertEquals(ErrorCode.VALIDATION_ERROR, exception.getErrorCode());
            verify(otpService, never()).verifyOtp(anyString(), anyString(), any());
            verify(authLegalConsentRepository, never()).saveAll(any());
        }

        @Test
        @DisplayName("Should throw exception when phone already exists")
        void shouldThrowException_WhenPhoneExists() {
            // Given
            RegisterRequest request = RegisterRequest.builder()
                    .phone("+84912345678")
                    .email("test@example.com")
                    .otp("123456")
                    .password("password123")
                    .displayName("Test User")
                    .acceptedTerms(true)
                    .acceptedPrivacy(true)
                    .build();
            
            when(authAccountRepository.existsByPhone(anyString())).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class, 
                () -> authService.register(request, httpRequest));
            
            assertEquals(ErrorCode.AUTH_PHONE_ALREADY_EXISTS, exception.getErrorCode());
            verify(otpService, never()).verifyOtp(anyString(), anyString(), any());
            verify(authAccountRepository, never()).save(any());
        }

        @Test
        @DisplayName("Should throw exception when email already exists")
        void shouldThrowException_WhenEmailExists() {
            // Given
            RegisterRequest request = RegisterRequest.builder()
                    .phone("+84912345678")
                    .email("test@example.com")
                    .otp("123456")
                    .password("password123")
                    .displayName("Test User")
                    .acceptedTerms(true)
                    .acceptedPrivacy(true)
                    .build();
            
            when(authAccountRepository.existsByPhone(anyString())).thenReturn(false);
            when(authAccountRepository.existsByEmailIgnoreCase(anyString())).thenReturn(true);

            // When & Then
            ApiException exception = assertThrows(ApiException.class, 
                () -> authService.register(request, httpRequest));
            
            assertEquals(ErrorCode.AUTH_EMAIL_ALREADY_EXISTS, exception.getErrorCode());
            verify(otpService, never()).verifyOtp(anyString(), anyString(), any());
        }
    }

    @Nested
    @DisplayName("Login Tests")
    class LoginTests {

        @Test
        @DisplayName("Should login successfully with valid credentials")
        void shouldLoginSuccessfully_WithValidCredentials() {
            // Given
            LoginRequest request = LoginRequest.builder()
                    .identifier("+84912345678")
                    .password("password123")
                    .platform("ANDROID")
                    .deviceId("android-device-1")
                    .build();

            when(authAccountRepository.findByPhone("+84912345678")).thenReturn(Optional.of(testAccount));
            when(passwordEncoder.matches("password123", "hashedPassword")).thenReturn(true);
            when(userProfileRepository.findById(testAccountId)).thenReturn(Optional.of(testProfile));
            when(authAccountRepository.save(any(AuthAccount.class))).thenReturn(testAccount);
            when(userSettingRepository.findById(testAccountId)).thenReturn(Optional.empty());
            when(jwtTokenProvider.generateAccessToken(any(UserPrincipal.class), anyMap())).thenReturn("accessToken");
            when(jwtTokenProvider.generateRefreshToken()).thenReturn("refreshToken");
            when(jwtTokenProvider.getRefreshTokenExpiration()).thenReturn(604800000L);
            when(jwtTokenProvider.getAccessTokenExpirationSeconds()).thenReturn(86400L);

            // When
            AuthResponse response = authService.login(request, httpRequest);

            // Then
            assertNotNull(response);
            assertEquals("accessToken", response.getAccessToken());
            assertNotNull(response.getUser());
            verify(authAccountRepository).save(any(AuthAccount.class)); // onLoginSuccess
        }

        @Test
        @DisplayName("Should throw exception with invalid credentials")
        void shouldThrowException_WithInvalidCredentials() {
            // Given
            LoginRequest request = LoginRequest.builder()
                    .identifier("+84912345678")
                    .password("wrongPassword")
                    .build();

            when(authAccountRepository.findByPhone("+84912345678")).thenReturn(Optional.of(testAccount));
            when(passwordEncoder.matches("wrongPassword", "hashedPassword")).thenReturn(false);
            when(authAccountRepository.save(any(AuthAccount.class))).thenReturn(testAccount);

            // When & Then
            ApiException exception = assertThrows(ApiException.class, 
                () -> authService.login(request, httpRequest));
            
            assertEquals(ErrorCode.AUTH_INVALID_CREDENTIALS, exception.getErrorCode());
            verify(authAccountRepository).save(any(AuthAccount.class)); // saves failed login count
        }
    }

    @Nested
    @DisplayName("Logout Tests")
    class LogoutTests {

        @Test
        @DisplayName("Should logout successfully")
        void shouldLogoutSuccessfully() {
            // Given
            String refreshToken = "validRefreshToken";

            // When
            authService.logout(refreshToken);

            // Then
            verify(refreshTokenRepository).revokeByTokenHash(anyString(), any(Instant.class));
        }

        @Test
        @DisplayName("Should handle null refresh token gracefully")
        void shouldHandleNullRefreshToken() {
            // When
            authService.logout(null);

            // Then
            verify(refreshTokenRepository, never()).revokeByTokenHash(anyString(), any(Instant.class));
        }

        @Test
        @DisplayName("Should logout from all devices")
        void shouldLogoutFromAllDevices() {
            // When
            authService.logoutAll(testAccountId);

            // Then
            verify(refreshTokenRepository).revokeAllByAccountId(eq(testAccountId), any(Instant.class));
        }
    }
}
