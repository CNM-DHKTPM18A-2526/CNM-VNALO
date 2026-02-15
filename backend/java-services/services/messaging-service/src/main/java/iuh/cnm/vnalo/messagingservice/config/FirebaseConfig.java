package iuh.cnm.vnalo.messagingservice.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Firebase configuration for push notifications via FCM.
 *
 * Place your Firebase service account JSON file at one of:
 * 1. classpath: src/main/resources/firebase-service-account.json
 * 2. External path: set FIREBASE_CONFIG_PATH environment variable
 *
 * Download credentials from: Firebase Console → Project Settings → Service Accounts → Generate New Private Key
 */
@Configuration
@Slf4j
public class FirebaseConfig {

    @Value("${firebase.config-path:#{null}}")
    private String configPath;

    @PostConstruct
    public void initialize() {
        if (FirebaseApp.getApps().isEmpty()) {
            try {
                InputStream serviceAccount = getServiceAccountStream();
                if (serviceAccount == null) {
                    log.warn("Firebase service account not found. FCM push notifications are DISABLED. " +
                            "Set 'firebase.config-path' or place 'firebase-service-account.json' in resources/");
                    return;
                }

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);
                log.info("Firebase initialized successfully — FCM push notifications are ENABLED");
            } catch (IOException e) {
                log.error("Failed to initialize Firebase: {}", e.getMessage());
            }
        }
    }

    private InputStream getServiceAccountStream() {
        // 1. Try external path from config
        if (configPath != null && !configPath.isBlank()) {
            try {
                return new FileInputStream(configPath);
            } catch (IOException e) {
                log.warn("Firebase config file not found at: {}", configPath);
            }
        }

        // 2. Try classpath resource
        try {
            ClassPathResource resource = new ClassPathResource("firebase-service-account.json");
            if (resource.exists()) {
                return resource.getInputStream();
            }
        } catch (IOException e) {
            log.debug("Firebase classpath resource not available");
        }

        return null;
    }
}
