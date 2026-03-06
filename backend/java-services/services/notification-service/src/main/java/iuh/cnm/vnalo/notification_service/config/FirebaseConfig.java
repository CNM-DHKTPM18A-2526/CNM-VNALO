package iuh.cnm.vnalo.notification_service.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.util.List;

@Slf4j
@Configuration
public class FirebaseConfig {

    @Value("${firebase.credentials.path}")
    private String credentialsPath;

    @PostConstruct
    public void init() {
        try {
            // Nếu đã init rồi thì thôi
            List<FirebaseApp> apps = FirebaseApp.getApps();
            if (apps != null && !apps.isEmpty()) {
                log.info("Firebase already initialized: {}", apps.get(0).getName());
                return;
            }

            Resource resource = new ClassPathResource(credentialsPath);
            try (InputStream is = resource.getInputStream()) {
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(is))
                        .build();
                FirebaseApp.initializeApp(options);
                log.info("Firebase initialized successfully (DEFAULT).");
            }
        } catch (Exception e) {
            // Dev có thể cho phép chạy mà không push (tuỳ bạn)
            log.error("Firebase init failed: {}", e.getMessage(), e);
            // Nếu muốn FAIL HARD thì throw:
            // throw new IllegalStateException("Firebase init failed", e);
        }
    }
}