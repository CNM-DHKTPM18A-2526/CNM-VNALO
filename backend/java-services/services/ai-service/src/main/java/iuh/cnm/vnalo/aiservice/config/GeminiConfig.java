package iuh.cnm.vnalo.aiservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

@Configuration
public class GeminiConfig {

    @Value("${ai.gemini.api-key}")
    private String geminiApiKey;

    @Bean
    public RestTemplate geminiRestTemplate(RestTemplateBuilder builder) {
        // Create an interceptor to auto-inject the API key into the headers for EVERY request
        ClientHttpRequestInterceptor apiKeyInterceptor = (request, body, execution) -> {
            request.getHeaders().add("x-goog-api-key", geminiApiKey);
            request.getHeaders().add("Content-Type", "application/json");
            return execution.execute(request, body);
        };

        return builder
                .setConnectTimeout(Duration.ofSeconds(10))
                .setReadTimeout(Duration.ofSeconds(30)) // Gemini can take time to think on complex video summaries
                .interceptors(apiKeyInterceptor)
                .build();
    }
}
