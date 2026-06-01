package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.face.FaceEnrollment;
import iuh.cnm.vnalo.core_service.repository.face.FaceEnrollmentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for managing face enrollments.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FaceEnrollmentService {

    private final FaceEnrollmentRepository faceEnrollmentRepository;
    private final FaceEncryptionService faceEncryptionService;

    /**
     * Stores or updates a face enrollment for a user.
     * If the user already has an enrollment, it will be updated (version bump).
     */
    @Transactional
    public FaceEnrollment enroll(UUID userId, float[] embedding,
                                double livenessScore, double qualityScore, String deviceInfo) {
        Optional<FaceEnrollment> existing = faceEnrollmentRepository.findByUserId(userId);

        String encrypted = faceEncryptionService.encrypt(embedding);

        FaceEnrollment enrollment;
        if (existing.isPresent()) {
            enrollment = existing.get();
            enrollment.setEmbeddingData(encrypted);
            enrollment.setVersion(enrollment.getVersion() + 1);
            enrollment.setLivenessScore(BigDecimal.valueOf(livenessScore));
            enrollment.setQualityScore(BigDecimal.valueOf(qualityScore));
            enrollment.setDeviceInfo(deviceInfo);
            enrollment.setEnrolledAt(Instant.now());
            enrollment.setIsActive(true);
            log.info("Re-enrolling face for userId={}, new version={}", userId, enrollment.getVersion());
        } else {
            enrollment = FaceEnrollment.builder()
                    .userId(userId)
                    .embeddingData(encrypted)
                    .livenessScore(BigDecimal.valueOf(livenessScore))
                    .qualityScore(BigDecimal.valueOf(qualityScore))
                    .deviceInfo(deviceInfo)
                    .isActive(true)
                    .version(1)
                    .enrolledAt(Instant.now())
                    .build();
            log.info("Enrolling face for userId={}", userId);
        }

        return faceEnrollmentRepository.save(enrollment);
    }

    /**
     * Retrieves the encrypted embedding string for a user.
     */
    @Transactional(readOnly = true)
    public String getEncryptedEmbedding(UUID userId) {
        return faceEnrollmentRepository
                .findByUserIdAndIsActiveTrue(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.FACE_NOT_ENROLLED))
                .getEmbeddingData();
    }

    /**
     * Retrieves and decrypts the embedding for a user.
     */
    @Transactional(readOnly = true)
    public float[] getAndDecryptEmbedding(UUID userId) {
        String encrypted = getEncryptedEmbedding(userId);
        return faceEncryptionService.decrypt(encrypted);
    }

    /**
     * Retrieves the enrollment metadata for a user.
     */
    @Transactional(readOnly = true)
    public Optional<FaceEnrollment> getEnrollment(UUID userId) {
        return faceEnrollmentRepository.findByUserIdAndIsActiveTrue(userId);
    }

    /**
     * Checks if a user has an active face enrollment.
     */
    @Transactional(readOnly = true)
    public boolean isEnrolled(UUID userId) {
        return faceEnrollmentRepository.existsByUserId(userId);
    }

    /**
     * Soft-deletes a face enrollment (sets is_active = false).
     */
    @Transactional
    public void deleteEnrollment(UUID userId) {
        faceEnrollmentRepository.findByUserId(userId).ifPresent(enrollment -> {
            enrollment.setIsActive(false);
            faceEnrollmentRepository.save(enrollment);
            log.info("Soft-deleted face enrollment for userId={}", userId);
        });
    }
}
