package iuh.cnm.vnalo.mediaservice.service;

import lombok.extern.slf4j.Slf4j;
import org.imgscalr.Scalr;
import org.springframework.stereotype.Service;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;

/**
 * Handles image compression and thumbnail generation.
 * - Compress: reduces quality to 0.75 (configurable), strips metadata
 * - Thumbnail: resizes to 200px width, JPEG output
 */
@Service
@Slf4j
public class ImageProcessingService {

    private static final float COMPRESSION_QUALITY = 0.75f;
    private static final int THUMBNAIL_SIZE = 200;
    private static final int MAX_IMAGE_WIDTH = 1920;
    private static final int MAX_IMAGE_HEIGHT = 1920;

    /**
     * Compress original image: resize if too large + JPEG compression.
     * Returns null if image cannot be processed.
     */
    public ImageResult compressImage(byte[] originalBytes) throws IOException {
        BufferedImage original = ImageIO.read(new ByteArrayInputStream(originalBytes));
        if (original == null) {
            log.warn("Cannot read image from bytes");
            return null;
        }

        BufferedImage processed = original;

        // Resize if exceeds max dimensions
        if (original.getWidth() > MAX_IMAGE_WIDTH || original.getHeight() > MAX_IMAGE_HEIGHT) {
            processed = Scalr.resize(original, Scalr.Method.QUALITY,
                    Scalr.Mode.AUTOMATIC, MAX_IMAGE_WIDTH, MAX_IMAGE_HEIGHT);
            log.info("Resized image from {}x{} to {}x{}",
                    original.getWidth(), original.getHeight(),
                    processed.getWidth(), processed.getHeight());
        }

        // Compress to JPEG
        byte[] compressedBytes = compressToJpeg(processed, COMPRESSION_QUALITY);

        return new ImageResult(
                compressedBytes,
                processed.getWidth(),
                processed.getHeight(),
                "image/jpeg"
        );
    }

    /**
     * Generate thumbnail from image bytes.
     */
    public ImageResult generateThumbnail(byte[] originalBytes) throws IOException {
        BufferedImage original = ImageIO.read(new ByteArrayInputStream(originalBytes));
        if (original == null) return null;

        BufferedImage thumbnail = Scalr.resize(original, Scalr.Method.QUALITY, THUMBNAIL_SIZE);
        byte[] thumbBytes = compressToJpeg(thumbnail, 0.8f);

        return new ImageResult(
                thumbBytes,
                thumbnail.getWidth(),
                thumbnail.getHeight(),
                "image/jpeg"
        );
    }

    private byte[] compressToJpeg(BufferedImage image, float quality) throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        // Remove alpha channel if present (JPEG doesn't support it)
        BufferedImage rgbImage = image;
        if (image.getType() == BufferedImage.TYPE_INT_ARGB || image.getColorModel().hasAlpha()) {
            rgbImage = new BufferedImage(image.getWidth(), image.getHeight(), BufferedImage.TYPE_INT_RGB);
            rgbImage.createGraphics().drawImage(image, 0, 0, null);
        }

        Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpg");
        if (!writers.hasNext()) {
            // Fallback: write without compression settings
            ImageIO.write(rgbImage, "jpg", baos);
            return baos.toByteArray();
        }

        ImageWriter writer = writers.next();
        ImageWriteParam params = writer.getDefaultWriteParam();
        params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
        params.setCompressionQuality(quality);

        try (ImageOutputStream ios = ImageIO.createImageOutputStream(baos)) {
            writer.setOutput(ios);
            writer.write(null, new IIOImage(rgbImage, null, null), params);
        }
        writer.dispose();

        return baos.toByteArray();
    }

    /**
     * Result of image processing.
     */
    public record ImageResult(byte[] data, int width, int height, String contentType) {}
}
