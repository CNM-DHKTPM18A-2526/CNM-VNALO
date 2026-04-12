package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerPack;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackStatus;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class StickerPackDetailResponse {

    private UUID stickerPackId;
    private UUID ownerUserId;
    private String name;
    private String description;
    private UUID coverMediaId;
    private String coverUrl;
    private Integer downloadCount;
    private Integer stickerCount;
    private StickerPackStatus status;
    private LocalDateTime createdAt;
    private List<StickerResponse> stickers;

    public static StickerPackDetailResponse from(StickerPack pack, String coverUrl, List<StickerResponse> stickers) {
        return StickerPackDetailResponse.builder()
                .stickerPackId(pack.getStickerPackId())
                .ownerUserId(pack.getOwnerUserId())
                .name(pack.getName())
                .description(pack.getDescription())
                .coverMediaId(pack.getCoverMediaId())
                .coverUrl(coverUrl)
                .downloadCount(pack.getDownloadCount())
                .stickerCount(pack.getStickerCount())
                .status(pack.getStatus())
                .createdAt(pack.getCreatedAt())
                .stickers(stickers)
                .build();
    }
}
