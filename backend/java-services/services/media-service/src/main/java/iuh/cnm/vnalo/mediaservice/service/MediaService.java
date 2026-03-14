package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.domain.dto.PresignedUploadResponse;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaAccessScopeRepository;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaObjectRepository;
import iuh.cnm.vnalo.mediaservice.event.MediaUploadedEvent;
import iuh.cnm.vnalo.mediaservice.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.io.FilenameUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MediaService {

    private final MediaObjectRepository mediaObjectRepository;
    private final MediaAccessScopeRepository mediaAccessScopeRepository;
    private final S3Service s3Service;

    // Kafka is optional — will be null when Kafka is disabled (dev profile)
    @Autowired(required = false)
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Transactional
    public MediaObject uploadMedia(MultipartFile file, UUID ownerId, MediaCategory category) {
        String originalFilename = file.getOriginalFilename();
        String extension = FilenameUtils.getExtension(originalFilename);
        String objectKey = buildObjectKey(category, ownerId, extension);

        String url = s3Service.uploadFile(file, objectKey);

        MediaObject mediaObject = MediaObject.builder()
                .ownerUserId(ownerId)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .url(url)
                .mimeType(file.getContentType())
                .sizeBytes(file.getSize())
                .originalFilename(originalFilename)
                .mediaCategory(category)
                .status(MediaStatus.READY)
                .expiresAt(category == MediaCategory.STORY ? LocalDateTime.now().plusHours(24) : null)
                .build();

        // Sync metadata extraction — read width/height/duration immediately
        extractMetadata(file, mediaObject, category);

        MediaObject savedMedia = mediaObjectRepository.save(mediaObject);
        publishMediaEvent(savedMedia, objectKey, category);

        return savedMedia;
    }

    @Transactional
    public PresignedUploadResponse initiateUpload(String originalFilename, String contentType,
                                                   long size, UUID ownerId, MediaCategory category) {
        String extension = FilenameUtils.getExtension(originalFilename);
        String objectKey = buildObjectKey(category, ownerId, extension);

        String presignedUrl = s3Service.generatePresignedUrl(objectKey, contentType);

        MediaObject mediaObject = MediaObject.builder()
                .ownerUserId(ownerId)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .url(s3Service.getFileUrl(objectKey))
                .mimeType(contentType)
                .sizeBytes(size)
                .originalFilename(originalFilename)
                .mediaCategory(category)
                .status(MediaStatus.PRE_UPLOAD)
                .build();

        mediaObjectRepository.save(mediaObject);

        return PresignedUploadResponse.builder()
                .mediaId(mediaObject.getId())
                .objectKey(objectKey)
                .presignedUrl(presignedUrl)
                .publicUrl(mediaObject.getUrl())
                .build();
    }

    public MediaObject getMedia(UUID id) {
        return mediaObjectRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Media not found: " + id));
    }

    // ==================== DELETE ====================

    @Transactional
    public void deleteMedia(UUID id, UUID userId) {
        MediaObject media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException("Chỉ chủ sở hữu mới được xóa media");
        }

        // Delete from S3
        try {
            s3Service.deleteFile(media.getObjectKey());
        } catch (Exception e) {
            log.warn("Failed to delete S3 object: {}", media.getObjectKey(), e);
        }

        // Delete access scopes
        mediaAccessScopeRepository.deleteByMediaId(id);

        // Delete from DB
        mediaObjectRepository.delete(media);
        log.info("Deleted media: {}", id);
    }

    // ==================== LIST (flexible filter + pagination) ====================

    public org.springframework.data.domain.Page<MediaObject> listMedia(
            UUID ownerUserId,
            UUID conversationId,
            MediaCategory category,
            org.springframework.data.domain.Pageable pageable) {

        // Filter by conversation + category
        if (conversationId != null && category != null) {
            return mediaObjectRepository.findByConversationIdAndCategory(conversationId, category, pageable);
        }
        // Filter by conversation only
        if (conversationId != null) {
            return mediaObjectRepository.findByConversationId(conversationId, pageable);
        }
        // Filter by owner + category
        if (ownerUserId != null && category != null) {
            return mediaObjectRepository.findByOwnerUserIdAndMediaCategory(ownerUserId, category, pageable);
        }
        // Filter by owner only
        if (ownerUserId != null) {
            return mediaObjectRepository.findByOwnerUserId(ownerUserId, pageable);
        }
        // Filter by category only
        if (category != null) {
            return mediaObjectRepository.findByMediaCategory(category, pageable);
        }
        // No filter — return all (paginated)
        return mediaObjectRepository.findAll(pageable);
    }

    // ==================== UPDATE METADATA ====================

    @Transactional
    public MediaObject updateMetadata(UUID id, UUID userId, String newFilename, MediaCategory newCategory) {
        MediaObject media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException("Chỉ chủ sở hữu mới được cập nhật metadata");
        }

        if (newFilename != null && !newFilename.isBlank()) {
            media.setOriginalFilename(newFilename);
        }
        if (newCategory != null) {
            media.setMediaCategory(newCategory);
        }

        return mediaObjectRepository.save(media);
    }

    // ==================== COMPLETE UPLOAD (presigned) ====================

    @Transactional
    public MediaObject completeUpload(UUID id, UUID userId) {
        MediaObject media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException("Chỉ chủ sở hữu mới được hoàn tất upload");
        }
        if (media.getStatus() != MediaStatus.PRE_UPLOAD) {
            throw new IllegalStateException("Media không ở trạng thái PRE_UPLOAD, hiện tại: " + media.getStatus());
        }

        media.setStatus(MediaStatus.READY);
        MediaObject saved = mediaObjectRepository.save(media);
        publishMediaEvent(saved, saved.getObjectKey(), saved.getMediaCategory());
        return saved;
    }

    // ==================== PRESIGNED DOWNLOAD ====================

    public String generateDownloadUrl(UUID id) {
        MediaObject media = getMedia(id);
        return s3Service.generatePresignedDownloadUrl(media.getObjectKey());
    }

    // ==================== SAVE TO DEVICE (stream bytes) ====================

    /**
     * Tải toàn bộ nội dung file từ S3 về dưới dạng byte array.
     * Dùng cho endpoint /save — trả về binary stream để client lưu về thiết bị.
     *
     * Lưu ý: Không dùng cho file lớn (>50MB) vì toàn bộ file được load vào RAM.
     * Với file video lớn, nên dùng presigned URL thay thế.
     */
    public byte[] downloadMediaBytes(UUID id) {
        MediaObject media = getMedia(id);
        log.debug("Downloading media bytes from S3: {}", media.getObjectKey());
        return s3Service.downloadFile(media.getObjectKey());
    }

    // ==================== STORY TTL CLEANUP ====================

    @Scheduled(fixedRate = 3600000) // Every hour
    @Transactional
    public void cleanExpiredStories() {
        List<MediaObject> expired = mediaObjectRepository
                .findByMediaCategoryAndStatusAndExpiresAtBefore(
                        MediaCategory.STORY, MediaStatus.READY, LocalDateTime.now());

        for (MediaObject media : expired) {
            try {
                s3Service.deleteFile(media.getObjectKey());
                media.setStatus(MediaStatus.EXPIRED);
                mediaObjectRepository.save(media);
                log.info("Expired story cleaned: {}", media.getId());
            } catch (Exception e) {
                log.warn("Failed to clean expired story: {}", media.getId(), e);
            }
        }

        if (!expired.isEmpty()) {
            log.info("Cleaned {} expired stories", expired.size());
        }
    }

    // --- Private helpers ---

    private String buildObjectKey(MediaCategory category, UUID ownerId, String extension) {
        return String.format("%s/%s/%s.%s", category.name().toLowerCase(), ownerId, UUID.randomUUID(), extension);
    }

    private void publishMediaEvent(MediaObject savedMedia, String objectKey, MediaCategory category) {
        if (kafkaTemplate != null) {
            try {
                kafkaTemplate.send("media-uploaded-topic", MediaUploadedEvent.builder()
                        .mediaId(savedMedia.getId())
                        .objectKey(objectKey)
                        .bucket(savedMedia.getBucket())
                        .category(category)
                        .build());
            } catch (Exception e) {
                log.warn("Failed to publish media uploaded event for media: {}", savedMedia.getId(), e);
            }
        } else {
            log.debug("Kafka disabled — skipping async processing for media: {}", savedMedia.getId());
        }
    }

    /**
     * Extract metadata synchronously during upload.
     * Reads width/height for images, width/height/duration for videos.
     * Never throws — logs warning on failure so upload still succeeds.
     */
    private void extractMetadata(MultipartFile file, MediaObject mediaObject, MediaCategory category) {
        try {
            String mimeType = file.getContentType();
            if (mimeType != null && mimeType.startsWith("image/")) {
                extractImageMetadata(file, mediaObject);
            } else if (mimeType != null && mimeType.startsWith("video/")) {
                extractVideoMetadata(file, mediaObject);
            }
        } catch (Exception e) {
            log.warn("Failed to extract metadata for file: {}", file.getOriginalFilename(), e);
        }
    }

    private void extractImageMetadata(MultipartFile file, MediaObject mediaObject) {
        try {
            java.awt.image.BufferedImage image = javax.imageio.ImageIO.read(file.getInputStream());
            if (image != null) {
                mediaObject.setWidth(image.getWidth());
                mediaObject.setHeight(image.getHeight());
                log.debug("Image metadata: {}x{}", image.getWidth(), image.getHeight());
            }
        } catch (Exception e) {
            log.warn("Failed to read image dimensions: {}", e.getMessage());
        }
    }

    private void extractVideoMetadata(MultipartFile file, MediaObject mediaObject) {
        java.io.File tempFile = null;
        try {
            tempFile = java.io.File.createTempFile("video_meta_", ".tmp");
            file.transferTo(tempFile);

            // Read video dimensions using FrameGrab
            org.jcodec.api.FrameGrab grab = org.jcodec.api.FrameGrab.createFrameGrab(
                org.jcodec.common.io.NIOUtils.readableChannel(tempFile));
            org.jcodec.common.model.Picture picture = grab.getNativeFrame();
            if (picture != null) {
                mediaObject.setWidth(picture.getWidth());
                mediaObject.setHeight(picture.getHeight());
            }

            // Read duration using MP4Demuxer
            try (org.jcodec.common.io.SeekableByteChannel ch = org.jcodec.common.io.NIOUtils.readableChannel(tempFile)) {
                org.jcodec.containers.mp4.demuxer.MP4Demuxer demuxer = org.jcodec.containers.mp4.demuxer.MP4Demuxer.createMP4Demuxer(ch);
                org.jcodec.common.DemuxerTrack videoTrack = demuxer.getVideoTrack();
                if (videoTrack != null) {
                    org.jcodec.common.DemuxerTrackMeta meta = videoTrack.getMeta();
                    if (meta != null && meta.getTotalDuration() > 0) {
                        mediaObject.setDurationMs((int) (meta.getTotalDuration() * 1000));
                    }
                }
            }
            log.debug("Video metadata: {}x{}, duration={}ms",
                mediaObject.getWidth(), mediaObject.getHeight(), mediaObject.getDurationMs());
        } catch (Exception e) {
            log.warn("Failed to read video metadata: {}", e.getMessage());
        } finally {
            if (tempFile != null && tempFile.exists()) {
                tempFile.delete();
            }
        }
    }
}
