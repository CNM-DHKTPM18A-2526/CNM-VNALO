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

import java.io.IOException;
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

    public String uploadFile(MultipartFile file, String objectKey) {
        try {
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
        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .contentType(contentType)
                .build();

        s3Client.putObject(putRequest, RequestBody.fromBytes(content));
        return getFileUrl(objectKey);
    }

    public byte[] downloadFile(String objectKey) {
        return s3Client.getObjectAsBytes(GetObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build()).asByteArray();
    }

    public String generatePresignedUrl(String objectKey, String contentType) {
        PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                .signatureDuration(Duration.ofMinutes(10))
                .putObjectRequest(PutObjectRequest.builder()
                        .bucket(bucketName)
                        .key(objectKey)
                        .contentType(contentType)
                        .build())
                .build();

        return s3Presigner.presignPutObject(presignRequest).url().toString();
    }

    public void deleteFile(String objectKey) {
        s3Client.deleteObject(software.amazon.awssdk.services.s3.model.DeleteObjectRequest.builder()
                .bucket(bucketName)
                .key(objectKey)
                .build());
        log.info("Deleted S3 object: {}", objectKey);
    }

    public String generatePresignedDownloadUrl(String objectKey) {
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
        if (publicEndpoint.endsWith("/")) {
            return publicEndpoint + objectKey;
        }
        return publicEndpoint + "/" + objectKey;
    }

    public String getBucketName() {
        return bucketName;
    }
}
