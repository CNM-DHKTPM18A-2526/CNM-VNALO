package iuh.cnm.vnalo.notification_service.config;

import com.google.firebase.FirebaseApp;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@Component("firebase")
@RequiredArgsConstructor
public class FirebaseHealthIndicator implements HealthIndicator {

    private final FirebaseConfig firebaseConfig;

    @Override
    public Health health() {
        if (!firebaseConfig.isEnabled()) {
            return Health.up()
                    .withDetail("firebase", "disabled")
                    .withDetail("reason", "Firebase is intentionally disabled for this environment")
                    .build();
        }

        if (!firebaseConfig.isInitialized()) {
            return Health.down()
                    .withDetail("firebase", "initialization_failed")
                    .withDetail("reason", "Firebase is enabled but not initialized")
                    .build();
        }

        if (FirebaseApp.getApps().isEmpty()) {
            return Health.down()
                    .withDetail("firebase", "no_registered_apps")
                    .withDetail("reason", "No Firebase apps registered")
                    .build();
        }

        FirebaseApp app = FirebaseApp.getApps().get(0);
        String appName = app.getName() != null ? app.getName() : "DEFAULT";
        String projectId = app.getOptions() != null && app.getOptions().getProjectId() != null
                ? app.getOptions().getProjectId()
                : "unknown";

        return Health.up()
                .withDetail("firebase", "initialized")
                .withDetail("name", appName)
                .withDetail("projectId", projectId)
                .build();
    }
}
