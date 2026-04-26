package iuh.cnm.vnalo.moderation_service.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import iuh.cnm.vnalo.moderation_service.exception.ErrorCode;
import iuh.cnm.vnalo.moderation_service.model.dto.response.ApiResponse;
import iuh.cnm.vnalo.moderation_service.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.http.HttpMethod;

import java.nio.charset.StandardCharsets;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final UserDetailsService userDetailsService;
    private final ObjectMapper objectMapper;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                    .authenticationEntryPoint((request, response, authException) -> {
                        response.setStatus(HttpStatus.UNAUTHORIZED.value());
                        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
                        response.setContentType("application/json");
                        response.getWriter().write(objectMapper.writeValueAsString(
                            ApiResponse.error(
                                ErrorCode.UNAUTHORIZED.getCode(),
                                "Unauthorized",
                                HttpStatus.UNAUTHORIZED
                            )
                        ));
                    })
                    .accessDeniedHandler((request, response, accessDeniedException) -> {
                        response.setStatus(HttpStatus.FORBIDDEN.value());
                        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
                        response.setContentType("application/json");
                        response.getWriter().write(objectMapper.writeValueAsString(
                            ApiResponse.error(
                                ErrorCode.ACCESS_DENIED.getCode(),
                                "Access denied",
                                HttpStatus.FORBIDDEN
                            )
                        ));
                    })
                )
               .authorizeHttpRequests(auth -> auth
    .requestMatchers(
        "/actuator/health",
        "/api/v1/actuator/health",
        "/swagger-ui/**",
        "/v3/api-docs/**",
        "/api/v1/swagger-ui/**",
        "/api/v1/v3/api-docs/**"
    ).permitAll()

    .requestMatchers(HttpMethod.POST, "/reports").hasAnyRole("USER", "MODERATOR", "ADMIN")
    .requestMatchers(HttpMethod.POST, "/api/v1/reports").hasAnyRole("USER", "MODERATOR", "ADMIN")
    .requestMatchers("/reports/me/**").hasAnyRole("USER", "MODERATOR", "ADMIN")
    .requestMatchers("/api/v1/reports/me/**").hasAnyRole("USER", "MODERATOR", "ADMIN")

    .requestMatchers("/moderation/**").authenticated()
    .requestMatchers("/api/v1/moderation/**").authenticated()
    .requestMatchers("/admin/**").authenticated()
    .requestMatchers("/api/v1/admin/**").authenticated()

    .anyRequest().authenticated()
)
                .authenticationProvider(authenticationProvider())
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    /**
     * Configure DaoAuthenticationProvider with UserDetailsService.
     * This is intentional - we're using custom UserDetailsService for JWT auth.
     */
    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider authProvider = new DaoAuthenticationProvider();
        authProvider.setUserDetailsService(userDetailsService);
        authProvider.setPasswordEncoder(passwordEncoder());
        authProvider.setHideUserNotFoundExceptions(true); // Prevent user enumeration
        return authProvider;
    }

    @Bean
    public org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource() {
        var configuration = new org.springframework.web.cors.CorsConfiguration();
        configuration.setAllowedOriginPatterns(java.util.List.of("*"));
        configuration.setAllowedMethods(java.util.Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(java.util.List.of("*"));
        configuration.setAllowCredentials(true);
        var source = new org.springframework.web.cors.UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}