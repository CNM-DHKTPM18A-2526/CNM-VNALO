package iuh.cnm.vnalo.mediaservice.domain.dto;

import iuh.cnm.vnalo.mediaservice.domain.model.Sticker;
import iuh.cnm.vnalo.mediaservice.domain.model.StickerStatus;
import lombok.Builder;
import lombok.Data;

import java.util.UUID;

@Data
@Builder
public class StickerResponse {

    private UUID stickerId;
    private UUID packId;
    private String name;
    private UUID mediaId;
    private Boolean isAnimated;
    private Integer displayOrder;
    private StickerStatus status;

    public static StickerResponse from(Sticker sticker) {
        return StickerResponse.builder()
                .stickerId(sticker.getStickerId())
                .packId(sticker.getPackId())
                .name(sticker.getName())
                .mediaId(sticker.getMediaId())
                .isAnimated(sticker.getIsAnimated())
                .displayOrder(sticker.getDisplayOrder())
                .status(sticker.getStatus())
                .build();
    }
}
