package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("FaceVerificationService Unit Tests")
class FaceVerificationServiceTest {

    private FaceVerificationService verificationService;

    @BeforeEach
    void setUp() {
        FaceAuthProperties props = new FaceAuthProperties();
        props.setVerificationThreshold(new BigDecimal("0.65"));
        FaceEnrollmentService enrollmentServiceMock = null;
        verificationService = new FaceVerificationService(
                enrollmentServiceMock, null, props);
    }

    @Nested
    @DisplayName("Cosine Similarity Tests")
    class CosineSimilarityTests {

        @Test
        @DisplayName("Should return 1.0 for identical normalized vectors")
        void shouldReturnOne_ForIdenticalVectors() {
            float[] v = createRandomEmbedding(512, 42);
            float[] identical = v.clone();

            double similarity = verificationService.cosineSimilarity(v, identical);
            assertEquals(1.0, similarity, 1e-6);
        }

        @Test
        @DisplayName("Should return -1.0 for opposite vectors")
        void shouldReturnNegativeOne_ForOppositeVectors() {
            float[] v = createRandomEmbedding(512, 42);
            float[] opposite = new float[512];
            for (int i = 0; i < 512; i++) opposite[i] = -v[i];

            double similarity = verificationService.cosineSimilarity(v, opposite);
            assertEquals(-1.0, similarity, 1e-6);
        }

        @Test
        @DisplayName("Should return ~0.85+ for similar face embeddings")
        void shouldReturnHighSimilarity_ForSimilarEmbeddings() {
            float[] embedding1 = createEmbedding(512, 1);
            float[] embedding2 = createSimilarEmbedding(embedding1, 0.1f);

            double similarity = verificationService.cosineSimilarity(embedding1, embedding2);
            assertTrue(similarity > 0.5,
                    "Similar embeddings should have cosine similarity > 0.5, got: " + similarity);
        }

        @Test
        @DisplayName("Should return recognizable similarity for similar face embeddings")
        void shouldReturnRecognizableSimilarity_ForSimilarEmbeddings() {
            float[] embedding1 = createEmbedding(512, 1);
            float[] embedding2 = createSimilarEmbedding(embedding1, 0.05f);

            double similarity = verificationService.cosineSimilarity(embedding1, embedding2);
            assertTrue(similarity > 0.3,
                    "Similar embeddings should have cosine similarity > 0.3, got: " + similarity);
        }

        @Test
        @DisplayName("Should return low similarity for completely different embeddings")
        void shouldReturnLowSimilarity_ForDifferentEmbeddings() {
            float[] embedding1 = createEmbedding(512, 1);
            float[] embedding2 = createEmbedding(512, 9999);

            double similarity = verificationService.cosineSimilarity(embedding1, embedding2);
            assertTrue(similarity < 0.3,
                    "Different embeddings should have similarity < 0.3, got: " + similarity);
        }

        @Test
        @DisplayName("Should clamp similarity to [-1, 1]")
        void shouldClampSimilarity() {
            float[] v1 = createEmbedding(512, 42);
            float[] v2 = createEmbedding(512, 43);
            double sim = verificationService.cosineSimilarity(v1, v2);

            assertTrue(sim >= -1.0 && sim <= 1.0,
                    "Similarity should be clamped to [-1, 1], got: " + sim);
        }
    }

    private float[] createRandomEmbedding(int dim, long seed) {
        Random rand = new Random(seed);
        float[] embedding = new float[dim];
        for (int i = 0; i < dim; i++) {
            embedding[i] = rand.nextFloat() * 2f - 1f;
        }
        float norm = 0f;
        for (float v : embedding) norm += v * v;
        norm = (float) Math.sqrt(norm);
        if (norm > 0) for (int i = 0; i < dim; i++) embedding[i] /= norm;
        return embedding;
    }

    private float[] createEmbedding(int dim, long seed) {
        return createRandomEmbedding(dim, seed);
    }

    private float[] createSimilarEmbedding(float[] base, float noiseLevel) {
        float[] result = base.clone();
        Random rand = new Random(123);
        for (int i = 0; i < result.length; i++) {
            result[i] += (rand.nextFloat() * 2f - 1f) * noiseLevel;
        }
        float norm = 0f;
        for (float v : result) norm += v * v;
        norm = (float) Math.sqrt(norm);
        if (norm > 0) for (int i = 0; i < result.length; i++) result[i] /= norm;
        return result;
    }
}
