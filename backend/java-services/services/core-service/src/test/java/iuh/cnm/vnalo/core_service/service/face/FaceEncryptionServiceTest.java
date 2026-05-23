package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("FaceEncryptionService Unit Tests")
class FaceEncryptionServiceTest {

    private FaceEncryptionService encryptionService;

    @BeforeEach
    void setUp() {
        FaceAuthProperties props = new FaceAuthProperties();
        props.setEncryptionKey("test-encryption-key-for-face-embeddings-32chars!");
        encryptionService = new FaceEncryptionService(props);
    }

    @Nested
    @DisplayName("Encrypt/Decrypt Round-Trip Tests")
    class RoundTripTests {

        @Test
        @DisplayName("Should encrypt and decrypt a 512-D embedding correctly")
        void shouldEncryptAndDecrypt_512DEmbedding() {
            float[] original = createRandomEmbedding(512);

            String encrypted = encryptionService.encrypt(original);
            assertNotNull(encrypted);
            assertFalse(encrypted.isEmpty());

            float[] decrypted = encryptionService.decrypt(encrypted);

            assertArrayEquals(original, decrypted, 1e-6f);
        }

        @Test
        @DisplayName("Should produce different ciphertext for same embedding (random IV)")
        void shouldProduceDifferentCiphertext_RandomIV() {
            float[] original = createRandomEmbedding(512);

            String encrypted1 = encryptionService.encrypt(original);
            String encrypted2 = encryptionService.encrypt(original);

            assertNotEquals(encrypted1, encrypted2,
                    "Same plaintext should produce different ciphertext due to random IV");

            float[] decrypted1 = encryptionService.decrypt(encrypted1);
            float[] decrypted2 = encryptionService.decrypt(encrypted2);

            assertArrayEquals(decrypted1, decrypted2, 1e-6f);
        }

        @Test
        @DisplayName("Should handle zero embedding vector")
        void shouldHandleZeroEmbedding() {
            float[] zero = new float[512];

            String encrypted = encryptionService.encrypt(zero);
            float[] decrypted = encryptionService.decrypt(encrypted);

            assertArrayEquals(zero, decrypted, 1e-6f);
        }

        @Test
        @DisplayName("Should handle normalized embedding values")
        void shouldHandleNormalizedEmbedding() {
            float[] normalized = new float[512];
            normalized[0] = 1.0f;
            for (int i = 1; i < 512; i++) normalized[i] = 0f;

            String encrypted = encryptionService.encrypt(normalized);
            float[] decrypted = encryptionService.decrypt(encrypted);

            assertArrayEquals(normalized, decrypted, 1e-5f);
        }
    }

    @Nested
    @DisplayName("Edge Cases")
    class EdgeCaseTests {

        @Test
        @DisplayName("Should throw exception when encryption key is missing")
        void shouldThrowException_WhenKeyMissing() {
            FaceAuthProperties noKeyProps = new FaceAuthProperties();
            noKeyProps.setEncryptionKey(null);
            FaceEncryptionService svc = new FaceEncryptionService(noKeyProps);

            float[] original = createRandomEmbedding(512);
            assertThrows(RuntimeException.class, () -> svc.encrypt(original));
        }

        @Test
        @DisplayName("Should throw exception when encryption key is blank")
        void shouldThrowException_WhenKeyBlank() {
            FaceAuthProperties blankKeyProps = new FaceAuthProperties();
            blankKeyProps.setEncryptionKey("   ");
            FaceEncryptionService svc = new FaceEncryptionService(blankKeyProps);

            float[] original = createRandomEmbedding(512);
            assertThrows(RuntimeException.class, () -> svc.encrypt(original));
        }

        @Test
        @DisplayName("Should throw exception for tampered ciphertext")
        void shouldThrowException_ForTamperedCiphertext() {
            float[] original = createRandomEmbedding(512);
            String encrypted = encryptionService.encrypt(original);

            String tampered = encrypted.substring(0, encrypted.length() - 2) + "XX";
            assertThrows(RuntimeException.class, () -> encryptionService.decrypt(tampered));
        }
    }

    private float[] createRandomEmbedding(int dim) {
        Random rand = new Random(42);
        float[] embedding = new float[dim];
        for (int i = 0; i < dim; i++) {
            embedding[i] = rand.nextFloat() * 2f - 1f;
        }
        return embedding;
    }
}
