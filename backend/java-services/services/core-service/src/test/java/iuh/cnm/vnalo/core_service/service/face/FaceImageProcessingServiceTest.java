package iuh.cnm.vnalo.core_service.service.face;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.awt.image.BufferedImage;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("FaceImageProcessingService Unit Tests")
class FaceImageProcessingServiceTest {

    private final FaceImageProcessingService imageProcessing = new FaceImageProcessingService();

    @Nested
    @DisplayName("Decode Image Tests")
    class DecodeImageTests {

        @Test
        @DisplayName("Should return null for null bytes")
        void shouldReturnNull_ForNullBytes() {
            assertNull(imageProcessing.decodeImage(null));
        }

        @Test
        @DisplayName("Should return null for empty bytes")
        void shouldReturnNull_ForEmptyBytes() {
            assertNull(imageProcessing.decodeImage(new byte[0]));
        }

        @Test
        @DisplayName("Should return null for invalid image data")
        void shouldReturnNull_ForInvalidData() {
            assertNull(imageProcessing.decodeImage("not an image".getBytes()));
        }
    }

    @Nested
    @DisplayName("toRgbFloatArray Tests")
    class ToRgbFloatArrayTests {

        @Test
        @DisplayName("Should produce correct shape [1][3][size][size]")
        void shouldProduceCorrectShape() {
            BufferedImage img = createTestImage(200, 200);

            float[][][][] result = imageProcessing.toRgbFloatArray(img, 112);

            assertEquals(1, result.length);
            assertEquals(3, result[0].length);
            assertEquals(112, result[0][0].length);
            assertEquals(112, result[0][0][0].length);
        }

        @Test
        @DisplayName("Should normalize RGB values to [0, 1]")
        void shouldNormalizeTo01() {
            BufferedImage img = createTestImage(50, 50);

            float[][][][] result = imageProcessing.toRgbFloatArray(img, 112);

            for (int c = 0; c < 3; c++) {
                for (int y = 0; y < 112; y++) {
                    for (int x = 0; x < 112; x++) {
                        assertTrue(result[0][c][y][x] >= 0f && result[0][c][y][x] <= 1f,
                                "RGB values must be in [0, 1] range");
                    }
                }
            }
        }

        @Test
        @DisplayName("Should handle 128x128 liveness size")
        void shouldHandleLivenessSize() {
            BufferedImage img = createTestImage(200, 200);

            float[][][][] result = imageProcessing.toRgbFloatArray(img, 128);

            assertEquals(128, result[0][0].length);
            assertEquals(128, result[0][0][0].length);
        }
    }

    @Nested
    @DisplayName("normalizeArcFace Tests")
    class NormalizeArcFaceTests {

        @Test
        @DisplayName("Should produce values in approximately [-1, 1] range")
        void shouldProduceMinusOneToOneRange() {
            BufferedImage img = createTestImage(100, 100);
            float[][][][] rgb = imageProcessing.toRgbFloatArray(img, 112);

            float[][][][] normalized = imageProcessing.normalizeArcFace(rgb);

            for (int c = 0; c < 3; c++) {
                for (int y = 0; y < 112; y++) {
                    for (int x = 0; x < 112; x++) {
                        assertTrue(normalized[0][c][y][x] >= -1.1f
                                        && normalized[0][c][y][x] <= 1.1f,
                                "ArcFace normalized values should be in [-1, 1] range");
                    }
                }
            }
        }

        @Test
        @DisplayName("Should preserve shape")
        void shouldPreserveShape() {
            float[][][][] input = new float[1][3][112][112];
            float[][][][] normalized = imageProcessing.normalizeArcFace(input);

            assertEquals(input.length, normalized.length);
            assertEquals(input[0].length, normalized[0].length);
        }
    }

    @Nested
    @DisplayName("Input Factory Tests")
    class InputFactoryTests {

        @Test
        @DisplayName("createEmbeddingInput should produce shape [1][3][112][112]")
        void createEmbeddingInput_ShouldProduceCorrectShape() {
            BufferedImage img = createTestImage(200, 200);

            float[][][][] input = imageProcessing.createEmbeddingInput(img);

            assertEquals(1, input.length);
            assertEquals(3, input[0].length);
            assertEquals(112, input[0][0].length);
            assertEquals(112, input[0][0][0].length);
        }

        @Test
        @DisplayName("createLivenessInput should produce shape [1][3][128][128]")
        void createLivenessInput_ShouldProduceCorrectShape() {
            BufferedImage img = createTestImage(200, 200);

            float[][][][] input = imageProcessing.createLivenessInput(img);

            assertEquals(1, input.length);
            assertEquals(3, input[0].length);
            assertEquals(128, input[0][0].length);
            assertEquals(128, input[0][0][0].length);
        }
    }

    private BufferedImage createTestImage(int width, int height) {
        BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Random rand = new Random(42);
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int r = rand.nextInt(256);
                int g = rand.nextInt(256);
                int b = rand.nextInt(256);
                img.setRGB(x, y, (r << 16) | (g << 8) | b);
            }
        }
        return img;
    }
}
