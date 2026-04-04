package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerPack;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class StickerPackResponse {

    private UUID stickerPackId;
    private UUID ownerUserId;
    private String name;
    private String description;
    private UUID coverMediaId;
    private Integer downloadCount;
    private Integer stickerCount;
    private StickerPackStatus status;
    private LocalDateTime createdAt;

    public static StickerPackResponse from(StickerPack pack) {
        return StickerPackResponse.builder()
                .stickerPackId(pack.getStickerPackId())
                .ownerUserId(pack.getOwnerUserId())
                .name(pack.getName())
                .description(pack.getDescription())
                .coverMediaId(pack.getCoverMediaId())
                .downloadCount(pack.getDownloadCount())
                .stickerCount(pack.getStickerCount())
                .status(pack.getStatus())
                .createdAt(pack.getCreatedAt())
                .build();
    }
}
