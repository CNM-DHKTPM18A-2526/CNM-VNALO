package iuh.cnm.vnalo.analytics_service.config;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class AnalyticsObservabilityConfig implements WebMvcConfigurer {
    private final AnalyticsSliMetricsInterceptor analyticsSliMetricsInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(analyticsSliMetricsInterceptor)
                .addPathPatterns("/api/v1/analytics/**");
    }
}