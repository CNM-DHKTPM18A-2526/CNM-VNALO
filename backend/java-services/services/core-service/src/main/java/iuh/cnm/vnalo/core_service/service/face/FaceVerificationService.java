package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.face.FaceVerificationLog;
import iuh.cnm.vnalo.core_service.repository.face.FaceVerificationLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Service for face verification and audit logging.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FaceVerificationService {

    private final FaceEnrollmentService faceEnrollmentService;
    private final FaceVerificationLogRepository logRepository;
    private final FaceAuthProperties faceAuthProperties;

    public record VerificationResult(
            boolean verified,
            double confidence,
            double threshold,
            String decision,
            long inferenceTimeMs
    ) {}

    /**
     * Verifies a face by extracting embedding and comparing with stored enrollment.
     */
    @Transactional
    public VerificationResult verifyWithEnrollment(UUID userId, float[] probeEmbedding,
                                                  double livenessScore,
                                                  String ipAddress, String deviceId, String appVersion) {
        long start = System.currentTimeMillis();

        float[] galleryEmbedding = faceEnrollmentService.getAndDecryptEmbedding(userId);
        double similarity = cosineSimilarity(galleryEmbedding, probeEmbedding);
        double threshold = faceAuthProperties.getVerificationThreshold().doubleValue();
        boolean verified = similarity >= threshold;
        long inferenceTime = System.currentTimeMillis() - start;

        FaceVerificationLog auditLog = FaceVerificationLog.builder()
                .userId(userId)
                .verified(verified)
                .confidence(BigDecimal.valueOf(similarity))
                .livenessScore(BigDecimal.valueOf(livenessScore))
                .threshold(BigDecimal.valueOf(threshold))
                .ipAddress(ipAddress)
                .deviceId(deviceId)
                .appVersion(appVersion)
                .inferenceTimeMs((int) inferenceTime)
                .createdAt(Instant.now())
                .build();
        logRepository.save(auditLog);

        log.info("Face verification for userId={}: verified={}, confidence={}, threshold={}, time={}ms",
                userId, verified, String.format("%.4f", similarity),
                String.format("%.2f", threshold), inferenceTime);

        return new VerificationResult(
                verified,
                similarity,
                threshold,
                verified ? "MATCH" : "NO_MATCH",
                inferenceTime
        );
    }

    /**
     * Computes cosine similarity between two vectors.
     * Since embeddings are L2-normalized, dot product equals cosine similarity.
     */
    public double cosineSimilarity(float[] a, float[] b) {
        if (a.length != b.length) {
            throw new ApiException(ErrorCode.FACE_MODEL_ERROR, "Embedding dimension mismatch");
        }
        double dot = 0.0;
        for (int i = 0; i < a.length; i++) {
            dot += a[i] * b[i];
        }
        return Math.max(-1.0, Math.min(1.0, dot));
    }
}
