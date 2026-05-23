package iuh.cnm.vnalo.core_service.service.face;

import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Service for AES-256-GCM encryption/decryption of face embedding vectors.
 * Embeddings are encrypted before storage in the database.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FaceEncryptionService {

    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128;

    private final FaceAuthProperties faceAuthProperties;

    /**
     * Encrypts a 512-D float embedding vector.
     *
     * @param embedding 512-D float array from buffalo_s model
     * @return Base64-encoded encrypted data (IV + ciphertext + tag)
     */
    public String encrypt(float[] embedding) {
        try {
            byte[] iv = new byte[GCM_IV_LENGTH];
            new SecureRandom().nextBytes(iv);

            SecretKey secretKey = deriveKey();
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, spec);

            ByteBuffer byteBuffer = ByteBuffer.allocate(4 * embedding.length);
            byteBuffer.asFloatBuffer().put(embedding);
            byte[] ciphertext = cipher.doFinal(byteBuffer.array());

            ByteBuffer result = ByteBuffer.allocate(GCM_IV_LENGTH + ciphertext.length);
            result.put(iv).put(ciphertext);
            return Base64.getEncoder().encodeToString(result.array());
        } catch (Exception e) {
            log.error("Failed to encrypt face embedding", e);
            throw new RuntimeException("Encryption failed", e);
        }
    }

    /**
     * Decrypts a Base64-encoded encrypted embedding back to float array.
     *
     * @param encryptedData Base64 string from {@link #encrypt(float[])}
     * @return 512-D float array
     */
    public float[] decrypt(String encryptedData) {
        try {
            byte[] decoded = Base64.getDecoder().decode(encryptedData);
            ByteBuffer byteBuffer = ByteBuffer.wrap(decoded);

            byte[] iv = new byte[GCM_IV_LENGTH];
            byteBuffer.get(iv);

            byte[] ciphertext = new byte[byteBuffer.remaining()];
            byteBuffer.get(ciphertext);

            SecretKey secretKey = deriveKey();
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_LENGTH, iv));

            byte[] plaintext = cipher.doFinal(ciphertext);
            FloatBuffer floatBuffer = ByteBuffer.wrap(plaintext).asFloatBuffer();
            float[] result = new float[floatBuffer.remaining()];
            floatBuffer.get(result);
            return result;
        } catch (Exception e) {
            log.error("Failed to decrypt face embedding", e);
            throw new RuntimeException("Decryption failed", e);
        }
    }

    private SecretKey deriveKey() {
        String keyMaterial = faceAuthProperties.getEncryptionKey();
        if (keyMaterial == null || keyMaterial.isBlank()) {
            throw new IllegalStateException(
                    "Face encryption key is not configured. Set face.auth.encryption-key in application.yml");
        }
        try {
            MessageDigest sha = MessageDigest.getInstance("SHA-256");
            byte[] digest = sha.digest(keyMaterial.getBytes(StandardCharsets.UTF_8));
            return new SecretKeySpec(digest, "AES");
        } catch (Exception e) {
            throw new RuntimeException("Failed to derive encryption key", e);
        }
    }
}
