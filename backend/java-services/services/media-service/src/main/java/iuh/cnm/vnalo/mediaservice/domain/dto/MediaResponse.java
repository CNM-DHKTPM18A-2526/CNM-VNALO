package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaObject;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * DTO for media response — hides internal fields (bucket, objectKey) from client.
 */
@Data
@Builder
public class MediaResponse {

    private UUID id;
    private UUID ownerUserId;
    private String url;
    private String thumbnailUrl;
    private String mimeType;
    private Long sizeBytes;
    private Integer width;
    private Integer height;
    private Integer durationMs;
    private String originalFilename;
    private MediaCategory mediaCategory;
    private MediaStatus status;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;

    /**
     * Convert entity to DTO (hides bucket, objectKey, checksum, updatedAt).
     */
    public static MediaResponse from(MediaObject entity) {
        return MediaResponse.builder()
                .id(entity.getId())
                .ownerUserId(entity.getOwnerUserId())
                .url(entity.getUrl())
                .thumbnailUrl(entity.getThumbnailUrl())
                .mimeType(entity.getMimeType())
                .sizeBytes(entity.getSizeBytes())
                .width(entity.getWidth())
                .height(entity.getHeight())
                .durationMs(entity.getDurationMs())
                .originalFilename(entity.getOriginalFilename())
                .mediaCategory(entity.getMediaCategory())
                .status(entity.getStatus())
                .createdAt(entity.getCreatedAt())
                .expiresAt(entity.getExpiresAt())
                .build();
    }
}
