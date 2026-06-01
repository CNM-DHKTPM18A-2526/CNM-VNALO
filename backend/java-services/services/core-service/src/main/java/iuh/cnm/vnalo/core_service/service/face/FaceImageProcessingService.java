package iuh.cnm.vnalo.core_service.service.face;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;

/**
 * Service for preprocessing face images before ONNX inference.
 * Handles image decoding, face cropping, resizing, and normalization.
 */
@Service
@Slf4j
public class FaceImageProcessingService {

    private static final int EMBEDDING_SIZE = 112;
    private static final int LIVENESS_SIZE = 128;

    /**
     * Reads a JPEG/PNG image from byte array.
     */
    public BufferedImage decodeImage(byte[] imageBytes) {
        if (imageBytes == null || imageBytes.length == 0) {
            return null;
        }
        try (ByteArrayInputStream bais = new ByteArrayInputStream(imageBytes)) {
            BufferedImage img = ImageIO.read(bais);
            if (img == null) {
                log.warn("ImageIO returned null for image bytes (unsupported format)");
                return null;
            }
            return img;
        } catch (IOException e) {
            log.warn("Failed to decode image: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Converts a BufferedImage to RGB float array ready for ONNX inference.
     *
     * @param image source image
     * @param size  target size (112 for embedding, 128 for liveness)
     * @return float array with shape [1][3][size][size], normalized to [0, 1]
     */
    public float[][][][] toRgbFloatArray(BufferedImage image, int size) {
        BufferedImage resized = resize(image, size, size);
        float[][][][] result = new float[1][3][size][size];

        for (int y = 0; y < size; y++) {
            for (int x = 0; x < size; x++) {
                int rgb = resized.getRGB(x, y);
                result[0][0][y][x] = ((rgb >> 16) & 0xFF) / 255.0f; // R
                result[0][1][y][x] = ((rgb >> 8) & 0xFF) / 255.0f;  // G
                result[0][2][y][x] = (rgb & 0xFF) / 255.0f;          // B
            }
        }
        return result;
    }

    /**
     * Converts to ArcFace normalization: subtract 127.5 and divide by 128.
     * Output range approximately [-1, 1].
     *
     * @param input output of {@link #toRgbFloatArray}, shape [1][3][112][112]
     * @return normalized array for ArcFace models (buffalo_s)
     */
    public float[][][][] normalizeArcFace(float[][][][] input) {
        int height = input[0][0].length;
        int width = input[0][0][0].length;
        float[][][][] normalized = new float[1][3][height][width];

        for (int c = 0; c < 3; c++) {
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    normalized[0][c][y][x] = (input[0][c][y][x] * 255.0f - 127.5f) / 128.0f;
                }
            }
        }
        return normalized;
    }

    /**
     * Resizes an image using high-quality bilinear interpolation.
     */
    private BufferedImage resize(BufferedImage original, int targetWidth, int targetHeight) {
        BufferedImage resized = new BufferedImage(targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = resized.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(original, 0, 0, targetWidth, targetHeight, null);
        g.dispose();
        return resized;
    }

    /**
     * Crops a square from the center of the image.
     * This preserves aspect ratio and focuses on the center where the face is located.
     */
    public BufferedImage cropCenterSquare(BufferedImage original) {
        int width = original.getWidth();
        int height = original.getHeight();
        if (width == height) {
            return original;
        }
        int size = Math.min(width, height);
        int x = (width - size) / 2;
        int y = (height - size) / 2;
        return original.getSubimage(x, y, size, size);
    }

    /**
     * Creates embedding input for buffalo_s model (112x112, ArcFace normalization).
     */
    public float[][][][] createEmbeddingInput(BufferedImage faceImage) {
        BufferedImage cropped = cropCenterSquare(faceImage);
        float[][][][] rgb = toRgbFloatArray(cropped, EMBEDDING_SIZE);
        return normalizeArcFace(rgb);
    }

    /**
     * Creates liveness input for MiniFASNetV2 model (128x128, [0,1] range).
     */
    public float[][][][] createLivenessInput(BufferedImage faceImage) {
        BufferedImage cropped = cropCenterSquare(faceImage);
        return toRgbFloatArray(cropped, LIVENESS_SIZE);
    }
}
