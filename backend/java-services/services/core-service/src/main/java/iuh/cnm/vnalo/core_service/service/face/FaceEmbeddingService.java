package iuh.cnm.vnalo.core_service.service.face;

import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtException;
import ai.onnxruntime.OrtSession;
import ai.onnxruntime.OrtSession.SessionOptions;
import iuh.cnm.vnalo.core_service.config.FaceAuthProperties;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * ONNX Runtime service for face embedding extraction and liveness detection.
 * Loads buffalo_s (embedding) and MiniFASNetV2 (liveness) models.
 * Models are loaded lazily on first inference to avoid blocking Spring startup.
 *
 * <p>Models expected at:
 * <ul>
 *   <li>buffalo_s.onnx (6 MB) — ArcFace embedding model</li>
 *   <li>minifasnetv2.onnx (600 KB) — Anti-spoofing liveness model</li>
 * </ul>
 *
 * <p>Inference is CPU-only (no GPU/CUDA). On t3.large (2 vCPU):
 * <ul>
 *   <li>buffalo_s: ~15-35ms per inference</li>
 *   <li>MiniFASNetV2: ~5-10ms per inference</li>
 * </ul>
 */
@Service
@Lazy
@RequiredArgsConstructor
@Slf4j
public class FaceEmbeddingService implements AutoCloseable {

    private static final String EMBEDDING_MODEL = "buffalo_s.onnx";
    private static final String LIVENESS_MODEL = "minifasnetv2.onnx";
    private static final int EMBEDDING_DIM = 512;
    private static final int EMBEDDING_INPUT_SIZE = 112;
    private static final int LIVENESS_INPUT_SIZE = 128;

    private final FaceAuthProperties faceAuthProperties;

    private OrtEnvironment env;
    private OrtSession embeddingSession;
    private OrtSession livenessSession;
    private final AtomicBoolean initialized = new AtomicBoolean(false);
    private final AtomicBoolean failed = new AtomicBoolean(false);

    @PostConstruct
    public void init() {
        log.info("FaceEmbeddingService initialized (models load lazily on first use)");
    }

    private synchronized void ensureInitialized() {
        if (initialized.get() || failed.get()) {
            return;
        }

        String modelPath = faceAuthProperties.getModelPath();
        log.info("Loading face auth ONNX models from: {}", modelPath);

        try {
            this.env = OrtEnvironment.getEnvironment();
            OrtSession.SessionOptions sessionOptions = new OrtSession.SessionOptions();
            sessionOptions.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT);
            sessionOptions.setIntraOpNumThreads(2);
            sessionOptions.setInterOpNumThreads(1);

            String embeddingPath = resolvePath(modelPath, EMBEDDING_MODEL);
            String livenessPath = resolvePath(modelPath, LIVENESS_MODEL);

            log.info("Loading embedding model: {}", embeddingPath);
            this.embeddingSession = env.createSession(embeddingPath, sessionOptions);
            log.info("Embedding model loaded successfully. Input/output names: {}",
                    embeddingSession.getInputNames());

            log.info("Loading liveness model: {}", livenessPath);
            this.livenessSession = env.createSession(livenessPath, sessionOptions);
            log.info("Liveness model loaded successfully");

            initialized.set(true);
            log.info("Face auth ONNX models loaded successfully");
        } catch (Exception e) {
            failed.set(true);
            log.warn("Failed to load face auth ONNX models: {}. "
                    + "Face authentication will return errors until models are available.", e.getMessage());
        }
    }

    private String resolvePath(String basePath, String modelName) {
        if (basePath.startsWith("classpath:")) {
            String resourcePath = basePath.replace("classpath:", "") + "/" + modelName;
            return resourcePath;
        }
        return basePath + "/" + modelName;
    }

    /**
     * Extracts a 512-D face embedding vector from a pre-cropped face image.
     *
     * @param faceImage Pre-cropped and aligned face image as float array
     *                  with shape [1][3][112][112] (batch, channels, height, width)
     * @return L2-normalized 512-D embedding vector
     * @throws OrtException if inference fails
     */
    public float[] extractEmbedding(float[][][][] faceImage) throws OrtException {
        ensureInitialized();
        if (!initialized.get()) {
            throw new OrtException("Face embedding model not available");
        }

        try (OnnxTensor inputTensor = OnnxTensor.createTensor(env, faceImage)) {
            var result = embeddingSession.run(
                    Collections.singletonMap("input", inputTensor));
            float[][] output = (float[][]) result.get(0).getValue();
            return normalize(output[0]);
        }
    }

    /**
     * Checks liveness of a face using MiniFASNetV2 anti-spoofing model.
     *
     * @param faceImage Pre-cropped face image with shape [1][3][128][128]
     * @return Liveness score between 0.0 (spoof) and 1.0 (live)
     * @throws OrtException if inference fails
     */
    public double checkLiveness(float[][][][] faceImage) throws OrtException {
        ensureInitialized();
        if (!initialized.get()) {
            throw new OrtException("Face liveness model not available");
        }

        try (OnnxTensor inputTensor = OnnxTensor.createTensor(env, faceImage)) {
            var result = livenessSession.run(
                    Collections.singletonMap("input", inputTensor));
            float[] output = (float[]) result.get(0).getValue();
            return sigmoid(output[0]);
        }
    }

    /**
     * Checks if the embedding service is ready (models loaded successfully).
     */
    public boolean isReady() {
        ensureInitialized();
        return initialized.get();
    }

    /**
     * L2-normalizes a vector.
     */
    private float[] normalize(float[] vector) {
        float norm = 0f;
        for (float v : vector) {
            norm += v * v;
        }
        norm = (float) Math.sqrt(norm);
        if (norm > 0) {
            for (int i = 0; i < vector.length; i++) {
                vector[i] /= norm;
            }
        }
        return vector;
    }

    /**
     * Sigmoid activation for liveness score.
     */
    private double sigmoid(float x) {
        return 1.0 / (1.0 + Math.exp(-x));
    }

    @Override
    @PreDestroy
    public void close() {
        try {
            if (embeddingSession != null) {
                embeddingSession.close();
            }
            if (livenessSession != null) {
                livenessSession.close();
            }
            if (env != null) {
                env.close();
            }
        } catch (Exception e) {
            log.warn("Error closing ONNX sessions", e);
        }
    }
}
