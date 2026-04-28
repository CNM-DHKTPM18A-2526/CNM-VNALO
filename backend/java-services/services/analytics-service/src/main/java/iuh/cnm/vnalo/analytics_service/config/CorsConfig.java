package iuh.cnm.vnalo.analytics_service.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig {

    @Bean("customCorsConfigurationSource")
    public CorsConfigurationSource corsConfigurationSource() {
        String allowedOriginsStr = System.getenv("CORS_ALLOWED_ORIGINS");
        if (allowedOriginsStr == null || allowedOriginsStr.isBlank()) {
            allowedOriginsStr = "http://localhost:3000,http://localhost:5173";
        }
        List<String> allowedOrigins = Arrays.stream(allowedOriginsStr.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isBlank())
                .toList();

        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(allowedOrigins);
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("*"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
