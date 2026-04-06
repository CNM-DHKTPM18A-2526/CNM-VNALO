package iuh.cnm.vnalo.analytics_service.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "analytics.retention")
@Getter
@Setter
public class AnalyticsRetentionProperties {
    private boolean enabled = true;
    private String cron = "0 30 0 * * *";
    private int eventsDays = 90;
    private int dailyMetricsDays = 730;
    private int backfillJobsDays = 180;
}