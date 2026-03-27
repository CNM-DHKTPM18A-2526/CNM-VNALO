package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaMetadataRepository;
import iuh.cnm.vnalo.mediaservice.event.MediaUploadedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import iuh.cnm.vnalo.mediaservice.config.RabbitMQConfig;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.File;
import java.nio.file.Files;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MediaProcessingService {

    private final MediaMetadataRepository mediaMetadataRepository;
    private final S3Service s3Service;
    private final ImageProcessingService imageProcessingService;
    private final VideoProcessingService videoProcessingService;

    @Autowired(required = false)
    private RabbitTemplate rabbitTemplate;

    @Async
    @Transactional
    public void processMediaAsync(UUID mediaId, String objectKey) {
        log.info("Starting async processing for media: {}", mediaId);
        MediaMetadata media = mediaMetadataRepository.findById(mediaId).orElse(null);
        if (media == null) {
            log.warn("Media not found for async processing: {}", mediaId);
            return;
        }

        File tempFile = null;
        try {
            tempFile = File.createTempFile("media_process_", ".tmp");
            tempFile.delete(); // S3 SDK needs path to NOT exist — it creates the file itself
            s3Service.downloadFileToPath(objectKey, tempFile.toPath());

            if (media.getCategory().isImage()) {
                extractImageMetadata(tempFile, media);
            } else if (media.getCategory().isVideo()) {
                extractVideoMetadata(tempFile, media);
            }
            media.setNeedsProcessing(false);
            media.setStatus(iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus.READY);
            mediaMetadataRepository.save(media);

            publishMediaEvent(media);
            log.info("Completed async processing for media: {}", mediaId);
        } catch (Exception e) {
            log.error("Failed to process media async for media ID: {}", mediaId, e);
            media.setStatus(iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus.FAILED);
            mediaMetadataRepository.save(media);
        } finally {
            if (tempFile != null && tempFile.exists()) {
                tempFile.delete();
            }
        }
    }

    private void extractImageMetadata(File file, MediaMetadata media) {
        try {
            java.awt.image.BufferedImage image = javax.imageio.ImageIO.read(file);
            if (image != null) {
                media.setWidth(image.getWidth());
                media.setHeight(image.getHeight());
            }

            byte[] fileBytes = Files.readAllBytes(file.toPath());
            ImageProcessingService.ImageResult thumbnail = imageProcessingService.generateThumbnail(fileBytes);
            if (thumbnail != null) {
                String thumbKey = "thumbnails/" + media.getId() + "_thumb.jpg";
                String thumbnailUrl = s3Service.uploadBytes(thumbnail.data(), thumbKey, thumbnail.contentType());
                media.setThumbnailUrl(thumbnailUrl);
                log.info("Generated image thumbnail for {}: {}", media.getId(), thumbnailUrl);
            }
        } catch (Exception e) {
            log.warn("Failed to read image dimensions or generate thumbnail: {}", e.getMessage());
        }
    }

    private void extractVideoMetadata(File tempFile, MediaMetadata media) {
        try {
            org.jcodec.api.FrameGrab grab = org.jcodec.api.FrameGrab.createFrameGrab(
                    org.jcodec.common.io.NIOUtils.readableChannel(tempFile));
            org.jcodec.common.model.Picture picture = grab.getNativeFrame();
            if (picture != null) {
                media.setWidth(picture.getWidth());
                media.setHeight(picture.getHeight());
            }

            try (org.jcodec.common.io.SeekableByteChannel ch = org.jcodec.common.io.NIOUtils.readableChannel(tempFile)) {
                org.jcodec.containers.mp4.demuxer.MP4Demuxer demuxer = org.jcodec.containers.mp4.demuxer.MP4Demuxer.createMP4Demuxer(ch);
                org.jcodec.common.DemuxerTrack videoTrack = demuxer.getVideoTrack();
                if (videoTrack != null) {
                    org.jcodec.common.DemuxerTrackMeta meta = videoTrack.getMeta();
                    if (meta != null && meta.getTotalDuration() > 0) {
                        media.setDurationMs((int) (meta.getTotalDuration() * 1000));
                    }
                }
            }

            byte[] fileBytes = Files.readAllBytes(tempFile.toPath());
            VideoProcessingService.VideoThumbnailResult thumbnail = videoProcessingService.extractThumbnail(fileBytes);
            if (thumbnail != null) {
                String thumbKey = "thumbnails/" + media.getId() + "_thumb.jpg";
                String thumbnailUrl = s3Service.uploadBytes(thumbnail.thumbnailData(), thumbKey, "image/jpeg");
                media.setThumbnailUrl(thumbnailUrl);
                log.info("Generated video thumbnail for {}: {}", media.getId(), thumbnailUrl);
            }
        } catch (Exception e) {
            log.warn("Failed to read video metadata or generate thumbnail: {}", e.getMessage());
        }
    }

    private void publishMediaEvent(MediaMetadata media) {
        if (rabbitTemplate != null) {
            try {
                rabbitTemplate.convertAndSend(RabbitMQConfig.EXCHANGE_NAME, RabbitMQConfig.UPLOAD_ROUTING_KEY,
                        MediaUploadedEvent.builder()
                        .mediaId(media.getId())
                        .objectKey(media.getObjectKey())
                        .bucket(media.getBucket())
                        .category(media.getCategory())
                        .build());
            } catch (Exception e) {
                log.warn("Failed to publish media uploaded event to RabbitMQ for media: {}", media.getId(), e);
            }
        }
    }
}
