package iuh.cnm.vnalo.core_service.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "app.admin.monitoring")
public record AdminMonitoringProperties(
        List<String> bootstrapEmails
) {
    public AdminMonitoringProperties {
        bootstrapEmails = bootstrapEmails == null ? List.of() : bootstrapEmails;
    }
}