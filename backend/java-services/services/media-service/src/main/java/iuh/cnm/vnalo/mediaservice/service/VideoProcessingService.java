package iuh.cnm.vnalo.mediaservice.service;

import lombok.extern.slf4j.Slf4j;
import org.jcodec.api.FrameGrab;
import org.jcodec.common.io.NIOUtils;
import org.jcodec.common.model.Picture;
import org.jcodec.scale.AWTUtil;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Handles video processing:
 * - Extract thumbnail frame from video
 * - Extract basic video metadata (duration is not easily available via jcodec)
 *
 * Note: Full video transcoding (format conversion) requires FFmpeg.
 * For production, consider AWS MediaConvert or a dedicated transcoding service.
 */
@Service
@Slf4j
public class VideoProcessingService {

    /**
     * Extract a thumbnail from video bytes.
     * Takes a frame from ~1 second into the video (or first frame if shorter).
     */
    public VideoThumbnailResult extractThumbnail(byte[] videoBytes) {
        Path tempFile = null;
        try {
            // jcodec needs a file — write to temp
            tempFile = Files.createTempFile("video_", ".mp4");
            Files.write(tempFile, videoBytes);

            Picture picture = FrameGrab.getFrameFromFile(tempFile.toFile(), 30); // frame #30 (~1sec at 30fps)
            if (picture == null) {
                log.warn("Could not extract frame from video");
                return null;
            }

            BufferedImage thumbnail = AWTUtil.toBufferedImage(picture);

            // Scale down for thumbnail
            int thumbWidth = 320;
            int thumbHeight = (int) ((double) thumbnail.getHeight() / thumbnail.getWidth() * thumbWidth);
            BufferedImage scaled = new BufferedImage(thumbWidth, thumbHeight, BufferedImage.TYPE_INT_RGB);
            scaled.createGraphics().drawImage(
                    thumbnail.getScaledInstance(thumbWidth, thumbHeight, java.awt.Image.SCALE_SMOOTH),
                    0, 0, null);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(scaled, "jpg", baos);

            return new VideoThumbnailResult(
                    baos.toByteArray(),
                    thumbnail.getWidth(),
                    thumbnail.getHeight()
            );
        } catch (Exception e) {
            log.warn("Failed to extract video thumbnail: {}", e.getMessage());
            return null;
        } finally {
            // Cleanup temp file
            if (tempFile != null) {
                try {
                    Files.deleteIfExists(tempFile);
                } catch (IOException ignored) {}
            }
        }
    }

    public record VideoThumbnailResult(byte[] thumbnailData, int videoWidth, int videoHeight) {}
}
