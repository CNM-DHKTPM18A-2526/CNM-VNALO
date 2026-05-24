package iuh.cnm.vnalo.core_service.config;

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
            return Health.unknown()
                    .withDetail("reason", "Firebase is disabled via configuration")
                    .build();
        }

        if (FirebaseApp.getApps().isEmpty()) {
            return Health.down()
                    .withDetail("reason", "Firebase Admin SDK not initialized")
                    .build();
        }

        return Health.up()
                .withDetail("name", FirebaseApp.getApps().get(0).getName())
                .withDetail("projectId", FirebaseApp.getApps().get(0).getOptions().getProjectId())
                .build();
    }
}
