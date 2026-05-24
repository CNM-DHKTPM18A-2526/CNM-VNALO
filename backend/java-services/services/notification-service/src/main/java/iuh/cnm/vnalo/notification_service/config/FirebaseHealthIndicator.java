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
        if (!firebaseConfig.isInitialized()) {
            return Health.down()
                    .withDetail("reason", "Firebase is not initialized or disabled")
                    .build();
        }

        if (FirebaseApp.getApps().isEmpty()) {
            return Health.down()
                    .withDetail("reason", "No Firebase apps registered")
                    .build();
        }

        return Health.up()
                .withDetail("name", FirebaseApp.getApps().get(0).getName())
                .withDetail("projectId", FirebaseApp.getApps().get(0).getOptions().getProjectId())
                .build();
    }
}
