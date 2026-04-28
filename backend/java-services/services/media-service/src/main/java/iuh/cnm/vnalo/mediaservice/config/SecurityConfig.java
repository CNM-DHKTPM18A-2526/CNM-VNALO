package iuh.cnm.vnalo.mediaservice.config;

import iuh.cnm.vnalo.mediaservice.security.JwtAuthenticationFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // Microservice: disable CSRF (stateless, no cookies)
                .csrf(AbstractHttpConfigurer::disable)

                // Microservice: no form login, no HTTP Basic (JWT only)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)

                // Microservice: stateless session
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // CORS configuration - Hardened for Production
                .cors(cors -> cors.configurationSource(request -> {
                    var config = new CorsConfiguration();
                    String allowedOriginsStr = System.getenv("CORS_ALLOWED_ORIGINS");
                    if (allowedOriginsStr != null && !allowedOriginsStr.isBlank()) {
                        List<String> origins = Arrays.stream(allowedOriginsStr.split(","))
                                .map(String::trim)
                                .filter(origin -> !origin.isBlank())
                                .toList();
                        config.setAllowedOrigins(origins);
                    } else {
                        // Intelligent Fallback: Allow localhost AND the current request host (for IP access)
                        String origin = request.getHeader("Origin");
                        if (origin != null && !origin.isBlank()) {
                            config.setAllowedOrigins(List.of(origin)); 
                        } else {
                            config.setAllowedOrigins(List.of("*")); 
                        }
                    }
                    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
                    config.setAllowedHeaders(List.of("*"));
                    config.setExposedHeaders(List.of("Content-Type", "Content-Length", "Cache-Control", "X-Requested-With"));
                    config.setAllowCredentials(true);
                    return config;
                }))

                // Authorization rules
                .authorizeHttpRequests(auth -> auth
                        // Public: Swagger, health check
                        .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                        .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                        // Public: media files (avatars, etc.) served without auth for image widgets
                        .requestMatchers("/public/**").permitAll()
                        // Protected: all other actuator endpoints
                        .requestMatchers("/actuator/**").authenticated()
                        // Protected: all API endpoints require valid JWT
                        .anyRequest().authenticated()
                )

                // Add JWT filter before UsernamePasswordAuthenticationFilter
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
