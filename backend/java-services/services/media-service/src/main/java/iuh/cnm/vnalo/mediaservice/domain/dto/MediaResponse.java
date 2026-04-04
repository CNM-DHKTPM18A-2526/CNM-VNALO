package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.MediaCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.MediaMetadata;
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

    private UUID mediaId;
    private UUID ownerUserId;
    private MediaCategory category;
    private String mimeType;
    private String originalFilename;
    private String url;
    private String thumbnailUrl;
    private Long sizeBytes;
    private Integer width;
    private Integer height;
    private Integer durationMs;
    private MediaStatus status;
    private LocalDateTime createdAt;

    public static MediaResponse from(MediaMetadata entity) {
        return MediaResponse.builder()
                .mediaId(entity.getId())
                .ownerUserId(entity.getOwnerUserId())
                .category(entity.getCategory())
                .mimeType(entity.getMimeType())
                .originalFilename(entity.getOriginalFilename())
                .url(entity.getUrl())
                .thumbnailUrl(entity.getThumbnailUrl())
                .sizeBytes(entity.getSizeBytes())
                .width(entity.getWidth())
                .height(entity.getHeight())
                .durationMs(entity.getDurationMs())
                .status(entity.getStatus())
                .createdAt(entity.getCreatedAt())
                .build();
    }
}
