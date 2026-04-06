package iuh.cnm.vnalo.analytics_service.config;

import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

@ConfigurationProperties(prefix = "analytics.cache")
@Getter
@Setter
@Validated
public class AnalyticsCacheProperties {
    private boolean enabled = true;

    private Duration overviewTtl = Duration.ofMinutes(5);

    private Duration dashboardTtl = Duration.ofMinutes(3);

    @Min(100)
    private long maximumSize = 10_000;
}
