package iuh.cnm.vnalo.mediaservice.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.ObjectCannedACL;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

import java.io.ByteArrayInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Duration;

@Service
@RequiredArgsConstructor
@Slf4j
public class S3Service {

    private final S3Client s3Client;
    private final S3Presigner s3Presigner;

    @Value("${application.s3.bucket}")
    private String bucketName;

    @Value("${application.s3.public-endpoint}")
    private String publicEndpoint;

    @Value("${application.s3.access-key:}")
    private String accessKey;

    @Value("${application.s3.secret-key:}")
    private String secretKey;

    @Value("${application.s3.local-dir:./.media-local}")
    private String localDir;

    public String uploadFile(MultipartFile file, String objectKey) {
        try {
            if (isLocalStorageMode()) {
                try (InputStream inputStream = file.getInputStream()) {
                    writeStreamToLocal(inputStream, objectKey);
                }
                return getFileUrl(objectKey);
            }

            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(objectKey)
                    .contentType(file.getContentType())
                    .build();

            s3Client.putObject(putRequest, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
            return getFileUrl(objectKey);
        } catch (IOException e) {
            log.error("Failed to upload file to S3: {}", objectKey, e);
            throw new RuntimeException("Failed to upload file", e);
        }
    }

    public String uploadBytes(byte[] content, String objectKey, String contentType) {
        if (isLocalStorageMode()) {
            writeBytesToLocal(content, objectKey);
            return getFileUrl(objectKey);
        }

        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .contentType(contentType)
                .build();

        s3Client.putObject(putRequest, RequestBody.fromBytes(content));
        return getFileUrl(objectKey);
    }

    public byte[] downloadFile(String objectKey) {
        if (isLocalStorageMode()) {
            return readBytesFromLocal(objectKey);
        }

        return s3Client.getObjectAsBytes(GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build()).asByteArray();
    }

    public void downloadFileToPath(String objectKey, java.nio.file.Path destination) {
        if (isLocalStorageMode()) {
            try {
                Files.createDirectories(destination.getParent());
                Files.copy(resolveLocalPath(objectKey), destination, StandardCopyOption.REPLACE_EXISTING);
                return;
            } catch (IOException e) {
                throw new RuntimeException("Failed to copy local media file", e);
            }
        }

        s3Client.getObject(GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build(),
                software.amazon.awssdk.core.sync.ResponseTransformer.toFile(destination));
    }

    public void streamToResponse(String objectKey, java.io.OutputStream out) {
        if (isLocalStorageMode()) {
            try (InputStream inputStream = Files.newInputStream(resolveLocalPath(objectKey))) {
                inputStream.transferTo(out);
                return;
            } catch (IOException e) {
                throw new RuntimeException("Failed to stream local media file", e);
            }
        }

        s3Client.getObject(GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build(),
                software.amazon.awssdk.core.sync.ResponseTransformer.toOutputStream(out));
    }

    public String generatePresignedUrl(String objectKey, String contentType) {
        if (isLocalStorageMode()) {
            return getFileUrl(objectKey);
        }

        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(60))
                .putObjectRequest(PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(objectKey)
                        .contentType(contentType)
                        .build())
                .build();

        return s3Presigner.presignPutObject(presignRequest).url().toString();
    }

    public void deleteFile(String objectKey) {
        if (isLocalStorageMode()) {
            try {
                Files.deleteIfExists(resolveLocalPath(objectKey));
                return;
            } catch (IOException e) {
                throw new RuntimeException("Failed to delete local media file", e);
            }
        }

        s3Client.deleteObject(software.amazon.awssdk.services.s3.model.DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build());
        log.info("Deleted S3 object: {}", objectKey);
    }

    public String generatePresignedDownloadUrl(String objectKey) {
        if (isLocalStorageMode()) {
            return getFileUrl(objectKey);
        }

        software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest presignRequest =
                software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest.builder()
                        .signatureDuration(Duration.ofMinutes(60))
                        .getObjectRequest(GetObjectRequest.builder()
                                .bucket(bucketName)
                                .key(objectKey)
                                .build())
                        .build();
        return s3Presigner.presignGetObject(presignRequest).url().toString();
    }

    public String getFileUrl(String objectKey) {
        if (isLocalStorageMode()) {
            return "/api/v1/media/public-file?key=" + objectKey;
        }
        if (publicEndpoint.endsWith("/")) {
            return publicEndpoint + objectKey;
        }
        return publicEndpoint + "/" + objectKey;
    }

    public String getBucketName() {
        return bucketName;
    }

    private boolean isLocalStorageMode() {
        return accessKey == null || accessKey.isBlank() || secretKey == null || secretKey.isBlank();
    }

    private Path resolveLocalPath(String objectKey) {
        return Paths.get(localDir).resolve(objectKey).normalize();
    }

    private void writeStreamToLocal(InputStream inputStream, String objectKey) {
        Path path = resolveLocalPath(objectKey);
        try {
            Files.createDirectories(path.getParent());
            Files.copy(inputStream, path, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException("Failed to write local media file", e);
        }
    }

    private void writeBytesToLocal(byte[] content, String objectKey) {
        writeStreamToLocal(new ByteArrayInputStream(content), objectKey);
    }

    private byte[] readBytesFromLocal(String objectKey) {
        Path path = resolveLocalPath(objectKey);
        try {
            if (!Files.exists(path)) {
                throw new FileNotFoundException("Local media file not found: " + objectKey);
            }
            return Files.readAllBytes(path);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read local media file", e);
        }
    }
}
