package iuh.cnm.vnalo.mediaservice.event;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaObjectRepository;
import iuh.cnm.vnalo.mediaservice.service.ImageProcessingService;
import iuh.cnm.vnalo.mediaservice.service.S3Service;
import iuh.cnm.vnalo.mediaservice.service.VideoProcessingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.annotation.RetryableTopic;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.retry.annotation.Backoff;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
@ConditionalOnClass(KafkaTemplate.class)
public class MediaEventConsumer {

    private final MediaObjectRepository mediaObjectRepository;
    private final S3Service s3Service;
    private final ImageProcessingService imageProcessingService;
    private final VideoProcessingService videoProcessingService;

    @RetryableTopic(
            attempts = "3",
            backoff = @Backoff(delay = 1000, multiplier = 2.0)
    )
    @KafkaListener(topics = "media-uploaded-topic", groupId = "media-service-group")
    public void consumeMediaUploadedEvent(MediaUploadedEvent event) {
        log.info("Processing media event: {}", event.getMediaId());

        MediaObject media = mediaObjectRepository.findById(event.getMediaId())
                .orElseThrow(() -> new RuntimeException("Media not found: " + event.getMediaId()));

        try {
            media.setStatus(MediaStatus.PROCESSING);
            mediaObjectRepository.save(media);

            if (media.getMediaCategory().isImage()) {
                processImage(media);
            } else if (media.getMediaCategory().isVideo()) {
                processVideo(media);
            } else {
                log.info("No async processing needed for category: {} id: {}",
                        media.getMediaCategory(), media.getId());
            }

            media.setStatus(MediaStatus.READY);
            mediaObjectRepository.save(media);
            log.info("Successfully processed media: {}", media.getId());

        } catch (Exception e) {
            log.error("Error processing media: {}", event.getMediaId(), e);
            media.setStatus(MediaStatus.FAILED);
            mediaObjectRepository.save(media);
            throw new RuntimeException(e);
        }
    }

    /**
     * Process image: compress original + generate thumbnail.
     */
    private void processImage(MediaObject media) throws Exception {
        byte[] originalBytes = s3Service.downloadFile(media.getObjectKey());

        // 1. Compress original image and re-upload
        ImageProcessingService.ImageResult compressed = imageProcessingService.compressImage(originalBytes);
        if (compressed != null) {
            String compressedKey = media.getObjectKey();
            // Re-upload compressed version to same key
            String url = s3Service.uploadBytes(compressed.data(), compressedKey, compressed.contentType());
            media.setUrl(url);
            media.setWidth(compressed.width());
            media.setHeight(compressed.height());
            media.setSizeBytes((long) compressed.data().length);
            log.info("Compressed image: {}KB → {}KB ({}%)",
                    originalBytes.length / 1024,
                    compressed.data().length / 1024,
                    100 - (compressed.data().length * 100 / originalBytes.length));
        }

        // 2. Generate thumbnail
        ImageProcessingService.ImageResult thumbnail = imageProcessingService.generateThumbnail(originalBytes);
        if (thumbnail != null) {
            String thumbnailKey = media.getObjectKey().replace(".", "_thumb.");
            String thumbnailUrl = s3Service.uploadBytes(thumbnail.data(), thumbnailKey, thumbnail.contentType());
            media.setThumbnailUrl(thumbnailUrl);
        }
    }

    /**
     * Process video: extract thumbnail frame from video.
     */
    private void processVideo(MediaObject media) {
        byte[] videoBytes = s3Service.downloadFile(media.getObjectKey());

        VideoProcessingService.VideoThumbnailResult result = videoProcessingService.extractThumbnail(videoBytes);
        if (result != null) {
            String thumbnailKey = media.getObjectKey().replaceAll("\\.[^.]+$", "_thumb.jpg");
            String thumbnailUrl = s3Service.uploadBytes(result.thumbnailData(), thumbnailKey, "image/jpeg");
            media.setThumbnailUrl(thumbnailUrl);
            media.setWidth(result.videoWidth());
            media.setHeight(result.videoHeight());
            log.info("Extracted video thumbnail for media: {}", media.getId());
        } else {
            log.warn("Could not extract video thumbnail for media: {}", media.getId());
        }
    }
}
