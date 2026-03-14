package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.StickerPack;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackCategory;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerPackStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class StickerPackDetailResponse {

    private UUID packId;
    private String name;
    private String description;
    private String thumbnailUrl;
    private String bannerUrl;
    private String author;
    private StickerPackCategory category;
    private Boolean isPremium;
    private Boolean isAnimated;
    private BigDecimal price;
    private Integer downloadCount;
    private Integer stickerCount;
    private StickerPackStatus status;
    private LocalDateTime createdAt;
    private List<StickerResponse> stickers;

    public static StickerPackDetailResponse from(StickerPack pack, List<StickerResponse> stickers) {
        return StickerPackDetailResponse.builder()
                .packId(pack.getPackId())
                .name(pack.getName())
                .description(pack.getDescription())
                .thumbnailUrl(pack.getThumbnailUrl())
                .bannerUrl(pack.getBannerUrl())
                .author(pack.getAuthor())
                .category(pack.getCategory())
                .isPremium(pack.getIsPremium())
                .isAnimated(pack.getIsAnimated())
                .price(pack.getPrice())
                .downloadCount(pack.getDownloadCount())
                .stickerCount(pack.getStickerCount())
                .status(pack.getStatus())
                .createdAt(pack.getCreatedAt())
                .stickers(stickers)
                .build();
    }
}
