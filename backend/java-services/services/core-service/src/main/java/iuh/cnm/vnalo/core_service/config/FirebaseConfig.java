package iuh.cnm.vnalo.core_service.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.util.StringUtils;

import java.io.InputStream;

@Configuration
@Slf4j
public class FirebaseConfig {

    @Value("${firebase.enabled:false}")
    private boolean firebaseEnabled;

    @Value("${firebase.fail-fast:false}")
    private boolean firebaseFailFast;

    @Value("${firebase.credentials.path:}")
    private String firebaseCredentialsPath;

    private final ResourceLoader resourceLoader;

    public FirebaseConfig(ResourceLoader resourceLoader) {
        this.resourceLoader = resourceLoader;
    }

    public boolean isEnabled() {
        return firebaseEnabled;
    }

    // Initialize Firebase Admin SDK before the application starts
    @PostConstruct
    public void init() {
        if (!firebaseEnabled) {
            log.info("Firebase initialization skipped (firebase.enabled=false)");
            return;
        }

        if (!StringUtils.hasText(firebaseCredentialsPath)) {
            String message = "Firebase credentials path is empty. Set FIREBASE_CREDENTIALS_PATH.";
            handleInitFailure(message, null);
            return;
        }

        try {
            // Check if Firebase Admin SDK is already initialized
            if (FirebaseApp.getApps().isEmpty()) {
                Resource resource = resolveCredentialResource(firebaseCredentialsPath);
                if (!resource.exists()) {
                    handleInitFailure(
                            "Firebase credential file not found: " + firebaseCredentialsPath,
                            null
                    );
                    return;
                }

                // Load the service account credentials from configured resource
                InputStream serviceAccount = resource.getInputStream();

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);

                log.info("Firebase Admin SDK initialized successfully");
            }
        } catch (Exception e) {
            handleInitFailure("Failed to initialize Firebase Admin SDK", e);
        }
    }

    private Resource resolveCredentialResource(String path) {
        if (path.startsWith("classpath:") || path.startsWith("file:")) {
            return resourceLoader.getResource(path);
        }
        return resourceLoader.getResource("file:" + path);
    }

    private void handleInitFailure(String message, Exception e) {
        if (firebaseFailFast) {
            if (e != null) {
                throw new RuntimeException(message, e);
            }
            throw new RuntimeException(message);
        }

        if (e != null) {
            log.warn("{} (continuing without Firebase)", message, e);
        } else {
            log.warn("{} (continuing without Firebase)", message);
        }
    }
}
