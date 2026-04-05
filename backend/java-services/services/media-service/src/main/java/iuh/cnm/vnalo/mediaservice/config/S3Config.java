package iuh.cnm.vnalo.mediaservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import lombok.extern.slf4j.Slf4j;
import software.amazon.awssdk.auth.credentials.AnonymousCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

import java.net.URI;

@Configuration
@Slf4j
public class S3Config {

    @Value("${application.s3.endpoint}")
    private String endpoint;

    @Value("${application.s3.access-key}")
    private String accessKey;

    @Value("${application.s3.secret-key}")
    private String secretKey;

    @Value("${application.s3.region}")
    private String region;

    @Bean
    public S3Client s3Client() {
        var builder = S3Client.builder()
            .region(Region.of(region))
            .credentialsProvider(resolveCredentialsProvider());

        if (endpoint != null && !endpoint.isEmpty()) {
            builder.endpointOverride(URI.create(endpoint));
            builder.serviceConfiguration(S3Configuration.builder()
                    .pathStyleAccessEnabled(true)
                    .build());
        }

        return builder.build();
    }

    @Bean
    public software.amazon.awssdk.services.s3.presigner.S3Presigner s3Presigner() {
        var builder = software.amazon.awssdk.services.s3.presigner.S3Presigner.builder()
            .region(Region.of(region))
            .credentialsProvider(resolveCredentialsProvider());

        if (endpoint != null && !endpoint.isEmpty()) {
            builder.endpointOverride(URI.create(endpoint));
        }

        return builder.build();
    }

    private AwsCredentialsProvider resolveCredentialsProvider() {
        if (hasAwsCredentials()) {
            String normalizedAccessKey = normalize(accessKey);
            String normalizedSecretKey = normalize(secretKey);
            try {
                return StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(normalizedAccessKey, normalizedSecretKey)
                );
            } catch (RuntimeException ex) {
                log.warn("Invalid AWS credentials format detected; falling back to anonymous/local mode: {}", ex.getMessage());
            }
        }
        return AnonymousCredentialsProvider.create();
    }

    private boolean hasAwsCredentials() {
        String normalizedAccessKey = normalize(accessKey);
        String normalizedSecretKey = normalize(secretKey);
        if (normalizedAccessKey.startsWith("${") || normalizedSecretKey.startsWith("${")) {
            return false;
        }
        return !normalizedAccessKey.isEmpty() && !normalizedSecretKey.isEmpty();
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim();
    }
}
