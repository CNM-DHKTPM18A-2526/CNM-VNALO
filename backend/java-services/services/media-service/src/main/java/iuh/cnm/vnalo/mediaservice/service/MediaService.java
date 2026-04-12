package iuh.cnm.vnalo.mediaservice.service;

import iuh.cnm.vnalo.mediaservice.config.RabbitMQConfig;
import iuh.cnm.vnalo.mediaservice.domain.dto.InitiateUploadRequest;
import iuh.cnm.vnalo.mediaservice.domain.dto.PresignedUploadResponse;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import iuh.cnm.vnalo.mediaservice.domain.repository.MediaMetadataRepository;
import iuh.cnm.vnalo.mediaservice.event.MediaUploadedEvent;
import iuh.cnm.vnalo.mediaservice.exception.AccessDeniedException;
import iuh.cnm.vnalo.mediaservice.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.io.FilenameUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MediaService {

    private final MediaMetadataRepository mediaMetadataRepository;
    private final S3Service s3Service;
    private final MediaProcessingService mediaProcessingService;

    @Autowired(required = false)
    private RabbitTemplate rabbitTemplate;

    // ==================== Upload ====================

    @Transactional
    public MediaMetadata uploadMedia(MultipartFile file, UUID ownerId, MediaCategory category) {
        String originalFilename = file.getOriginalFilename();
        String extension = FilenameUtils.getExtension(originalFilename);
        String objectKey = buildObjectKey(category, ownerId, extension);

        String url = s3Service.uploadFile(file, objectKey);

        MediaMetadata media = MediaMetadata.builder()
                .ownerUserId(ownerId)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .category(category)
                .mimeType(file.getContentType())
                .sizeBytes(file.getSize())
                .originalFilename(originalFilename)
                .url(url)
                .needsProcessing(category.isImage() || category.isVideo())
                .status(MediaStatus.UPLOADED)
                .build();

        MediaMetadata saved = mediaMetadataRepository.save(media);

        if (saved.getNeedsProcessing()) {
            scheduleProcessingAfterCommit(saved.getId(), objectKey);
        } else {
            publishMediaEvent(saved);
        }

        return saved;
    }

    // ==================== Presigned Upload ====================

    @Transactional
    public PresignedUploadResponse initiateUpload(InitiateUploadRequest request, UUID ownerId) {
        String extension = FilenameUtils.getExtension(request.getFilename());
        String objectKey = buildObjectKey(request.getCategory(), ownerId, extension);

        String presignedUrl = s3Service.generatePresignedUrl(objectKey, request.getContentType());

        MediaMetadata media = MediaMetadata.builder()
                .ownerUserId(ownerId)
                .bucket(s3Service.getBucketName())
                .objectKey(objectKey)
                .category(request.getCategory())
                .mimeType(request.getContentType())
                .sizeBytes(request.getSizeBytes())
                .originalFilename(request.getFilename())
                .needsProcessing(request.getCategory().isImage() || request.getCategory().isVideo())
                .status(MediaStatus.PENDING_UPLOAD)
                .build();

        mediaMetadataRepository.save(media);

        return PresignedUploadResponse.builder()
                .mediaId(media.getId())
                .objectKey(objectKey)
                .presignedUrl(presignedUrl)
                .build();
    }

    // ==================== Complete Upload ====================

    @Transactional
    public MediaMetadata completeUpload(UUID id, UUID userId) {
        MediaMetadata media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu mới được hoàn tất upload");
        }
        if (media.getStatus() != MediaStatus.PENDING_UPLOAD) {
            throw new IllegalStateException("Media không ở trạng thái PENDING_UPLOAD, hiện tại: " + media.getStatus());
        }

        media.setStatus(MediaStatus.UPLOADED);
        media.setUrl(s3Service.getFileUrl(media.getObjectKey()));
        MediaMetadata saved = mediaMetadataRepository.save(media);

        if (saved.getNeedsProcessing()) {
            scheduleProcessingAfterCommit(saved.getId(), saved.getObjectKey());
        } else {
            publishMediaEvent(saved);
        }
        return saved;
    }

    // ==================== Query ====================

    public MediaMetadata getMedia(UUID id) {
        return mediaMetadataRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Media not found: " + id));
    }

    public Page<MediaMetadata> listMedia(UUID ownerUserId, MediaCategory category, Pageable pageable) {
        if (ownerUserId != null && category != null) {
            return mediaMetadataRepository.findByOwnerUserIdAndCategory(ownerUserId, category, pageable);
        }
        if (ownerUserId != null) {
            return mediaMetadataRepository.findByOwnerUserId(ownerUserId, pageable);
        }
        if (category != null) {
            return mediaMetadataRepository.findByCategory(category, pageable);
        }
        return mediaMetadataRepository.findAll(pageable);
    }

    // ==================== Update ====================

    @Transactional
    public MediaMetadata updateMedia(UUID id, UUID userId, String originalFilename) {
        MediaMetadata media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu mới được cập nhật media");
        }
        if (originalFilename != null && !originalFilename.isBlank()) {
            media.setOriginalFilename(originalFilename);
        }
        return mediaMetadataRepository.save(media);
    }

    // ==================== Replace File ====================

    @Transactional
    public MediaMetadata replaceMedia(UUID id, UUID userId, MultipartFile newFile) {
        MediaMetadata media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu mới được thay thế file");
        }

        // 1. Delete old S3 object
        String oldObjectKey = media.getObjectKey();
        try {
            s3Service.deleteFile(oldObjectKey);
        } catch (Exception e) {
            log.warn("Failed to delete old S3 object during replace: {}", oldObjectKey, e);
        }

        // 2. Upload new file
        String extension = FilenameUtils.getExtension(newFile.getOriginalFilename());
        String newObjectKey = buildObjectKey(media.getCategory(), userId, extension);
        String newUrl = s3Service.uploadFile(newFile, newObjectKey);

        // 3. Update metadata — keep same mediaId + category
        media.setObjectKey(newObjectKey);
        media.setUrl(newUrl);
        media.setThumbnailUrl(null); // reset thumbnail — sẽ được tạo lại
        media.setMimeType(newFile.getContentType());
        media.setSizeBytes(newFile.getSize());
        media.setOriginalFilename(newFile.getOriginalFilename());
        media.setWidth(null);
        media.setHeight(null);
        media.setDurationMs(null);
        media.setChecksumSha256(null);
        media.setNeedsProcessing(media.getCategory().isImage() || media.getCategory().isVideo());
        media.setStatus(MediaStatus.UPLOADED);

        MediaMetadata saved = mediaMetadataRepository.save(media);

        // 4. Reprocess (generate thumbnail, etc.)
        if (saved.getNeedsProcessing()) {
            scheduleProcessingAfterCommit(saved.getId(), newObjectKey);
        } else {
            publishMediaEvent(saved);
        }

        log.info("Replaced media file: {} by user {}", id, userId);
        return saved;
    }

    // ==================== Delete ====================

    @Transactional
    public void deleteMedia(UUID id, UUID userId) {
        MediaMetadata media = getMedia(id);
        if (!media.getOwnerUserId().equals(userId)) {
            throw new AccessDeniedException("Chỉ chủ sở hữu mới được xóa media");
        }

        try {
            s3Service.deleteFile(media.getObjectKey());
        } catch (Exception e) {
            log.warn("Failed to delete S3 object: {}", media.getObjectKey(), e);
        }

        mediaMetadataRepository.delete(media);
        log.info("Deleted media: {}", id);
    }

    // ==================== Download ====================

    public String generateDownloadUrl(UUID id) {
        MediaMetadata media = getMedia(id);
        return s3Service.generatePresignedDownloadUrl(media.getObjectKey());
    }

    public byte[] downloadMediaBytes(UUID id) {
        MediaMetadata media = getMedia(id);
        return s3Service.downloadFile(media.getObjectKey());
    }

    public byte[] downloadMediaBytesByKey(String objectKey) {
        return s3Service.downloadFile(objectKey);
    }

    public void streamMediaToResponse(UUID id, java.io.OutputStream out) {
        MediaMetadata media = getMedia(id);
        s3Service.streamToResponse(media.getObjectKey(), out);
    }

    // ==================== Private helpers ====================

    private String buildObjectKey(MediaCategory category, UUID ownerId, String extension) {
        return String.format("%s/%s/%s.%s", category.name().toLowerCase(), ownerId, UUID.randomUUID(), extension);
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

    private void scheduleProcessingAfterCommit(UUID mediaId, String objectKey) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                mediaProcessingService.processMediaAsync(mediaId, objectKey);
            }
        });
    }
}
