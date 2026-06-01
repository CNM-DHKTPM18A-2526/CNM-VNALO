package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.exception.ApiException;
import iuh.cnm.vnalo.core_service.exception.ErrorCode;
import iuh.cnm.vnalo.core_service.model.entity.face.FaceEnrollment;
import iuh.cnm.vnalo.core_service.repository.face.FaceEnrollmentRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.Random;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("FaceEnrollmentService Unit Tests")
class FaceEnrollmentServiceTest {

    @Mock
    private FaceEnrollmentRepository faceEnrollmentRepository;

    @Mock
    private FaceEncryptionService faceEncryptionService;

    @InjectMocks
    private FaceEnrollmentService enrollmentService;

    private UUID userId;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
    }

    @Nested
    @DisplayName("Enroll Tests")
    class EnrollTests {

        @Test
        @DisplayName("Should enroll new face successfully")
        void shouldEnrollNewFace() {
            float[] embedding = createEmbedding(512);
            String encrypted = "encrypted_data_placeholder";
            when(faceEnrollmentRepository.findByUserId(userId)).thenReturn(Optional.empty());
            when(faceEncryptionService.encrypt(embedding)).thenReturn(encrypted);
            when(faceEnrollmentRepository.save(any(FaceEnrollment.class)))
                    .thenAnswer(inv -> inv.getArgument(0));

            FaceEnrollment result = enrollmentService.enroll(
                    userId, embedding, 0.95, 0.90, "{\"device\":\"test\"}");

            assertNotNull(result);
            assertEquals(encrypted, result.getEmbeddingData());
            assertEquals(1, result.getVersion());
            assertTrue(result.getIsActive());
            verify(faceEnrollmentRepository).save(any(FaceEnrollment.class));
        }

        @Test
        @DisplayName("Should re-enroll existing face with version bump")
        void shouldReEnroll_ExistingFace() {
            float[] embedding = createEmbedding(512);
            String encrypted = "re_encrypted_data";
            FaceEnrollment existing = FaceEnrollment.builder()
                    .userId(userId)
                    .embeddingData("old_data")
                    .version(3)
                    .isActive(true)
                    .build();
            when(faceEnrollmentRepository.findByUserId(userId))
                    .thenReturn(Optional.of(existing));
            when(faceEncryptionService.encrypt(embedding)).thenReturn(encrypted);
            when(faceEnrollmentRepository.save(any(FaceEnrollment.class)))
                    .thenAnswer(inv -> inv.getArgument(0));

            FaceEnrollment result = enrollmentService.enroll(
                    userId, embedding, 0.98, 0.92, "{\"device\":\"updated\"}");

            assertEquals(encrypted, result.getEmbeddingData());
            assertEquals(4, result.getVersion(),
                    "Version should be bumped from 3 to 4");
            assertTrue(result.getIsActive());
        }
    }

    @Nested
    @DisplayName("Get Embedding Tests")
    class GetEmbeddingTests {

        @Test
        @DisplayName("Should retrieve and decrypt embedding")
        void shouldGetAndDecryptEmbedding() {
            String encrypted = "encrypted_face_data";
            float[] expected = createEmbedding(512);
            FaceEnrollment enrollment = FaceEnrollment.builder()
                    .userId(userId)
                    .embeddingData(encrypted)
                    .isActive(true)
                    .build();
            when(faceEnrollmentRepository.findByUserIdAndIsActiveTrue(userId))
                    .thenReturn(Optional.of(enrollment));
            when(faceEncryptionService.decrypt(encrypted)).thenReturn(expected);

            float[] result = enrollmentService.getAndDecryptEmbedding(userId);

            assertArrayEquals(expected, result, 1e-5f);
        }

        @Test
        @DisplayName("Should throw exception when user not enrolled")
        void shouldThrowException_WhenNotEnrolled() {
            when(faceEnrollmentRepository.findByUserIdAndIsActiveTrue(userId))
                    .thenReturn(Optional.empty());

            ApiException exception = assertThrows(ApiException.class,
                    () -> enrollmentService.getAndDecryptEmbedding(userId));

            assertEquals(ErrorCode.FACE_NOT_ENROLLED, exception.getErrorCode());
        }
    }

    @Nested
    @DisplayName("Is Enrolled Tests")
    class IsEnrolledTests {

        @Test
        @DisplayName("Should return true when enrolled")
        void shouldReturnTrue_WhenEnrolled() {
            when(faceEnrollmentRepository.existsByUserId(userId)).thenReturn(true);

            assertTrue(enrollmentService.isEnrolled(userId));
        }

        @Test
        @DisplayName("Should return false when not enrolled")
        void shouldReturnFalse_WhenNotEnrolled() {
            when(faceEnrollmentRepository.existsByUserId(userId)).thenReturn(false);

            assertFalse(enrollmentService.isEnrolled(userId));
        }
    }

    @Nested
    @DisplayName("Delete Enrollment Tests")
    class DeleteEnrollmentTests {

        @Test
        @DisplayName("Should soft-delete enrollment")
        void shouldSoftDeleteEnrollment() {
            FaceEnrollment enrollment = FaceEnrollment.builder()
                    .userId(userId)
                    .embeddingData("data")
                    .isActive(true)
                    .build();
            when(faceEnrollmentRepository.findByUserId(userId))
                    .thenReturn(Optional.of(enrollment));
            when(faceEnrollmentRepository.save(any(FaceEnrollment.class)))
                    .thenAnswer(inv -> inv.getArgument(0));

            enrollmentService.deleteEnrollment(userId);

            ArgumentCaptor<FaceEnrollment> captor = ArgumentCaptor.forClass(FaceEnrollment.class);
            verify(faceEnrollmentRepository).save(captor.capture());
            assertFalse(captor.getValue().getIsActive(),
                    "isActive should be set to false on soft delete");
        }
    }

    private float[] createEmbedding(int dim) {
        Random rand = new Random(42);
        float[] embedding = new float[dim];
        for (int i = 0; i < dim; i++) {
            embedding[i] = rand.nextFloat() * 2f - 1f;
        }
        return embedding;
    }
}
